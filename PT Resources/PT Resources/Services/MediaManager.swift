//
//  MediaManager.swift
//  PT Resources
//
//  Unified media management service consolidating artwork, haptics, transitions, and widgets
//

import Foundation
import UIKit
import AVFoundation
import MediaPlayer
import SwiftUI
import Combine

// MARK: - Media Manager Protocol

@MainActor
protocol MediaManagerProtocol {
    // Artwork
    func generateArtwork(for talk: Talk) async -> UIImage?
    func generateArtwork(for resource: ResourceDetail) async -> UIImage?
    
    // Haptics
    func playButtonPress()
    func pauseButtonPress()
    func skipAction()
    func speedChange()
    func downloadComplete()
    func videoTransition()
    
    // Widget/Now Playing
    func updateNowPlaying(for resource: ResourceDetail, isPlaying: Bool, currentTime: TimeInterval, duration: TimeInterval)
    func clearNowPlaying()
    
    // Transitions
    func transitionFromVideoToAudio(resource: ResourceDetail, currentTime: TimeInterval) async
}

// MARK: - Unified Media Manager

@MainActor
final class MediaManager: NSObject, ObservableObject, MediaManagerProtocol {
    
    // MARK: - Published Properties
    
    @Published var currentArtwork: UIImage?
    @Published var isGeneratingArtwork = false
    @Published var isHapticsEnabled = true
    @Published var isTransitioning = false
    @Published var transitionProgress: Double = 0.0
    @Published var isWidgetActive = false
    
    // Audio Session
    @Published var currentRoute: AVAudioSessionRouteDescription?
    @Published var isAirPlayActive = false
    @Published var isHeadphonesConnected = false
    @Published var outputVolume: Float = 0.5
    
    // MARK: - Private Properties
    
    // Artwork caching
    private let artworkCache = NSCache<NSString, UIImage>()
    private let artworkSize = CGSize(width: 512, height: 512)
    
    // Haptics
    private var impactFeedbackGenerator: UIImpactFeedbackGenerator?
    private var selectionFeedbackGenerator: UISelectionFeedbackGenerator?
    private var notificationFeedbackGenerator: UINotificationFeedbackGenerator?
    
    // Now Playing & Remote Controls
    private let nowPlayingCenter = MPNowPlayingInfoCenter.default()
    private let remoteCommandCenter = MPRemoteCommandCenter.shared()
    
    // Audio Session
    private let audioSession = AVAudioSession.sharedInstance()
    private var routeObserver: NSObjectProtocol?
    
