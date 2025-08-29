//
//  PTVideoPlayerViewController.swift
//  PT Resources
//
//  Custom wrapper around AVPlayerViewController with PT-specific enhancements
//

import UIKit
import AVKit
import AVFoundation

class PTVideoPlayerViewController: AVPlayerViewController {
    
    // MARK: - Properties
    
    private let resourceTitle: String?
    private let resourceSpeaker: String?
    private var loadingIndicator: UIActivityIndicatorView?
    private var errorView: PTVideoErrorView?
    
    // Analytics and tracking
    private var playbackStartTime: Date?
    private var totalPlaybackTime: TimeInterval = 0
    
    // MARK: - Initialization
    
    init(title: String? = nil, speaker: String? = nil) {
        self.resourceTitle = title
        self.resourceSpeaker = speaker
        super.init(nibName: nil, bundle: nil)
        
        setupVideoPlayer()
    }
    
    required init?(coder: NSCoder) {
        self.resourceTitle = nil
        self.resourceSpeaker = nil
        super.init(coder: coder)
        
        setupVideoPlayer()
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupNotificationObservers()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Track video viewing session
        playbackStartTime = Date()
        PTLogger.general.info("Video player presented for: \(self.resourceTitle ?? "Unknown")")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Calculate and log playback time
        if let startTime = playbackStartTime {
            totalPlaybackTime += Date().timeIntervalSince(startTime)
            PTLogger.general.info("Video playback session ended. Total time: \(self.totalPlaybackTime)s")
        }
    }
    
    deinit {
        removeNotificationObservers()
        PTLogger.general.debug("PTVideoPlayerViewController deallocated")
    }
    
    // MARK: - Public Methods
    
    /// Load and play a video from URL
    func loadVideo(from url: URL) {
        showLoadingIndicator()
        hideErrorView()
        
        Task {
            do {
                let processedURL = try await VideoURLDetector.shared.processVideoURL(url)
                await MainActor.run {
                    setupPlayerWithURL(processedURL)
                }
            } catch {
                await MainActor.run {
                    showError(error)
                }
            }
        }
    }
    
    /// Show error state with retry option
    func showError(_ error: Error) {
        hideLoadingIndicator()
        
        let errorView = PTVideoErrorView(error: error) { [weak self] in
            self?.retryLoad()
        }
        
        showErrorView(errorView)
    }
    
    // MARK: - Private Setup Methods
    
    private func setupVideoPlayer() {
        // Configure player settings
        allowsPictureInPicturePlayback = true
        canStartPictureInPictureAutomaticallyFromInline = false
        
        // Enable speed controls
        if #available(iOS 16.0, *) {
            speeds = [AVPlaybackSpeed(rate: 0.5, localizedName: "0.5x"), AVPlaybackSpeed(rate: 0.75, localizedName: "0.75x"), AVPlaybackSpeed(rate: 1.0, localizedName: "1x"), AVPlaybackSpeed(rate: 1.25, localizedName: "1.25x"), AVPlaybackSpeed(rate: 1.5, localizedName: "1.5x"), AVPlaybackSpeed(rate: 2.0, localizedName: "2x")]
        }
        
        // Configure delegate
        delegate = self
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Customize appearance for PT branding
        if let title = resourceTitle {
            navigationItem.title = title
        }
        
