//
//  VideoPlayerConfiguration.swift
//  PT Resources
//
//  Configuration and advanced features for video playback
//

import Foundation
import AVFoundation
import AVKit
import MediaPlayer
import UIKit

/// Configuration for video player features and behavior
struct VideoPlayerConfiguration {
    
    // MARK: - Playback Settings
    
    /// Enable Picture-in-Picture playback
    let allowsPictureInPicturePlayback: Bool
    
    /// Auto-start PiP when app enters background
    let canStartPictureInPictureAutomaticallyFromInline: Bool
    
    /// Enable AirPlay functionality
    let allowsExternalPlayback: Bool
    
    /// Available playback speeds
    let availablePlaybackSpeeds: [Float]
    
    /// Enable background audio continuation
    let allowsBackgroundAudio: Bool
    
    /// Automatically resume playback after interruption
    let resumesAfterInterruption: Bool
    
    // MARK: - UI Settings
    
    /// Show video controls overlay
    let showsPlaybackControls: Bool
    
    /// Enable custom PT branding on player
    let enableCustomBranding: Bool
    
    /// Show loading indicators
    let showsLoadingIndicators: Bool
    
    // MARK: - Analytics Settings
    
    /// Track video playback analytics
    let enableAnalytics: Bool
    
    /// Track playback milestones (25%, 50%, 75%, 100%)
    let trackPlaybackMilestones: Bool
    
    // MARK: - Default Configuration
    
    static let `default` = VideoPlayerConfiguration(
        allowsPictureInPicturePlayback: true,
        canStartPictureInPictureAutomaticallyFromInline: false,
        allowsExternalPlayback: true,
        availablePlaybackSpeeds: Config.playbackSpeedOptions,
        allowsBackgroundAudio: false, // Video doesn't continue in background by default
        resumesAfterInterruption: true,
        showsPlaybackControls: true,
        enableCustomBranding: true,
        showsLoadingIndicators: true,
        enableAnalytics: true,
        trackPlaybackMilestones: true
    )
    
    static let audioOnly = VideoPlayerConfiguration(
        allowsPictureInPicturePlayback: false,
        canStartPictureInPictureAutomaticallyFromInline: false,
        allowsExternalPlayback: true,
        availablePlaybackSpeeds: Config.playbackSpeedOptions,
        allowsBackgroundAudio: true,
        resumesAfterInterruption: true,
        showsPlaybackControls: true,
        enableCustomBranding: true,
        showsLoadingIndicators: true,
        enableAnalytics: true,
        trackPlaybackMilestones: true
    )
}

/// Advanced video playback features manager
@MainActor
class VideoPlayerFeatureManager: NSObject, ObservableObject {
    
    // MARK: - Properties
    
    @Published var isPictureInPictureActive = false
    @Published var isAirPlayActive = false
    @Published var currentPlaybackSpeed: Float = 1.0
    @Published var playbackMilestones: Set<Int> = []
    
    private var configuration: VideoPlayerConfiguration
    private var player: AVPlayer?
    private var playerViewController: AVPlayerViewController?
    
    // Analytics tracking
    private var playbackStartTime: Date?
    private var playbackDuration: TimeInterval = 0
    private var lastPlaybackPosition: TimeInterval = 0
    
    // MARK: - Initialization
    
    init(configuration: VideoPlayerConfiguration = .default) {
        self.configuration = configuration
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Configuration
    
    func configure(playerViewController: AVPlayerViewController, with player: AVPlayer) {
        self.player = player
        self.playerViewController = playerViewController
        
        // Apply configuration settings
        playerViewController.allowsPictureInPicturePlayback = configuration.allowsPictureInPicturePlayback
        playerViewController.delegate = self
        
        if #available(iOS 14.2, *) {
            playerViewController.canStartPictureInPictureAutomaticallyFromInline = 
                configuration.canStartPictureInPictureAutomaticallyFromInline
        }
        
        // Configure playback speeds
        if #available(iOS 16.0, *) {
            let speeds = configuration.availablePlaybackSpeeds.map { AVPlaybackSpeed(rate: $0, localizedName: "\($0)x") }
            playerViewController.speeds = speeds
        }
        
        // Configure external playback (AirPlay)
        player.allowsExternalPlayback = configuration.allowsExternalPlayback
        