    // Transitions
    private var transitionAnimator: UIViewPropertyAnimator?
    private var currentResource: ResourceDetail?
    private var savedPlaybackTime: TimeInterval = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupArtworkCache()
        setupHaptics()
        setupNowPlayingControls()
        setupAudioSession()
        loadPreferences()
        observeAudioSessionChanges()
    }
    
    deinit {
        if let observer = routeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        audioSession.removeObserver(self, forKeyPath: "outputVolume")
    }
    
    // MARK: - Artwork Management
    
    func generateArtwork(for talk: Talk) async -> UIImage? {
        let cacheKey = "talk_\(talk.id)" as NSString
        
        if let cachedImage = artworkCache.object(forKey: cacheKey) {
            await MainActor.run {
                currentArtwork = cachedImage
            }
            return cachedImage
        }
        
        await MainActor.run {
            isGeneratingArtwork = true
        }
        
        var artwork: UIImage?
        
        if let artworkURL = talk.artworkURL, let url = URL(string: artworkURL) {
            artwork = await loadRemoteImage(from: url)
        }
        
        if artwork == nil {
            artwork = generateDefaultArtwork()
        }
        
        if let finalArtwork = artwork {
            artworkCache.setObject(finalArtwork, forKey: cacheKey)
        }
        
        await MainActor.run {
            currentArtwork = artwork
            isGeneratingArtwork = false
        }
        
        return artwork
    }
    
    func generateArtwork(for resource: ResourceDetail) async -> UIImage? {
        let cacheKey = "resource_\(resource.id)" as NSString
        
        if let cachedImage = artworkCache.object(forKey: cacheKey) {
            await MainActor.run {
                currentArtwork = cachedImage
            }
            return cachedImage
        }
        
        await MainActor.run {
            isGeneratingArtwork = true
        }
        
        var artwork: UIImage?
        
        if let url = resource.resourceImageURL {
            artwork = await loadRemoteImage(from: url)
        }
        
        if artwork == nil {
            artwork = generateDefaultArtwork()
        }
        
        if let finalArtwork = artwork {
            artworkCache.setObject(finalArtwork, forKey: cacheKey)
        }
        
        await MainActor.run {
            currentArtwork = artwork
            isGeneratingArtwork = false
        }
        
        return artwork
    }
    
    // MARK: - Haptic Feedback
    
    func playButtonPress() {
        guard isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func pauseButtonPress() {
        guard isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func skipAction() {
        guard isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            generator.impactOccurred()
        }
    }
    
    func speedChange() {
        guard isHapticsEnabled else { return }
        if selectionFeedbackGenerator == nil {
            selectionFeedbackGenerator = UISelectionFeedbackGenerator()
        }
        selectionFeedbackGenerator?.prepare()
        selectionFeedbackGenerator?.selectionChanged()
    }
    
    func downloadComplete() {
        guard isHapticsEnabled else { return }
        if notificationFeedbackGenerator == nil {
            notificationFeedbackGenerator = UINotificationFeedbackGenerator()
        }
        notificationFeedbackGenerator?.prepare()
        notificationFeedbackGenerator?.notificationOccurred(.success)
        
        // Add celebration pattern
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        }
    }
    
    func videoTransition() {
        guard isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
            heavyGenerator.prepare()
            heavyGenerator.impactOccurred(intensity: 0.7)
        }
    }
    
    // MARK: - Now Playing & Widget Management
    
    func updateNowPlaying(for resource: ResourceDetail, isPlaying: Bool, currentTime: TimeInterval, duration: TimeInterval) {
        var nowPlayingInfo = [String: Any]()
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = resource.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = resource.speaker
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = resource.conference.isEmpty ? "PT Resources" : resource.conference
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        if let artwork = currentArtwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in
                return artwork
            }
        }
        
        nowPlayingCenter.nowPlayingInfo = nowPlayingInfo
        isWidgetActive = true
        
        PTLogger.general.info("Updated Now Playing info for: \(resource.title)")
    }
    
    func clearNowPlaying() {
        nowPlayingCenter.nowPlayingInfo = nil
        isWidgetActive = false
        PTLogger.general.info("Cleared Now Playing info")
    }
    
    // MARK: - Media Transitions
    
    func transitionFromVideoToAudio(resource: ResourceDetail, currentTime: TimeInterval) async {
        guard !isTransitioning else { return }
        
        PTLogger.general.info("Starting video to audio transition")
        
        isTransitioning = true
        transitionProgress = 0.0
        currentResource = resource
        savedPlaybackTime = currentTime
        
        videoTransition()
        
        // Simulate transition progress
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for i in 0...10 {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    await MainActor.run {
                        self.transitionProgress = Double(i) / 10.0
                    }
                }
            }
        }
        
        await configureForAudioPlayback()
        
        await MainActor.run {
            isTransitioning = false
            transitionProgress = 1.0
        }
        
        PTLogger.general.info("Video to audio transition completed")
    }
    
    // MARK: - Audio Session Management
    
    func configureForAudioPlayback() async {
        do {
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [
                    .allowAirPlay,
                    .allowBluetooth,
                    .allowBluetoothA2DP,
                    .defaultToSpeaker
                ]
            )
            
            try audioSession.setPreferredIOBufferDuration(0.005)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            PTLogger.general.info("Audio session configured for audio playback")
            
        } catch {
            PTLogger.general.error("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
    
    func configureForVideoPlayback() async {
        do {
            try audioSession.setCategory(
                .playback,
                mode: .moviePlayback,
                options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP]
            )
            
            try audioSession.setActive(true)
            PTLogger.general.info("Audio session configured for video playback")
            
        } catch {
            PTLogger.general.error("Failed to configure audio session for video: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Settings
    
    func toggleHaptics() {
        isHapticsEnabled.toggle()
        UserDefaults.standard.set(isHapticsEnabled, forKey: "PTHapticsEnabled")
        
        if isHapticsEnabled {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        }
        
        PTLogger.general.info("Haptic feedback \(self.isHapticsEnabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Private Methods
    
    private func setupArtworkCache() {
        artworkCache.countLimit = 50
        artworkCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    private func setupHaptics() {
        impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        selectionFeedbackGenerator = UISelectionFeedbackGenerator()
        notificationFeedbackGenerator = UINotificationFeedbackGenerator()
    }
    
    private func setupNowPlayingControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            NotificationCenter.default.post(name: .remotePlayCommand, object: nil)
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            NotificationCenter.default.post(name: .remotePauseCommand, object: nil)
            return .success
        }
        
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: 30)]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            NotificationCenter.default.post(name: .remoteSkipForwardCommand, object: nil)
            return .success
        }
        
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: 30)]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            NotificationCenter.default.post(name: .remoteSkipBackwardCommand, object: nil)
            return .success
        }
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            updateAudioRouteInfo()
            outputVolume = audioSession.outputVolume
            
        } catch {
            PTLogger.general.error("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    private func observeAudioSessionChanges() {
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
        
        audioSession.addObserver(self, forKeyPath: "outputVolume", options: .new, context: nil)
    }
    
    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonRaw = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw) else {
            return
        }
        
        updateAudioRouteInfo()
        
        switch reason {
        case .newDeviceAvailable:
            PTLogger.general.info("New audio device available")
        case .oldDeviceUnavailable:
            PTLogger.general.info("Audio device disconnected")
        default:
            break
        }
    }
    
    private func updateAudioRouteInfo() {
        currentRoute = audioSession.currentRoute
        
        isAirPlayActive = currentRoute?.outputs.contains { output in
            output.portType == .airPlay
        } ?? false
        
        isHeadphonesConnected = currentRoute?.outputs.contains { output in
            output.portType == .headphones ||
            output.portType == .bluetoothA2DP ||
            output.portType == .bluetoothHFP ||
            output.portType == .bluetoothLE
        } ?? false
    }
    
    private func loadPreferences() {
        isHapticsEnabled = UserDefaults.standard.bool(forKey: "PTHapticsEnabled")
        if UserDefaults.standard.object(forKey: "PTHapticsEnabled") == nil {
            isHapticsEnabled = true
            UserDefaults.standard.set(isHapticsEnabled, forKey: "PTHapticsEnabled")
        }
    }
    
    private func loadRemoteImage(from url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            PTLogger.general.error("Failed to load remote image: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func generateDefaultArtwork() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: artworkSize)
        return renderer.image { context in
            // PT brand background
            UIColor(PTDesignTokens.Colors.surface).setFill()
            context.fill(CGRect(origin: .zero, size: artworkSize))
            
            // PT logo in center
            let logoSize = CGSize(width: 200, height: 200)
            let logoRect = CGRect(
                x: (artworkSize.width - logoSize.width) / 2,
                y: (artworkSize.height - logoSize.height) / 2,
                width: logoSize.width,
                height: logoSize.height
            )
            
            UIColor(PTDesignTokens.Colors.tang).setFill()
            context.cgContext.fillEllipse(in: logoRect)
            
            // PT text
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            
            let text = "PT"
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: logoRect.midX - textSize.width / 2,
                y: logoRect.midY - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    // MARK: - KVO
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "outputVolume" {
            self.outputVolume = audioSession.outputVolume
        }
    }
}

// MARK: - Remote Command Notifications

extension Notification.Name {
    static let remotePlayCommand = Notification.Name("remotePlayCommand")
    static let remotePauseCommand = Notification.Name("remotePauseCommand")
    static let remoteSkipForwardCommand = Notification.Name("remoteSkipForwardCommand")
    static let remoteSkipBackwardCommand = Notification.Name("remoteSkipBackwardCommand")
}