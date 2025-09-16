//
//  MediaWidgetService.swift
//  PT Resources
//
//  Comprehensive media widget service for lock screen, Control Center, and dynamic island integration
//

import Foundation
import UIKit
import MediaPlayer
import SwiftUI
import Combine

@MainActor
final class MediaWidgetService: ObservableObject {
    
    // MARK: - Singleton Instance
    
    static let shared = MediaWidgetService()
    
    // MARK: - Published Properties
    
    @Published var isWidgetActive = false
    @Published var currentActivity: Any? // Placeholder for Activity Kit
    @Published var widgetDisplayMode: WidgetDisplayMode = .standard
    
    // MARK: - Private Properties
    
    private let nowPlayingCenter = MPNowPlayingInfoCenter.default()
    private let remoteCommandCenter = MPRemoteCommandCenter.shared()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupRemoteCommandCenter()
        observePlayerState()
    }
    
    // MARK: - Public Methods
    
    /// Initialize comprehensive media widget with rich metadata
    func initializeMediaWidget(
        for resource: ResourceDetail,
        artwork: UIImage?,
        isPlaying: Bool,
        currentTime: TimeInterval,
        duration: TimeInterval
    ) async {
        
        await updateNowPlayingInfo(
            resource: resource,
            artwork: artwork,
            isPlaying: isPlaying,
            currentTime: currentTime,
            duration: duration
        )
        
        await startDynamicIslandActivity(
            resource: resource,
            artwork: artwork,
            isPlaying: isPlaying
        )
        
        isWidgetActive = true
        
        PTLogger.general.info("Initialized comprehensive media widget for: \(resource.title)")
    }
    
    /// Update widget state with current playback information
    func updateWidgetState(
        isPlaying: Bool,
        currentTime: TimeInterval,
        duration: TimeInterval,
        playbackRate: Float = 1.0
    ) {
        
        // Update Now Playing info
        var currentInfo = nowPlayingCenter.nowPlayingInfo ?? [:]
        currentInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        currentInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0
        currentInfo[MPMediaItemPropertyPlaybackDuration] = duration
        
        nowPlayingCenter.nowPlayingInfo = currentInfo
        
        // Update Dynamic Island activity
        updateDynamicIslandActivity(
            isPlaying: isPlaying,
            currentTime: currentTime,
            duration: duration
        )
        
        PTLogger.general.debug("Updated media widget state - Playing: \(isPlaying), Time: \(currentTime)")
    }
    
    /// Clear all media widget states
    func clearMediaWidget() {
        // Clear Now Playing info
        nowPlayingCenter.nowPlayingInfo = nil
        
        // End Dynamic Island activity
        endDynamicIslandActivity()
        
        isWidgetActive = false
        
        PTLogger.general.info("Cleared media widget")
    }
    
    /// Handle remote command events
    func setupRemoteCommandHandlers(
        onPlayPause: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPrevious: @escaping () -> Void,
        onSeek: @escaping (TimeInterval) -> Void,
        onChangePlaybackRate: @escaping (Float) -> Void
    ) {
        
        // Play/Pause command
        remoteCommandCenter.playCommand.addTarget { _ in
            PTHapticFeedbackService.shared.playButtonPress()
            onPlayPause()
            return .success
        }
        
        remoteCommandCenter.pauseCommand.addTarget { _ in
            PTHapticFeedbackService.shared.pauseButtonPress()
            onPlayPause()
            return .success
        }
        
        remoteCommandCenter.togglePlayPauseCommand.addTarget { _ in
            PTHapticFeedbackService.shared.playButtonPress()
            onPlayPause()
            return .success
        }
        
        // Skip commands
        remoteCommandCenter.nextTrackCommand.addTarget { _ in
            PTHapticFeedbackService.shared.skipAction()
            onNext()
            return .success
        }
        
        remoteCommandCenter.previousTrackCommand.addTarget { _ in
            PTHapticFeedbackService.shared.skipAction()
            onPrevious()
            return .success
        }
        
        // Skip intervals
        remoteCommandCenter.skipForwardCommand.addTarget { event in
            if let skipEvent = event as? MPSkipIntervalCommandEvent {
                PTHapticFeedbackService.shared.skipAction()
                onSeek(skipEvent.interval)
                return .success
            }
            return .commandFailed
        }
        
        remoteCommandCenter.skipBackwardCommand.addTarget { event in
            if let skipEvent = event as? MPSkipIntervalCommandEvent {
                PTHapticFeedbackService.shared.skipAction()
                onSeek(-skipEvent.interval)
                return .success
            }
            return .commandFailed
        }
        
        // Playback position
        remoteCommandCenter.changePlaybackPositionCommand.addTarget { event in
            if let positionEvent = event as? MPChangePlaybackPositionCommandEvent {
                PTHapticFeedbackService.shared.seekingFeedback()
                onSeek(positionEvent.positionTime)
                return .success
            }
            return .commandFailed
        }
        
        // Playback rate
        remoteCommandCenter.changePlaybackRateCommand.addTarget { event in
            if let rateEvent = event as? MPChangePlaybackRateCommandEvent {
                PTHapticFeedbackService.shared.speedChange()
                onChangePlaybackRate(rateEvent.playbackRate)
                return .success
            }
            return .commandFailed
        }
        
        PTLogger.general.info("Configured remote command handlers")
    }
    
    // MARK: - Private Methods - Now Playing
    
    private func updateNowPlayingInfo(
        resource: ResourceDetail,
        artwork: UIImage?,
        isPlaying: Bool,
        currentTime: TimeInterval,
        duration: TimeInterval
    ) async {
        
        // Generate high-quality artwork if not provided
        let finalArtwork: UIImage?
        if let artwork = artwork {
            finalArtwork = artwork
        } else {
            finalArtwork = await MediaArtworkService.shared.generateArtwork(for: resource)
        }
        
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: resource.title,
            MPMediaItemPropertyArtist: resource.speaker,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPMediaItemPropertyMediaType: MPMediaType.podcast.rawValue,
            MPMediaItemPropertyGenre: "Sermon",
            MPMediaItemPropertyComments: "Proclamation Trust Resources"
        ]
        
        // Add conference/series information
        if !resource.conference.isEmpty {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = resource.conference
        }
        
        // Add high-resolution artwork
        if let artwork = finalArtwork {
            let mpArtwork = MPMediaItemArtwork(boundsSize: CGSize(width: 512, height: 512)) { _ in artwork }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = mpArtwork
        }
        
        // Add additional metadata for richer experience
        nowPlayingInfo[MPMediaItemPropertyPodcastTitle] = "PT Resources"
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = false
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        
        // Enhanced playback info
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        nowPlayingInfo[MPNowPlayingInfoPropertyAvailableLanguageOptions] = ["en"]
        nowPlayingInfo[MPNowPlayingInfoPropertyCurrentLanguageOptions] = ["en"]
        
        nowPlayingCenter.nowPlayingInfo = nowPlayingInfo
    }
    
    // MARK: - Private Methods - Dynamic Island
    
    private func startDynamicIslandActivity(
        resource: ResourceDetail,
        artwork: UIImage?,
        isPlaying: Bool
    ) async {
        // Dynamic Island functionality would be implemented here with ActivityKit
        // Currently disabled for build compatibility
        PTLogger.general.info("Dynamic Island activity would start here (ActivityKit integration)")
    }
    
    private func updateDynamicIslandActivity(
        isPlaying: Bool,
        currentTime: TimeInterval,
        duration: TimeInterval
    ) {
        // Update Dynamic Island activity (ActivityKit integration)
        PTLogger.general.debug("Dynamic Island update: Playing: \(isPlaying), Time: \(currentTime)")
    }
    
    private func endDynamicIslandActivity() {
        // End Dynamic Island activity (ActivityKit integration)
        currentActivity = nil
        PTLogger.general.info("Dynamic Island activity ended")
    }
    
    // MARK: - Private Methods - Setup
    
    private func setupRemoteCommandCenter() {
        // Enable relevant commands
        remoteCommandCenter.playCommand.isEnabled = true
        remoteCommandCenter.pauseCommand.isEnabled = true
        remoteCommandCenter.togglePlayPauseCommand.isEnabled = true
        remoteCommandCenter.nextTrackCommand.isEnabled = true
        remoteCommandCenter.previousTrackCommand.isEnabled = true
        remoteCommandCenter.changePlaybackPositionCommand.isEnabled = true
        remoteCommandCenter.changePlaybackRateCommand.isEnabled = true
        
        // Configure skip intervals
        remoteCommandCenter.skipForwardCommand.isEnabled = true
        remoteCommandCenter.skipForwardCommand.preferredIntervals = [15, 30] // 15 and 30 seconds
        
        remoteCommandCenter.skipBackwardCommand.isEnabled = true
        remoteCommandCenter.skipBackwardCommand.preferredIntervals = [15, 30]
        
        // Configure playback rates
        remoteCommandCenter.changePlaybackRateCommand.supportedPlaybackRates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    }
    
    private func observePlayerState() {
        // Note: PlayerService doesn't have @Published properties, so we'll update manually
        // This would typically be done through notifications or direct updates from the UI
        PTLogger.general.info("Media widget service initialized - manual state updates required")
    }
    
    private func handlePlaybackStateChange(isPlaying: Bool) {
        guard isWidgetActive else { return }
        
        // Update Now Playing playback rate
        if var currentInfo = nowPlayingCenter.nowPlayingInfo {
            currentInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
            nowPlayingCenter.nowPlayingInfo = currentInfo
        }
        
        // Update Dynamic Island (would need to be called manually with proper parameters)
        // updateDynamicIslandActivity(isPlaying: isPlaying, currentTime: currentTime, duration: duration)
    }
    
    private func handleTimeUpdate(currentTime: TimeInterval) {
        guard isWidgetActive else { return }
        
        // Update Now Playing elapsed time
        if var currentInfo = nowPlayingCenter.nowPlayingInfo {
            currentInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            nowPlayingCenter.nowPlayingInfo = currentInfo
        }
    }
}

