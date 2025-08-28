//
//  PlayerService.swift
//  PT Resources
//
//  Service for audio playback with speed control, background playback, and Now Playing integration
//

import Foundation
import AVFoundation
import MediaPlayer
import CoreData
import Combine
import UIKit

@MainActor
final class PlayerService: NSObject, ObservableObject {

    // MARK: - Singleton Instance

    static let shared = PlayerService()

    // MARK: - Published Properties

    @Published var currentTalk: Talk?
    @Published var playbackState: PlaybackState = .stopped
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackSpeed: Float = 1.0
    @Published var isBuffering = false
    @Published var chapters: [Chapter] = []
    @Published var currentChapterIndex: Int = 0

    // MARK: - Private Properties

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var timePitchNode: AVAudioUnitTimePitch?

    private var persistenceController: PersistenceController
    private var cancellables = Set<AnyCancellable>()
    private var isAudioSessionConfigured = false
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid

    // Sleep timer
    @Published var sleepTimerMinutes: Int?
    private var sleepTimer: Timer?

    // Queue management
    @Published var playQueue: [Talk] = []
    @Published var currentQueueIndex = 0

    // MARK: - Computed Properties

    var isPlaying: Bool {
        return playbackState == .playing
    }

    // MARK: - Initialization

    private init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        super.init()

