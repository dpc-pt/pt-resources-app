//
//  SimpleHapticService.swift
//  PT Resources
//
//  Simplified haptic feedback service for enhanced user experience
//

import UIKit

@MainActor
final class SimpleHapticService: ObservableObject {
    
    static let shared = SimpleHapticService()
    
    @Published var isHapticsEnabled = true
    
    private init() {
        loadHapticsPreference()
    }
    
    func lightImpact() {
        guard isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func mediumImpact() {
        guard isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func heavyImpact() {
        guard isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func selection() {
        guard isHapticsEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    func success() {
        guard isHapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    func warning() {
        guard isHapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
    
    func error() {
        guard isHapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
    
    // MARK: - Media-Specific Patterns
    
    func playButtonPress() {
        heavyImpact()
    }
    
    func pauseButtonPress() {
        mediumImpact()
    }
    
    func skipAction() {
        lightImpact()
    }
    
    func speedChange() {
        selection()
    }
    
    func seekingFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.3)
    }
    
    func videoTransition() {
        mediumImpact()
    }
    
    private func loadHapticsPreference() {
        isHapticsEnabled = UserDefaults.standard.bool(forKey: "PTHapticsEnabled")
        if UserDefaults.standard.object(forKey: "PTHapticsEnabled") == nil {
            isHapticsEnabled = true
            UserDefaults.standard.set(isHapticsEnabled, forKey: "PTHapticsEnabled")
        }
    }
}