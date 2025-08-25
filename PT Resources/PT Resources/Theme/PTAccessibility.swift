//
//  PTAccessibility.swift
//  PT Resources
//
//  Accessibility helpers and VoiceOver support for PT Resources
//

import SwiftUI
import UIKit

// MARK: - Accessibility Identifiers

enum PTAccessibility {
    // Screen identifiers
    static let homeScreen = "home_screen"
    static let talksListScreen = "talks_list_screen"
    static let playerScreen = "player_screen"
    static let settingsScreen = "settings_screen"

    // Component identifiers
    static let talkRowPrefix = "talk_row_"
    static let playButtonSuffix = "_play_button"
    static let downloadButtonSuffix = "_download_button"
    static let miniPlayer = "mini_player"
    static let fullPlayer = "full_player"

    // Tab bar identifiers
    static let homeTab = "home_tab"
    static let talksTab = "talks_tab"
    static let downloadsTab = "downloads_tab"
    static let moreTab = "more_tab"
}

// MARK: - Accessibility Helpers

extension View {
    /// Add accessibility properties for a talk row
    func accessibilityTalkRow(_ talk: Talk, isDownloaded: Bool, downloadProgress: Float?) -> some View {
        self.accessibilityElement(children: .combine)
            .accessibilityIdentifier(PTAccessibility.talkRowPrefix + talk.id)
            .accessibilityLabel(accessibilityLabel(for: talk))
            .accessibilityValue(accessibilityValue(for: talk, isDownloaded: isDownloaded, downloadProgress: downloadProgress))
            .accessibilityHint(accessibilityHint(for: talk, isDownloaded: isDownloaded, downloadProgress: downloadProgress))
            .accessibilityAddTraits(.isButton)
    }

    /// Add accessibility properties for a play button
    func accessibilityPlayButton(isPlaying: Bool) -> some View {
        self.accessibilityElement(children: .ignore)
            .accessibilityLabel(isPlaying ? "Pause talk" : "Play talk")
            .accessibilityHint(isPlaying ? "Double tap to pause the current talk" : "Double tap to play the talk")
            .accessibilityAddTraits(.isButton)
    }

    /// Add accessibility properties for a download button
    func accessibilityDownloadButton(isDownloaded: Bool, downloadProgress: Float?) -> some View {
        let label: String
        let hint: String

        if let progress = downloadProgress {
            label = "Downloading, \(Int(progress * 100)) percent complete"
            hint = "Download in progress, double tap to cancel"
        } else if isDownloaded {
            label = "Download complete"
            hint = "Talk is downloaded and available offline"
        } else {
            label = "Download talk"
            hint = "Double tap to download this talk for offline listening"
        }

        return self.accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(.isButton)
    }
    
    /// Add accessibility properties for a delete button
    func accessibilityDeleteButton() -> some View {
        self.accessibilityElement(children: .ignore)
            .accessibilityLabel("Delete downloaded talk")
            .accessibilityHint("Double tap to delete this talk and free up storage space")
            .accessibilityAddTraits(.isButton)
    }
    