        // Defer audio session setup until first audio playback
        setupRemoteTransportControls()
        setupNotificationObservers()
    }
    
    deinit {
        Task { @MainActor in
            cleanup()
        }
    }
    
    // MARK: - Public Methods
    
    func loadTalk(_ talk: Talk, startTime: TimeInterval = 0) {
        cleanup()
        
        self.currentTalk = talk
        self.currentTime = startTime
        
        // Determine audio URL (local or remote)
        let audioURL: URL
        if let localPath = getLocalAudioPath(for: talk.id), FileManager.default.fileExists(atPath: localPath) {
            audioURL = URL(fileURLWithPath: localPath)
        } else if let remoteAudioURL = talk.audioURL {
            guard let url = URL(string: remoteAudioURL) else {
                print("Invalid audio URL for talk: \(talk.id)")
                return
            }
            audioURL = url
        } else {
            print("No audio URL available for talk: \(talk.id)")
            return
        }
        
        // Setup audio session before loading player
        setupAudioSessionIfNeeded()
        
        // Start background task immediately when loading a talk
        // This ensures background task is active if user switches apps quickly after loading
        startBackgroundTask()
        
        setupPlayer(with: audioURL, startTime: startTime)
        updateNowPlayingInfo()
        
        // Load chapters
        loadChapters(for: talk.id)
    }
    
    func play() {
        guard let player = player else { return }

        // Ensure audio session is configured before playing
        setupAudioSessionIfNeeded()

        // Ensure background task is active (may already be started in loadTalk)
        startBackgroundTask()

        player.play()
        playbackState = .playing
        updateNowPlayingInfo()
        startTimeObserver()

        // Save playback state
        savePlaybackState()
    }

    func pause() {
        guard let player = player else { return }

        player.pause()
        playbackState = .paused
        updateNowPlayingInfo()

        // Keep background task active for lock screen controls
        // Only end background task when stopping completely

        // Save playback state
        savePlaybackState()
    }
    
    func stop() {
        cleanup()
        playbackState = .stopped
        currentTime = 0
        currentTalk = nil
        updateNowPlayingInfo()

        // End background task since playback has stopped
        endBackgroundTask()
    }
    
    func seek(to time: TimeInterval) {
        guard let player = player else { return }
        
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime) { [weak self] _ in
            DispatchQueue.main.async {
                self?.currentTime = time
                self?.updateCurrentChapter()
                self?.savePlaybackState()
            }
        }
    }
    
    func skipForward() {
        let newTime = min(currentTime + Config.skipInterval, duration)
        seek(to: newTime)
    }
    
    func skipBackward() {
        let newTime = max(currentTime - Config.skipInterval, 0)
        seek(to: newTime)
    }
    
    func setPlaybackSpeed(_ speed: Float) {
        guard speed >= 0.5 && speed <= 3.0 else { return }
        
        playbackSpeed = speed
        
        if player != nil {
            // Use AVAudioEngine for pitch-corrected speed adjustment
            setupAudioEngineWithSpeed(speed)
        }
        
        updateNowPlayingInfo()
        savePlaybackState()
    }
    
    func jumpToChapter(_ chapter: Chapter) {
        seek(to: chapter.startTime)
    }
    
    func setSleepTimer(minutes: Int) {
        sleepTimer?.invalidate()
        sleepTimerMinutes = minutes
        
        sleepTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.pause()
                self?.sleepTimerMinutes = nil
            }
        }
    }
    
    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimerMinutes = nil
    }
    
    func addToQueue(_ talk: Talk) {
        playQueue.append(talk)
    }
    
    func removeFromQueue(at index: Int) {
        guard index < playQueue.count else { return }
        playQueue.remove(at: index)
        
        if index < currentQueueIndex {
            currentQueueIndex -= 1
        }
    }
    
    func playNext() {
        guard currentQueueIndex < playQueue.count - 1 else { return }
        currentQueueIndex += 1
        loadTalk(playQueue[currentQueueIndex])
        play()
    }
    
    func playPrevious() {
        guard currentQueueIndex > 0 else { return }
        currentQueueIndex -= 1
        loadTalk(playQueue[currentQueueIndex])
        play()
    }
    
    func adjustPlaybackSpeed() {
        let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]
        if let currentIndex = speeds.firstIndex(of: playbackSpeed) {
            playbackSpeed = speeds[(currentIndex + 1) % speeds.count]
        } else {
            playbackSpeed = 1.0
        }
        setupAudioEngineWithSpeed(playbackSpeed)
    }
    
    // MARK: - Private Methods

    private func setupAudioSessionIfNeeded() {
        guard !isAudioSessionConfigured else { return }

        do {
            let audioSession = AVAudioSession.sharedInstance()

            // Configure audio session for background playback
            try audioSession.setCategory(.playback,
                                        mode: .spokenAudio,
                                        options: [.allowAirPlay, .allowBluetooth])

            // Set preferred buffer duration for smooth playback
            try audioSession.setPreferredIOBufferDuration(0.005)

            // Activate the audio session
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            isAudioSessionConfigured = true

            print("Audio session configured successfully for background playback")

        } catch let error as NSError {
            print("Failed to setup audio session: \(error)")
            print("Error domain: \(error.domain), code: \(error.code)")

            // Log additional context for common error codes
            if error.domain == NSOSStatusErrorDomain {
                switch error.code {
                case -50:
                    print("Audio session error -50: Invalid parameter. Check that background audio capability is enabled in Xcode project settings.")
                case -12985:
                    print("Audio session error -12985: Session is not active. This may occur if another app is using the audio session.")
                case -12986:
                    print("Audio session error -12986: Hardware not available. Audio hardware may be in use by another application.")
                default:
                    print("Audio session error code \(error.code) - check AVFoundation documentation for details")
                }
            }

            // Don't set isAudioSessionConfigured to true on failure
        } catch {
            print("Unexpected error setting up audio session: \(error)")
        }
    }

    func startBackgroundTask() {
        guard backgroundTaskIdentifier == .invalid else { return }

        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "AudioPlayback") {
            // Background task expired - system will end it automatically
            // Just clean up our identifier
            self.backgroundTaskIdentifier = .invalid
            print("Background task expired - system ended task automatically")
        }

        print("Started background task for audio playback: \(backgroundTaskIdentifier.rawValue)")
    }

    private func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
            print("Ended background task for audio playback")
        }
    }
    
    private func reactivateAudioSessionIfNeeded() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Check if audio session is active
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                print("Reactivated audio session for lock screen playback")
            }
        } catch {
            print("Failed to reactivate audio session: \(error)")
            // Force reconfiguration on next play
            isAudioSessionConfigured = false
        }
    }
    
    private func setupPlayer(with url: URL, startTime: TimeInterval = 0) {
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Observe player item status
        playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .readyToPlay:
                    self?.duration = playerItem.duration.seconds
                    if startTime > 0 {
                        self?.seek(to: startTime)
                    }
                    self?.isBuffering = false
                case .failed:
                    print("Player item failed: \(playerItem.error?.localizedDescription ?? "Unknown error")")
                    self?.isBuffering = false
                case .unknown:
                    self?.isBuffering = true
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Observe playback end
        NotificationCenter.default
            .publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handlePlaybackEnd()
            }
            .store(in: &cancellables)
        
        // Setup audio engine for speed control
        setupAudioEngineWithSpeed(playbackSpeed)
    }
    
    private func setupAudioEngineWithSpeed(_ speed: Float) {
        // TODO: Implement AVAudioEngine setup for pitch-corrected speed control
        // For now, use basic rate control
        player?.rate = speed
    }
    
    private func startTimeObserver() {
        guard let player = player else { return }
        
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
                self?.updateCurrentChapter()
                
                // Save playback position every 30 seconds
                if Int(time.seconds) % 30 == 0 {
                    self?.savePlaybackState()
                }
            }
        }
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Enable all commands we want to support
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true

        commandCenter.playCommand.addTarget { [weak self] event in
            Task { @MainActor in
                // Ensure audio session is active when responding to lock screen play
                self?.reactivateAudioSessionIfNeeded()
                self?.play()
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] event in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }

        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            Task { @MainActor in
                self?.skipForward()
            }
            return .success
        }

        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            Task { @MainActor in
                self?.skipBackward()
            }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            Task { @MainActor in
                self?.playNext()
            }
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            Task { @MainActor in
                self?.playPrevious()
            }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                Task { @MainActor in
                    self?.seek(to: event.positionTime)
                }
                return .success
            }
            return .commandFailed
        }

        // Configure skip intervals
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: Config.skipInterval)]
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: Config.skipInterval)]

        print("Remote transport controls configured successfully")
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default
            .publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleAudioInterruption(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default
            .publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleAudioRouteChange(notification)
            }
            .store(in: &cancellables)
    }
    
    private func updateNowPlayingInfo() {
        guard let talk = currentTalk else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: talk.title,
            MPMediaItemPropertyArtist: talk.speaker,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: playbackState == .playing ? playbackSpeed : 0.0
        ]
        
        if let series = talk.series {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = series
        }
        
        // TODO: Load and set artwork
        // if let imageURL = talk.imageURL {
        //     loadArtwork(from: imageURL) { artwork in
        //         nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        //         MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        //     }
        // }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func updateCurrentChapter() {
        let chapterIndex = chapters.firstIndex { chapter in
            currentTime >= chapter.startTime && (chapter.endTime == nil || currentTime < chapter.endTime!)
        } ?? 0
        
        if chapterIndex != currentChapterIndex {
            currentChapterIndex = chapterIndex
        }
    }
    
    private func handlePlaybackEnd() {
        // Mark talk as completed
        markTalkAsCompleted()

        // Play next in queue if available
        if currentQueueIndex < playQueue.count - 1 {
            playNext()
        } else {
            // End playback completely
            stop()
        }
    }
    
    private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            pause()
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && playbackState == .paused {
                    play()
                }
            }
        @unknown default:
            break
        }
    }
    
    private func handleAudioRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            // Headphones were unplugged
            pause()
        default:
            break
        }
    }
    
    private func loadChapters(for talkID: String) {
        Task {
            // TODO: Load chapters from API or local cache
            // For now, use empty array
            await MainActor.run {
                self.chapters = []
                self.currentChapterIndex = 0
            }
        }
    }
    
    private func savePlaybackState() {
        guard let talk = currentTalk else { return }
        
        Task {
            try? await persistenceController.performBackgroundTask { context in
                // Find or create playback state entity
                let request: NSFetchRequest<PlaybackStateEntity> = PlaybackStateEntity.fetchRequest()
                request.predicate = NSPredicate(format: "talkID == %@", talk.id)
                
                let entity = try context.fetch(request).first ?? PlaybackStateEntity(context: context)
                
                entity.talkID = talk.id
                entity.position = self.currentTime
                entity.playbackSpeed = self.playbackSpeed
                entity.lastPlayedAt = Date()
                entity.isCompleted = self.currentTime >= self.duration * 0.95 // Consider 95% as completed
            }
        }
    }
    
    private func markTalkAsCompleted() {
        guard let talk = currentTalk else { return }
        
        Task {
            try? await persistenceController.performBackgroundTask { context in
                let request: NSFetchRequest<PlaybackStateEntity> = PlaybackStateEntity.fetchRequest()
                request.predicate = NSPredicate(format: "talkID == %@", talk.id)
                
                let entity = try context.fetch(request).first ?? PlaybackStateEntity(context: context)
                
                entity.talkID = talk.id
                entity.position = self.duration
                entity.playbackSpeed = self.playbackSpeed
                entity.lastPlayedAt = Date()
                entity.isCompleted = true
            }
        }
    }
    
    private func getLocalAudioPath(for talkID: String) -> String? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioPath = documentsPath.appendingPathComponent("audio/\(talkID).mp3")
        return audioPath.path
    }
    
    private func cleanup() {
        player?.pause()

        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        player = nil
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        timePitchNode = nil

        // End background task
        endBackgroundTask()
        
        // Deactivate audio session only when completely stopping
        if isAudioSessionConfigured {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                isAudioSessionConfigured = false
                print("Deactivated audio session")
            } catch {
                print("Failed to deactivate audio session: \(error)")
                // Still reset the flag
                isAudioSessionConfigured = false
            }
        }

        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

enum PlaybackState: String, CaseIterable {
    case stopped = "stopped"
    case playing = "playing"
    case paused = "paused"
    case buffering = "buffering"
    case error = "error"
    
    var isPlaying: Bool {
        return self == .playing
    }
    
    var isPaused: Bool {
        return self == .paused
    }
    
    var canPlay: Bool {
        return self == .stopped || self == .paused
    }
}