// MARK: - Widget Display Mode

enum WidgetDisplayMode {
    case standard
    case compact
    case expanded
    case dynamicIsland
}

// MARK: - Dynamic Island Activity Attributes (Placeholder)
// ActivityKit integration would be implemented here for iOS 16.1+

// MARK: - Enhanced Remote Command Extension

extension MediaWidgetService {
    
    /// Configure advanced remote commands with custom intervals and rates
    func configureAdvancedRemoteCommands() {
        // Like/Unlike commands for favorites
        remoteCommandCenter.likeCommand.isEnabled = true
        remoteCommandCenter.dislikeCommand.isEnabled = true
        
        // Bookmark command for saving position
        remoteCommandCenter.bookmarkCommand.isEnabled = true
        
        // Language options for transcripts
        remoteCommandCenter.enableLanguageOptionCommand.isEnabled = true
        remoteCommandCenter.disableLanguageOptionCommand.isEnabled = true
        
        PTLogger.general.info("Configured advanced remote commands")
    }
    
    /// Handle advanced command events
    func setupAdvancedCommandHandlers(
        onToggleFavorite: @escaping () -> Void,
        onBookmark: @escaping () -> Void,
        onToggleTranscript: @escaping () -> Void
    ) {
        
        remoteCommandCenter.likeCommand.addTarget { _ in
            PTHapticFeedbackService.shared.success()
            onToggleFavorite()
            return .success
        }
        
        remoteCommandCenter.bookmarkCommand.addTarget { _ in
            PTHapticFeedbackService.shared.mediumImpact()
            onBookmark()
            return .success
        }
        
        remoteCommandCenter.enableLanguageOptionCommand.addTarget { _ in
            PTHapticFeedbackService.shared.selection()
            onToggleTranscript()
            return .success
        }
    }
}