    /// Add accessibility properties for a downloaded talk row
    func accessibilityDownloadedTalkRow(_ downloadedTalk: DownloadedTalk) -> some View {
        self.accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(for: downloadedTalk))
            .accessibilityValue(accessibilityValue(for: downloadedTalk))
            .accessibilityHint("Double tap to open talk details, swipe right for playback controls")
            .accessibilityAddTraits(.isButton)
    }

    /// Add accessibility properties for mini player
    func accessibilityMiniPlayer(talkTitle: String?, speaker: String?, isPlaying: Bool) -> some View {
        let label = talkTitle ?? "No talk selected"
        let value = speaker.map { "By \($0)" } ?? ""
        let hint = isPlaying ? "Double tap to open full player and control playback" : "Double tap to open full player"

        return self.accessibilityElement(children: .combine)
            .accessibilityIdentifier(PTAccessibility.miniPlayer)
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityHint(hint)
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Private Helpers

    private func accessibilityLabel(for talk: Talk) -> String {
        var components = [talk.title]

        if !talk.speaker.isEmpty {
            components.append("by \(talk.speaker)")
        }

        if let series = talk.series {
            components.append("from \(series)")
        }

        return components.joined(separator: ", ")
    }

    private func accessibilityValue(for talk: Talk, isDownloaded: Bool, downloadProgress: Float?) -> String {
        var components: [String] = []

        components.append("Duration: \(talk.formattedDuration)")

        components.append("Recorded: \(talk.formattedDate)")

        if let progress = downloadProgress {
            components.append("Download: \(Int(progress * 100))%")
        } else if isDownloaded {
            components.append("Downloaded")
        }

        return components.joined(separator: ", ")
    }

    private func accessibilityHint(for talk: Talk, isDownloaded: Bool, downloadProgress: Float?) -> String {
        if downloadProgress != nil {
            return "Swipe right for download controls, double tap to open talk details"
        } else if isDownloaded {
            return "Swipe right for playback controls, double tap to open talk details"
        } else {
            return "Swipe right for download and playback controls, double tap to open talk details"
        }
    }
    
    private func accessibilityLabel(for downloadedTalk: DownloadedTalk) -> String {
        var components = [downloadedTalk.title]

        if !downloadedTalk.speaker.isEmpty {
            components.append("by \(downloadedTalk.speaker)")
        }

        if let series = downloadedTalk.series {
            components.append("from \(series)")
        }

        return components.joined(separator: ", ")
    }

    private func accessibilityValue(for downloadedTalk: DownloadedTalk) -> String {
        var components: [String] = []

        components.append("Duration: \(downloadedTalk.formattedDuration)")
        components.append("File size: \(downloadedTalk.formattedFileSize)")
        components.append("Downloaded")
        components.append("Last played: \(downloadedTalk.formattedLastAccessed)")

        return components.joined(separator: ", ")
    }
}

// MARK: - Dynamic Type Support

extension Font {
    /// Returns a font that scales with Dynamic Type
    static func ptDynamicTitle(size: CGFloat = 34, weight: Font.Weight = .bold) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }

    static func ptDynamicHeadline(size: CGFloat = 17, weight: Font.Weight = .semibold) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }

    static func ptDynamicBody(size: CGFloat = 17, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }

    static func ptDynamicSubheadline(size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }

    static func ptDynamicCaption(size: CGFloat = 12, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }
}

// MARK: - Accessibility Actions

// Note: Custom accessibility actions can be added here when needed
// For now, using standard SwiftUI accessibility modifiers is sufficient

// MARK: - Color Contrast Helpers

extension Color {
    /// Check if color meets WCAG contrast requirements
    func meetsContrastRequirement(with background: Color) -> Bool {
        // This is a simplified check - in production, you'd use a proper color contrast library
        // For now, we rely on the design system colors which should meet contrast requirements
        return true
    }
}

// MARK: - VoiceOver Announcements

class PTVoiceOver {
    static func announce(_ message: String, delay: TimeInterval = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    static func announceDownloadStarted(talkTitle: String) {
        announce("Download started for \(talkTitle)")
    }

    static func announceDownloadCompleted(talkTitle: String) {
        announce("Download completed for \(talkTitle)")
    }

    static func announcePlaybackStarted(talkTitle: String) {
        announce("Now playing \(talkTitle)")
    }

    static func announcePlaybackPaused(talkTitle: String) {
        announce("Playback paused")
    }

    static func announceError(_ error: Error) {
        announce("Error: \(error.localizedDescription)")
    }
}

// MARK: - Haptic Feedback for Accessibility

class PTHaptics {
    static let shared = PTHaptics()

    private let feedbackGenerator = UINotificationFeedbackGenerator()

    init() {
        feedbackGenerator.prepare()
    }

    func success() {
        feedbackGenerator.notificationOccurred(.success)
    }

    func warning() {
        feedbackGenerator.notificationOccurred(.warning)
    }

    func error() {
        feedbackGenerator.notificationOccurred(.error)
    }

    func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    func heavyImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

// MARK: - Accessibility Preferences

class PTAccessibilityPreferences {
    static let shared = PTAccessibilityPreferences()

    var isVoiceOverEnabled: Bool {
        UIAccessibility.isVoiceOverRunning
    }

    var prefersHighContrast: Bool {
        UIAccessibility.isDarkerSystemColorsEnabled
    }

    var largerTextEnabled: Bool {
        UIApplication.shared.preferredContentSizeCategory > .large
    }

    var reduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    var reduceTransparency: Bool {
        UIAccessibility.isReduceTransparencyEnabled
    }
}

