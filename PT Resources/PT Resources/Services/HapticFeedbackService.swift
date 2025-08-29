//
//  HapticFeedbackService.swift
//  PT Resources
//
//  Comprehensive haptic feedback service for enhanced user experience
//

import UIKit
import AVFoundation

@MainActor
final class HapticFeedbackService: ObservableObject {
    
    // MARK: - Singleton Instance
    
    static let shared = HapticFeedbackService()
    
    // MARK: - Published Properties
    
    @Published var isHapticsEnabled = true
    
    // MARK: - Private Properties
    
    private var impactFeedbackGenerator: UIImpactFeedbackGenerator?
    private var selectionFeedbackGenerator: UISelectionFeedbackGenerator?
    private var notificationFeedbackGenerator: UINotificationFeedbackGenerator?
    
    // MARK: - Initialization
    
    private init() {
        setupFeedbackGenerators()
        loadHapticsPreference()
    }
    
    // MARK: - Public Methods
    
    /// Generate light impact feedback for subtle interactions
    func lightImpact() {
        guard isHapticsEnabled else { return }
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        
        PTLogger.general.debug("Generated light haptic feedback")
    }
    
    /// Generate medium impact feedback for standard interactions
    func mediumImpact() {
        guard isHapticsEnabled else { return }
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        PTLogger.general.debug("Generated medium haptic feedback")
    }
    
    /// Generate heavy impact feedback for significant interactions
    func heavyImpact() {
        guard isHapticsEnabled else { return }
        
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
        
        PTLogger.general.debug("Generated heavy haptic feedback")
    }
    
    /// Generate selection feedback for picker/selector interactions
    func selection() {
        guard isHapticsEnabled else { return }
        
        if selectionFeedbackGenerator == nil {
            selectionFeedbackGenerator = UISelectionFeedbackGenerator()
        }
        
        selectionFeedbackGenerator?.prepare()
        selectionFeedbackGenerator?.selectionChanged()
        
        PTLogger.general.debug("Generated selection haptic feedback")
    }
    
    /// Generate success notification feedback
    func success() {
        guard isHapticsEnabled else { return }
        
        if notificationFeedbackGenerator == nil {
            notificationFeedbackGenerator = UINotificationFeedbackGenerator()
        }
        
        notificationFeedbackGenerator?.prepare()
        notificationFeedbackGenerator?.notificationOccurred(.success)
        
        PTLogger.general.debug("Generated success haptic feedback")
    }
    
    /// Generate warning notification feedback
    func warning() {
        guard isHapticsEnabled else { return }
        
        if notificationFeedbackGenerator == nil {
            notificationFeedbackGenerator = UINotificationFeedbackGenerator()
        }
        
        notificationFeedbackGenerator?.prepare()
        notificationFeedbackGenerator?.notificationOccurred(.warning)
        
        PTLogger.general.debug("Generated warning haptic feedback")
    }
    
    /// Generate error notification feedback
    func error() {
        guard isHapticsEnabled else { return }
        
        if notificationFeedbackGenerator == nil {
            notificationFeedbackGenerator = UINotificationFeedbackGenerator()
        }
        
        notificationFeedbackGenerator?.prepare()
        notificationFeedbackGenerator?.notificationOccurred(.error)
        
        PTLogger.general.debug("Generated error haptic feedback")
    }
    
    // MARK: - Media-Specific Haptic Patterns
    
    /// Haptic pattern for play button press
    func playButtonPress() {
        heavyImpact()
    }
    
    /// Haptic pattern for pause button press
    func pauseButtonPress() {
        mediumImpact()
    }
    
    /// Haptic pattern for skip forward/backward
    func skipAction() {
        lightImpact()
        
        // Add a second subtle feedback after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.lightImpact()
        }
    }
    
    /// Haptic pattern for speed change
    func speedChange() {
        selection()
    }
    
    /// Haptic pattern for seeking/scrubbing
    func seekingFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.3)
    }
    
    /// Haptic pattern for volume changes
    func volumeChange() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.2)
    }
    
    /// Haptic pattern for chapter transitions
    func chapterTransition() {
        mediumImpact()
        
        // Add a gentle second tap
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.lightImpact()
        }
    }
    
    /// Haptic pattern for download completion
    func downloadComplete() {
        success()
        
        // Add celebration pattern
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.lightImpact()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.lightImpact()
        }
    }
    
    /// Haptic pattern for video transition
    func videoTransition() {
        mediumImpact()
        
        // Add a rising pattern
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred(intensity: 0.7)
        }
    }
    
    // MARK: - Settings
    
    /// Toggle haptic feedback on/off
    func toggleHaptics() {
        isHapticsEnabled.toggle()
        saveHapticsPreference()
        
        // Provide feedback when enabling
        if isHapticsEnabled {
            mediumImpact()
        }
        
        PTLogger.general.info("Haptic feedback \(self.isHapticsEnabled ? "enabled" : "disabled")")
    }
    
    /// Prepare feedback generators for upcoming interactions
    func prepareForMediaInteraction() {
        guard isHapticsEnabled else { return }
        
        // Prepare all generators to reduce latency
        if impactFeedbackGenerator == nil {
            impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        }
        impactFeedbackGenerator?.prepare()
        
        if selectionFeedbackGenerator == nil {
            selectionFeedbackGenerator = UISelectionFeedbackGenerator()
        }
        selectionFeedbackGenerator?.prepare()
    }
    
    // MARK: - Private Methods
    
    private func setupFeedbackGenerators() {
        // Pre-create generators to reduce first-use latency
        impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        selectionFeedbackGenerator = UISelectionFeedbackGenerator()
        notificationFeedbackGenerator = UINotificationFeedbackGenerator()
    }
    
    private func loadHapticsPreference() {
        isHapticsEnabled = UserDefaults.standard.bool(forKey: "PTHapticsEnabled")
        
        // Default to enabled if no preference is set
        if UserDefaults.standard.object(forKey: "PTHapticsEnabled") == nil {
            isHapticsEnabled = true
            saveHapticsPreference()
        }
    }
    
    private func saveHapticsPreference() {
        UserDefaults.standard.set(isHapticsEnabled, forKey: "PTHapticsEnabled")
    }
}