        // Add custom controls overlay if needed
        setupCustomControls()
    }
    
    private func setupCustomControls() {
        // This could be expanded to add PT-specific controls or branding
        // For now, we rely on the standard AVPlayerViewController controls
    }
    
    private func setupPlayerWithURL(_ url: URL) {
        hideLoadingIndicator()
        
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        
        // Configure player
        player.automaticallyWaitsToMinimizeStalling = true
        
        // Set up player item observers
        setupPlayerItemObservers(playerItem)
        
        // Assign player
        self.player = player
        
        PTLogger.general.info("Video player configured with URL: \(url)")
    }
    
    private func setupPlayerItemObservers(_ playerItem: AVPlayerItem) {
        // Observe player status
        playerItem.addObserver(self, forKeyPath: "status", options: [.new, .old], context: nil)
        
        // Observe loading state
        playerItem.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .new, context: nil)
        
        // Observe end of playback
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        // Observe playback stalls
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerStalled),
            name: .AVPlayerItemPlaybackStalled,
            object: playerItem
        )
    }
    
    private func setupNotificationObservers() {
        // App lifecycle notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self)
        
        // Remove KVO observers
        player?.currentItem?.removeObserver(self, forKeyPath: "status")
        player?.currentItem?.removeObserver(self, forKeyPath: "playbackBufferEmpty")
        player?.currentItem?.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
    }
    
    // MARK: - UI Helper Methods
    
    private func showLoadingIndicator() {
        if loadingIndicator == nil {
            let indicator = UIActivityIndicatorView(style: .large)
            indicator.color = .systemBlue
            indicator.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(indicator)
            
            NSLayoutConstraint.activate([
                indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
            
            loadingIndicator = indicator
        }
        
        loadingIndicator?.startAnimating()
    }
    
    private func hideLoadingIndicator() {
        loadingIndicator?.stopAnimating()
        loadingIndicator?.removeFromSuperview()
        loadingIndicator = nil
    }
    
    private func showErrorView(_ errorView: PTVideoErrorView) {
        hideErrorView()
        
        errorView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorView)
        
        NSLayoutConstraint.activate([
            errorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            errorView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
        
        self.errorView = errorView
    }
    
    private func hideErrorView() {
        errorView?.removeFromSuperview()
        errorView = nil
    }
    
    private func retryLoad() {
        // This would need the original URL to retry - could be stored as a property
        PTLogger.general.info("User requested video retry")
        // Implementation depends on how the original URL is stored
    }
    
    // MARK: - Notification Handlers
    
    @objc private func playerDidFinishPlaying() {
        PTLogger.general.info("Video playback finished")
        
        // Could trigger analytics or suggested content here
        if let startTime = playbackStartTime {
            totalPlaybackTime += Date().timeIntervalSince(startTime)
        }
    }
    
    @objc private func playerStalled() {
        PTLogger.general.warning("Video playback stalled")
        showLoadingIndicator()
    }
    
    @objc private func appDidEnterBackground() {
        PTLogger.general.debug("Video player app entering background")
    }
    
    @objc private func appWillEnterForeground() {
        PTLogger.general.debug("Video player app entering foreground")
    }
    
    // MARK: - KVO Observer
    
    override func observeValue(forKeyPath keyPath: String?, 
                              of object: Any?, 
                              change: [NSKeyValueChangeKey : Any]?, 
                              context: UnsafeMutableRawPointer?) {
        
        guard let keyPath = keyPath else { return }
        
        switch keyPath {
        case "status":
            handlePlayerStatusChange()
            
        case "playbackBufferEmpty":
            if player?.currentItem?.isPlaybackBufferEmpty == true {
                showLoadingIndicator()
            }
            
        case "playbackLikelyToKeepUp":
            if player?.currentItem?.isPlaybackLikelyToKeepUp == true {
                hideLoadingIndicator()
            }
            
        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    private func handlePlayerStatusChange() {
        guard let player = player else { return }
        
        switch player.status {
        case .readyToPlay:
            hideLoadingIndicator()
            PTLogger.general.info("Video ready to play")
            
        case .failed:
            if let error = player.error {
                showError(error)
            }
            
        case .unknown:
            PTLogger.general.debug("Video player status unknown")
            
        @unknown default:
            PTLogger.general.warning("Unknown video player status")
        }
    }
}

// MARK: - AVPlayerViewControllerDelegate

extension PTVideoPlayerViewController: AVPlayerViewControllerDelegate {
    
    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        PTLogger.general.info("Starting Picture in Picture")
    }
    
    func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        PTLogger.general.info("Picture in Picture started")
    }
    
    func playerViewControllerWillStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        PTLogger.general.info("Stopping Picture in Picture")
    }
    
    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        PTLogger.general.info("Picture in Picture stopped")
    }
    
    func playerViewController(_ playerViewController: AVPlayerViewController, 
                            willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        PTLogger.general.debug("Entering full screen video")
    }
    
    func playerViewController(_ playerViewController: AVPlayerViewController, 
                            willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        PTLogger.general.debug("Exiting full screen video")
    }
}

// MARK: - Error View

class PTVideoErrorView: UIView {
    
    private let error: Error
    private let retryAction: () -> Void
    
    init(error: Error, retryAction: @escaping () -> Void) {
        self.error = error
        self.retryAction = retryAction
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor.systemBackground
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 8
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Error icon
        let iconImageView = UIImageView(image: UIImage(systemName: "exclamationmark.triangle"))
        iconImageView.tintColor = .systemRed
        iconImageView.contentMode = .scaleAspectFit
        
        // Error title
        let titleLabel = UILabel()
        titleLabel.text = "Video Unavailable"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        
        // Error message
        let messageLabel = UILabel()
        messageLabel.text = error.localizedDescription
        messageLabel.font = UIFont.systemFont(ofSize: 14)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        
        // Retry button
        let retryButton = UIButton(type: .system)
        retryButton.setTitle("Retry", for: .normal)
        retryButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        retryButton.backgroundColor = .systemBlue
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.layer.cornerRadius = 8
        // Note: contentEdgeInsets is deprecated in iOS 15.0, but we're using it for backward compatibility
        retryButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        
        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(messageLabel)
        stackView.addArrangedSubview(retryButton)
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            iconImageView.heightAnchor.constraint(equalToConstant: 48),
            iconImageView.widthAnchor.constraint(equalToConstant: 48),
            
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
            
            messageLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 280)
        ])
    }
    
    @objc private func retryTapped() {
        retryAction()
    }
}