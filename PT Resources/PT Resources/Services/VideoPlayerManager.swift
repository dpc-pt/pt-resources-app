//
//  VideoPlayerManager.swift
//  PT Resources
//
//  Video playback manager for handling video URLs and AVPlayerViewController presentation
//

import Foundation
import AVFoundation
import AVKit
import UIKit
import Combine
import WebKit

@MainActor
final class VideoPlayerManager: NSObject, ObservableObject {
    
    // MARK: - Singleton Instance
    
    static let shared = VideoPlayerManager()
    
    // MARK: - Published Properties
    
    @Published var currentVideoURL: URL?
    @Published var isVideoLoading = false
    @Published var videoError: VideoError?
    @Published var isVideoPlaying = false
    
    // MARK: - Private Properties
    
    private var currentPlayerViewController: AVPlayerViewController?
    private var currentWebViewController: UIViewController?
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var featureManager: VideoPlayerFeatureManager?
    
    // Cache for video metadata
    private var videoCache: [String: VideoMetadata] = [:]
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupNotificationObservers()
    }
    
    deinit {
        Task { @MainActor in
            cleanup()
        }
    }
    
    // MARK: - Public Methods
    
    /// Present video player for a given video URL
    func presentVideoPlayer(for url: URL, title: String? = nil, from presentingViewController: UIViewController? = nil) {
        Task {
            await loadAndPresentVideo(url: url, title: title, from: presentingViewController)
        }
    }
    
    /// Present video player for a Talk with video content
    func presentVideoPlayer(for talk: Talk, from presentingViewController: UIViewController? = nil) {
        guard let url = talk.processedVideoURL else {
            videoError = .invalidURL("No video URL available for this talk")
            return
        }
        presentVideoPlayer(for: url, title: talk.title, from: presentingViewController)
    }
    
    /// Present video player for a ResourceDetail with video content
    func presentVideoPlayer(for resource: ResourceDetail, from presentingViewController: UIViewController? = nil) {
        guard let videoURL = resource.videoURL else {
            videoError = .invalidURL("No video URL available for this resource")
            return
        }
        
        presentVideoPlayer(for: videoURL, title: resource.title, from: presentingViewController)
    }
    
    /// Check if a URL is a supported video URL
    func isSupportedVideoURL(_ url: URL) -> Bool {
        return VideoURLDetector.shared.isValidVideoURL(url)
    }
    
    /// Check if a video URL is accessible (performs a quick validation)
    func isVideoAccessible(_ url: URL) async -> Bool {
        // For Vimeo videos, use the SDK service for better accuracy
        if url.host?.contains("vimeo.com") == true || url.host?.contains("player.vimeo.com") == true {
            let videoID = extractVimeoVideoID(from: url)
            if !videoID.isEmpty {
                return await VimeoSDKService.shared.isVideoAccessible(videoID: videoID)
            }
        }
        
        // For other videos, use the existing validation
        do {
            let _ = try await VideoURLDetector.shared.processVideoURL(url)
            return true
        } catch {
            PTLogger.general.warning("Video URL not accessible: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Present video using web view fallback for Vimeo videos with domain restrictions
    func presentVideoWithWebViewFallback(for videoID: String, title: String?, from presentingViewController: UIViewController?) {
        Task {
            await presentWebViewVideo(videoID: videoID, title: title, from: presentingViewController)
        }
    }
    
    private func presentWebViewVideo(videoID: String, title: String?, from presentingViewController: UIViewController?) async {
        // Create a simple web view that loads the Vimeo player
        let webViewController = UIViewController()
        let webView = WKWebView()
        webView.frame = webViewController.view.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Create the Vimeo embed HTML with better styling
        let embedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
            <style>
                body { 
                    margin: 0; 
                    padding: 0; 
                    background: #000; 
                    overflow: hidden;
                    position: fixed;
                    width: 100%;
                    height: 100%;
                }
                iframe { 
                    position: absolute;
                    top: 0;
                    left: 0;
                    width: 100%; 
                    height: 100%; 
                    border: none;
                }
            </style>
        </head>
        <body>
            <iframe src="https://player.vimeo.com/video/\(videoID)?h=auto&autoplay=1&title=0&byline=0&portrait=0" 
                    frameborder="0" 
                    allow="autoplay; fullscreen; picture-in-picture" 
                    allowfullscreen>
            </iframe>
        </body>
        </html>
        """
        
        webView.loadHTMLString(embedHTML, baseURL: URL(string: "https://www.proctrust.org.uk"))
        webViewController.view.addSubview(webView)
        webViewController.view.backgroundColor = .black
        
        // Store reference to the current web view controller for dismissal
        currentWebViewController = webViewController
        
        let presenter = presentingViewController ?? findTopViewController()
        
        guard let presenter = presenter else {
            PTLogger.general.error("Unable to find presenting view controller for WebView")
            return
        }
        
        // Check if the presenter is already presenting something
        if presenter.presentedViewController != nil {
            // Dismiss any existing presentation first
            await dismissExistingPresentation(from: presenter)
        }
        
        // Present directly as full screen without navigation controller
        await MainActor.run {
            webViewController.modalPresentationStyle = .fullScreen
            webViewController.modalTransitionStyle = .crossDissolve
            
            // Add tap gesture to dismiss (double tap)
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissWebView))
            tapGesture.numberOfTapsRequired = 2
            webViewController.view.addGestureRecognizer(tapGesture)
            
            // Add swipe down gesture to dismiss
            let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(dismissWebView))
            swipeGesture.direction = .down
            webViewController.view.addGestureRecognizer(swipeGesture)
            
            presenter.present(webViewController, animated: true)
        }
    }
    
    @objc private func dismissWebView() {
        if let webViewController = currentWebViewController {
            webViewController.dismiss(animated: true) {
                self.currentWebViewController = nil
            }
        } else {
            currentPlayerViewController?.dismiss(animated: true)
        }
    }
    
    /// Dismiss current video player
    func dismissVideoPlayer() {
        currentPlayerViewController?.dismiss(animated: true) { [weak self] in
            self?.cleanup()
        }
    }
    
    /// Pause current video playback
    func pauseVideo() {
        player?.pause()
        isVideoPlaying = false
    }
    
    /// Resume current video playback
    func playVideo() {
        player?.play()
        isVideoPlaying = true
    }
    
    // MARK: - Private Methods
    
    private func loadAndPresentVideo(url: URL, title: String?, from presentingViewController: UIViewController?) async {
        isVideoLoading = true
        videoError = nil
        
        do {
            // Validate URL
            let validatedURL = try await VideoURLDetector.shared.processVideoURL(url)
            
            // Create player
            let playerItem = AVPlayerItem(url: validatedURL)
            let player = AVPlayer(playerItem: playerItem)
            
            // Configure player
            await setupPlayer(player, title: title)
            
            // Create player view controller
            let playerViewController = createPlayerViewController(with: player)
            
            // Present the player
            await presentPlayer(playerViewController, from: presentingViewController)
            
            // Cache metadata
            cacheVideoMetadata(for: url, title: title)
            
        } catch {
            handleVideoError(error)
        }
        
        isVideoLoading = false
    }
    
    private func setupPlayer(_ player: AVPlayer, title: String?) async {
        self.player = player
        // Note: AVAsset doesn't have a direct url property, we'll use the original URL
        // self.currentVideoURL = player.currentItem?.asset.url
        
        // Add time observer
        let time = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        timeObserver = player.addPeriodicTimeObserver(forInterval: time, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.updatePlaybackState()
            }
        }
        
        // Observe player status
        player.currentItem?.publisher(for: \.status)
            .sink { [weak self] status in
                Task { @MainActor in
                    self?.handlePlayerStatusChange(status)
                }
            }
            .store(in: &cancellables)
    }
    
    private func createPlayerViewController(with player: AVPlayer) -> AVPlayerViewController {
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        
        // Create and configure feature manager
        let config = VideoPlayerConfiguration.default
        featureManager = VideoPlayerFeatureManager(configuration: config)
        featureManager?.configure(playerViewController: playerViewController, with: player)
        
        // Start analytics tracking
        featureManager?.startAnalyticsTracking()
        
        currentPlayerViewController = playerViewController
        return playerViewController
    }
    
    private func presentPlayer(_ playerViewController: AVPlayerViewController, from presentingViewController: UIViewController?) async {
        let presenter = presentingViewController ?? findTopViewController()
        
        guard let presenter = presenter else {
            videoError = .presentationError("Unable to find presenting view controller")
            return
        }
        
        // Check if the presenter is already presenting something
        if presenter.presentedViewController != nil {
            // Dismiss any existing presentation first
            await dismissExistingPresentation(from: presenter)
        }
        
        // Ensure we're on the main thread for UI operations
        await MainActor.run {
            presenter.present(playerViewController, animated: true) { [weak self] in
                self?.player?.play()
                self?.isVideoPlaying = true
            }
        }
    }
    
    private func dismissExistingPresentation(from presenter: UIViewController) async {
        return await withCheckedContinuation { continuation in
            presenter.dismiss(animated: true) {
                continuation.resume()
            }
        }
    }
    
    private func findTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first,
              let window = windowScene.windows.first(where: \.isKeyWindow) else {
            return nil
        }
        
        return window.rootViewController?.topMostViewController
    }
    
    private func updatePlaybackState() {
        guard let player = player else { return }
        
        let rate = player.rate
        isVideoPlaying = rate > 0
        
        // Update current time if needed for analytics
        let currentTime = player.currentTime()
        PTLogger.general.debug("Video playback time: \(CMTimeGetSeconds(currentTime))")
    }
    
    private func handlePlayerStatusChange(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            videoError = nil
            PTLogger.general.info("Video player ready to play")
            
        case .failed:
            if let error = player?.currentItem?.error {
                handleVideoError(error)
            } else {
                videoError = .playbackError("Video failed to load")
            }
            
        case .unknown:
            PTLogger.general.debug("Video player status unknown")
            
        @unknown default:
            PTLogger.general.warning("Unknown video player status")
        }
    }
    
    private func handleVideoError(_ error: Error) {
        PTLogger.general.error("Video player error: \(error.localizedDescription)")
        
        if let videoError = error as? VideoError {
            self.videoError = videoError
        } else if let nsError = error as? NSError {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                self.videoError = .networkError("No internet connection available")
            case NSURLErrorTimedOut:
                self.videoError = .networkError("Video loading timed out")
            case NSURLErrorCannotFindHost:
                self.videoError = .networkError("Unable to connect to video server")
            case NSURLErrorCannotLoadFromNetwork:
                self.videoError = .networkError("Unable to load video from network")
            case NSURLErrorBadServerResponse:
                self.videoError = .playbackError("Video server error")
            case NSURLErrorUserAuthenticationRequired:
                self.videoError = .playbackError("Video requires authentication")
            case NSURLErrorNoPermissionsToReadFile:
                self.videoError = .playbackError("No permission to access this video")
            default:
                // Check for specific error messages that might indicate permission issues
                let errorMessage = nsError.localizedDescription.lowercased()
                if errorMessage.contains("permission") || errorMessage.contains("access") || errorMessage.contains("forbidden") {
                    self.videoError = .playbackError("This video is not publicly accessible")
                } else {
                    self.videoError = .playbackError(nsError.localizedDescription)
                }
            }
        } else {
            // Check for specific error messages in the localized description
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("permission") || errorMessage.contains("access") || errorMessage.contains("forbidden") {
                self.videoError = .playbackError("This video is not publicly accessible")
            } else {
                self.videoError = .playbackError(error.localizedDescription)
            }
        }
    }
    
    private func cacheVideoMetadata(for url: URL, title: String?) {
        let metadata = VideoMetadata(
            url: url,
            title: title,
            cachedAt: Date()
        )
        videoCache[url.absoluteString] = metadata
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppWillEnterForeground()
            }
            .store(in: &cancellables)
    }
    
    private func handleAppDidEnterBackground() {
        // Video will automatically pause in background for non-background apps
        PTLogger.general.debug("App entering background, video playback will pause")
    }
    
    private func handleAppWillEnterForeground() {
        // Update playback state when returning from background
        updatePlaybackState()
    }
    
    private func cleanup() {
        // Stop analytics tracking
        featureManager?.stopAnalyticsTracking()
        
        // Remove time observer
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        // Cancel all publishers
        cancellables.removeAll()
        
        // Pause and clean up player
        player?.pause()
        player = nil
        currentPlayerViewController = nil
        featureManager = nil
        currentVideoURL = nil
        isVideoPlaying = false
    }
    
    private func extractVimeoVideoID(from url: URL) -> String {
        let urlString = url.absoluteString
        
        // Handle different Vimeo URL formats
        if let range = urlString.range(of: "vimeo.com/") {
            let afterHost = String(urlString[range.upperBound...])
            let components = afterHost.components(separatedBy: "/")
            if let firstComponent = components.first, 
               firstComponent.allSatisfy({ $0.isNumber }) {
                return firstComponent
            }
        }
        
        // Handle player.vimeo.com URLs
        if let range = urlString.range(of: "player.vimeo.com/video/") {
            let afterPath = String(urlString[range.upperBound...])
            let components = afterPath.components(separatedBy: "?")
            if let videoID = components.first,
               videoID.allSatisfy({ $0.isNumber }) {
                return videoID
            }
        }
        
        return ""
    }
}

// MARK: - Supporting Types

enum VideoError: LocalizedError {
    case invalidURL(String)
    case networkError(String)
    case playbackError(String)
    case presentationError(String)
    case unsupportedFormat(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let message):
            return "Invalid video URL: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .playbackError(let message):
            return "Playback error: \(message)"
        case .presentationError(let message):
            return "Presentation error: \(message)"
        case .unsupportedFormat(let message):
            return "Unsupported format: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidURL:
            return "Please check the video URL and try again."
        case .networkError:
            return "Please check your internet connection and try again."
        case .playbackError:
            return "Try playing the video again or contact support if the problem persists."
        case .presentationError:
            return "Please try again or restart the app."
        case .unsupportedFormat:
            return "This video format is not supported on your device."
        }
    }
}

struct VideoMetadata {
    let url: URL
    let title: String?
    let cachedAt: Date
}

// MARK: - UIViewController Extension

private extension UIViewController {
    var topMostViewController: UIViewController {
        if let presentedViewController = presentedViewController {
            return presentedViewController.topMostViewController
        }
        
        if let navigationController = self as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return visibleViewController.topMostViewController
        }
        
        if let tabBarController = self as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return selectedViewController.topMostViewController
        }
        
        return self
    }
}