// MARK: - Enhanced Audio Session Service

@MainActor
final class EnhancedAudioSessionService: NSObject, ObservableObject {
    
    // MARK: - Singleton Instance
    
    static let shared = EnhancedAudioSessionService()
    
    // MARK: - Published Properties
    
    @Published var currentRoute: AVAudioSessionRouteDescription?
    @Published var isAirPlayActive = false
    @Published var isHeadphonesConnected = false
    @Published var outputVolume: Float = 0.5
    
    // MARK: - Private Properties
    
    private let audioSession = AVAudioSession.sharedInstance()
    private var routeObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    
    override private init() {
        super.init()
        setupAudioSession()
        observeAudioSessionChanges()
    }
    
    deinit {
        if let observer = routeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public Methods
    
    /// Configure audio session for media playback
    func configureForMediaPlayback() {
        do {
            // Use spokenAudio mode for better talk/sermon playback
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP]
            )
            
            // Set preferred buffer duration for smooth playback
            try audioSession.setPreferredIOBufferDuration(0.005)
            
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            PTLogger.general.info("Audio session configured for media playback with spokenAudio mode")
            
        } catch let error as NSError {
            PTLogger.general.error("Failed to configure audio session: \(error.localizedDescription)")
            PTLogger.general.error("Error domain: \(error.domain), code: \(error.code)")
            
            // Log specific error -50 context
            if error.code == -50 {
                PTLogger.general.error("Audio session error -50: Invalid parameter. Check that background audio capability is enabled in Xcode project settings.")
            }
        }
    }
    
    /// Configure audio session for video playback
    func configureForVideoPlayback() {
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
    
    /// Optimize audio session for background playback
    func optimizeForBackground() {
        do {
            // Ensure the session remains active in background
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP, .mixWithOthers]
            )
            
            PTLogger.general.info("Audio session optimized for background playback")
            
        } catch {
            PTLogger.general.error("Failed to optimize for background: \(error.localizedDescription)")
        }
    }
    
    /// Handle audio interruptions gracefully
    func handleInterruption(_ type: AVAudioSession.InterruptionType, options: AVAudioSession.InterruptionOptions?) {
        switch type {
        case .began:
            PTLogger.general.info("Audio interruption began")
            HapticFeedbackService.shared.warning()
            
        case .ended:
            guard let options = options else { return }
            
            if options.contains(.shouldResume) {
                do {
                    try audioSession.setActive(true)
                    PTLogger.general.info("Audio session resumed after interruption")
                    HapticFeedbackService.shared.lightImpact()
                } catch {
                    PTLogger.general.error("Failed to resume audio session: \(error.localizedDescription)")
                }
            }
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            // Set up initial configuration
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            // Get initial state
            updateAudioRouteInfo()
            outputVolume = audioSession.outputVolume
            
        } catch {
            PTLogger.general.error("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    private func observeAudioSessionChanges() {
        // Observe route changes
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
        
        // Observe volume changes
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
            HapticFeedbackService.shared.lightImpact()
            
        case .oldDeviceUnavailable:
            PTLogger.general.info("Audio device disconnected")
            HapticFeedbackService.shared.mediumImpact()
            
        case .categoryChange:
            PTLogger.general.info("Audio category changed")
            
        case .override:
            PTLogger.general.info("Audio route overridden")
            
        default:
            break
        }
    }
    
    private func updateAudioRouteInfo() {
        currentRoute = audioSession.currentRoute
        
        // Check for AirPlay
        isAirPlayActive = currentRoute?.outputs.contains { output in
            output.portType == .airPlay
        } ?? false
        
        // Check for headphones
        isHeadphonesConnected = currentRoute?.outputs.contains { output in
            output.portType == .headphones || 
            output.portType == .bluetoothA2DP ||
            output.portType == .bluetoothHFP ||
            output.portType == .bluetoothLE
        } ?? false
        
        PTLogger.general.debug("Audio route updated - AirPlay: \(self.isAirPlayActive), Headphones: \(self.isHeadphonesConnected)")
    }
    
    // MARK: - KVO
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "outputVolume" {
            self.outputVolume = audioSession.outputVolume
            PTLogger.general.debug("Output volume changed to \(self.outputVolume)")
        }
    }
}