        // Setup observers
        setupPlayerObservers(player)
        setupNowPlayingInfo()
    }
    
    // MARK: - Picture-in-Picture Controls
    
    func startPictureInPicture() {
        guard playerViewController != nil else {
            PTLogger.general.warning("Player view controller not available")
            return
        }
        
        // Check if PiP is supported and possible
        if AVPictureInPictureController.isPictureInPictureSupported() {
            // Note: PiP functionality would need to be implemented with AVPictureInPictureController
            PTLogger.general.info("Picture in Picture supported but not yet implemented")
        } else {
            PTLogger.general.warning("Picture in Picture not supported on this device")
        }
    }
    
    func stopPictureInPicture() {
        // Note: PiP functionality would need to be implemented with AVPictureInPictureController
        PTLogger.general.info("Picture in Picture stop requested but not yet implemented")
    }
    
    // MARK: - AirPlay Controls
    
    func showAirPlayPicker(from sourceView: UIView) {
        guard player != nil else { return }
        
        let routePickerView = AVRoutePickerView()
        // Note: player property is not available on iOS, using alternative approach
        routePickerView.frame = sourceView.bounds
        
        // Programmatically trigger the route picker
        if let button = routePickerView.subviews.first(where: { $0 is UIButton }) as? UIButton {
            button.sendActions(for: .touchUpInside)
        }
    }
    
    // MARK: - Playback Speed Controls
    
    func setPlaybackSpeed(_ speed: Float) {
        guard configuration.availablePlaybackSpeeds.contains(speed),
              let player = player else { return }
        
        player.rate = speed
        currentPlaybackSpeed = speed
        
        PTLogger.general.info("Set playback speed to \(speed)x")
        
        // Update Now Playing info
        updateNowPlayingPlaybackRate()
    }
    
    func cyclePlaybackSpeed() {
        guard let currentIndex = configuration.availablePlaybackSpeeds.firstIndex(of: currentPlaybackSpeed) else {
            return
        }
        
        let nextIndex = (currentIndex + 1) % configuration.availablePlaybackSpeeds.count
        let nextSpeed = configuration.availablePlaybackSpeeds[nextIndex]
        
        setPlaybackSpeed(nextSpeed)
    }
    
    // MARK: - Analytics and Tracking
    
    func startAnalyticsTracking() {
        guard configuration.enableAnalytics else { return }
        
        playbackStartTime = Date()
        playbackMilestones.removeAll()
        
        PTLogger.general.info("Started video analytics tracking")
    }
    
    func stopAnalyticsTracking() {
        guard configuration.enableAnalytics,
              let startTime = playbackStartTime else { return }
        
        let totalWatchTime = Date().timeIntervalSince(startTime)
        
        PTLogger.general.info("Video analytics: Total watch time: \(totalWatchTime)s, Milestones: \(self.playbackMilestones)")
        
        // Reset tracking state
        playbackStartTime = nil
        playbackMilestones.removeAll()
    }
    
    func trackPlaybackProgress(_ currentTime: TimeInterval, duration: TimeInterval) {
        guard configuration.trackPlaybackMilestones,
              duration > 0 else { return }
        
        let progressPercentage = Int((currentTime / duration) * 100)
        
        // Track milestone achievements
        for milestone in [25, 50, 75, 100] {
            if progressPercentage >= milestone && !playbackMilestones.contains(milestone) {
                playbackMilestones.insert(milestone)
                PTLogger.general.info("Video milestone reached: \(milestone)%")
            }
        }
        
        lastPlaybackPosition = currentTime
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            if configuration.allowsBackgroundAudio {
                try audioSession.setCategory(.playback, mode: .default, options: [])
            } else {
                try audioSession.setCategory(.playback, mode: .moviePlayback, options: [])
            }
            
            try audioSession.setActive(true)
            PTLogger.general.info("Audio session configured for video playback")
            
        } catch {
            PTLogger.general.error("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    private func setupPlayerObservers(_ player: AVPlayer) {
        // Observe external playback (AirPlay) status
        player.publisher(for: \.isExternalPlaybackActive)
            .sink { [weak self] isActive in
                self?.isAirPlayActive = isActive
                PTLogger.general.info("AirPlay \(isActive ? "activated" : "deactivated")")
            }
            .store(in: &cancellables)
        
        // Observe playback rate changes
        player.publisher(for: \.rate)
            .sink { [weak self] rate in
                self?.currentPlaybackSpeed = rate
            }
            .store(in: &cancellables)
        
        // Add time observer for analytics tracking
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let time = CMTime(seconds: 1.0, preferredTimescale: timeScale)
        
        player.addPeriodicTimeObserver(forInterval: time, queue: .main) { [weak self] time in
            let currentTime = CMTimeGetSeconds(time)
            let duration = CMTimeGetSeconds(player.currentItem?.duration ?? CMTime.zero)
            
            Task { @MainActor in
                self?.trackPlaybackProgress(currentTime, duration: duration)
            }
        }
    }
    
    private func setupNowPlayingInfo() {
        guard configuration.enableCustomBranding else { return }
        
        // Configure Now Playing info for Control Center and Lock Screen
        var nowPlayingInfo = [String: Any]()
        
        // This would be populated with actual video metadata
        nowPlayingInfo[MPMediaItemPropertyTitle] = "PT Resources Video"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Proclamation Trust"
        nowPlayingInfo[MPMediaItemPropertyMediaType] = MPMediaType.movie.rawValue
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func updateNowPlayingPlaybackRate() {
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = currentPlaybackSpeed
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - AVPlayerViewControllerDelegate

extension VideoPlayerFeatureManager: AVPlayerViewControllerDelegate {
    
    nonisolated func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        PTLogger.general.info("Will start Picture in Picture")
    }
    
    nonisolated func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        PTLogger.general.info("Picture in Picture started")
        
        Task { @MainActor in
            isPictureInPictureActive = true
            
            // Optionally track PiP usage in analytics
            if configuration.enableAnalytics {
                PTLogger.general.info("Analytics: Picture in Picture activated")
            }
        }
    }
    
    nonisolated func playerViewControllerWillStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        PTLogger.general.info("Will stop Picture in Picture")
    }
    
    nonisolated func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        PTLogger.general.info("Picture in Picture stopped")
        
        Task { @MainActor in
            isPictureInPictureActive = false
        }
    }
    
    nonisolated func playerViewController(
        _ playerViewController: AVPlayerViewController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        PTLogger.general.error("Failed to start Picture in Picture: \(error.localizedDescription)")
    }
    
    nonisolated func playerViewController(
        _ playerViewController: AVPlayerViewController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        // Handle returning from PiP to full screen
        PTLogger.general.info("Restoring UI from Picture in Picture")
        completionHandler(true)
    }
}

// MARK: - Combine Import

import Combine