//
//  PTAccessibilityExtensions.swift
//  PT Resources
//
//  Comprehensive accessibility extensions for enhanced user experience
//

import SwiftUI
import AVFoundation

// MARK: - Accessibility Extensions for View

extension View {
    // MARK: - Enhanced Accessibility Labels

    func ptAccessibilityLabel(_ label: String) -> some View {
        self.accessibilityLabel(Text(label))
    }

    func ptAccessibilityHint(_ hint: String) -> some View {
        self.accessibilityHint(Text(hint))
    }

    func ptAccessibilityValue(_ value: String) -> some View {
        self.accessibilityValue(Text(value))
    }

    // MARK: - Interactive Element Accessibility

    func ptAccessibilityTapTarget(minimumSize: CGSize = CGSize(width: 44, height: 44)) -> some View {
        self.accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .frame(minWidth: max(minimumSize.width, 44), minHeight: max(minimumSize.height, 44))
    }

    func ptAccessibilityPlayButton(isPlaying: Bool) -> some View {
        self.accessibilityLabel(isPlaying ? "Pause" : "Play")
            .accessibilityHint(isPlaying ? "Pause audio playback" : "Start audio playback")
            .accessibilityAddTraits(.startsMediaSession)
    }

    func ptAccessibilityDownloadButton(isDownloaded: Bool, downloadProgress: Float?) -> some View {
        let label = isDownloaded ? "Downloaded" :
                   downloadProgress != nil ? "Downloading" : "Download"
        let hint = isDownloaded ? "Audio file is downloaded" :
                  downloadProgress != nil ? "Audio file is downloading" : "Download audio file"
        let traits: AccessibilityTraits = isDownloaded ? .isSelected : .isButton

        return self
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(traits)
            .accessibilityValue(downloadProgress != nil ? "\(Int(downloadProgress! * 100))% downloaded" : "")
    }

    // MARK: - List and Collection Accessibility

    func ptAccessibilityListItem<Content: View>(
        rowIndex: Int,
        totalCount: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        self.accessibilityElement(children: .ignore)
            .accessibilityLabel("Item \(rowIndex + 1) of \(totalCount)")
            .overlay(content())
    }

    // MARK: - Dynamic Type Support

    func ptDynamicTypeSize(_ size: DynamicTypeSize = .large) -> some View {
        self.dynamicTypeSize(size)
    }

    // MARK: - Reduced Motion Support

    func ptReducedMotion() -> some View {
        self.transaction { transaction in
            if UIAccessibility.isReduceMotionEnabled {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
    }

    // MARK: - High Contrast Support

    func ptHighContrast() -> some View {
        self.environment(\.colorScheme, .light) // Use light mode for high contrast
    }
}

// MARK: - Accessibility Extensions for Specific UI Components

extension View {
    func ptCardAccessibility(title: String, subtitle: String? = nil, isInteractive: Bool = true) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)
            .accessibilityHint(isInteractive ? "Double tap to open" : "Information card")
            .accessibilityValue(subtitle ?? "")
            .accessibilityAddTraits(isInteractive ? [.isButton, .isModal] : .isStaticText)
    }

    func ptSearchAccessibility(placeholder: String, isSearching: Bool) -> some View {
        self
            .accessibilityLabel("Search talks and resources")
            .accessibilityHint("Enter keywords to find content")
            .accessibilityValue(isSearching ? "Searching..." : placeholder)
            .accessibilityAddTraits(.isSearchField)
    }

    func ptFilterAccessibility(filterCount: Int) -> some View {
        self
            .accessibilityLabel("Filters")
            .accessibilityHint("Tap to modify search filters")
            .accessibilityValue(filterCount > 0 ? "\(filterCount) filters applied" : "No filters applied")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Accessibility Helpers

struct PTAccessibilityHelpers {

    // MARK: - Audio Playback Accessibility

    static func announceAudioState(isPlaying: Bool, talkTitle: String) {
        let announcement = isPlaying ?
            "Playing \(talkTitle)" :
            "Paused \(talkTitle)"
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }

    static func announceDownloadProgress(progress: Float, talkTitle: String) {
        let percentage = Int(progress * 100)
        let announcement = "Download progress for \(talkTitle): \(percentage) percent"
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }

    static func announceDownloadComplete(talkTitle: String) {
        let announcement = "\(talkTitle) download complete"
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }

    // MARK: - Screen Reader Optimized Descriptions

    static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return "\(hours) hours, \(minutes) minutes"
        } else if minutes > 0 {
            return "\(minutes) minutes, \(seconds) seconds"
        } else {
            return "\(seconds) seconds"
        }
    }

    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - VoiceOver Gesture Support

    static func configureVoiceOverGestures() {
        // Enable magic tap for play/pause
        // Magic tap functionality is deprecated, removing this line

        // Configure custom actions
        let playPauseAction = UIAccessibilityCustomAction(name: "Play/Pause") { _ in
            // Handle play/pause gesture
            return true
        }

        UIAccessibility.post(notification: .layoutChanged, argument: nil)
    }
}

// MARK: - Accessibility Notification Names

extension Notification.Name {
    static let ptAccessibilityPreferencesChanged = Notification.Name("PTAccessibilityPreferencesChanged")
}

// MARK: - Accessibility Preferences Manager

@MainActor
final class PTAccessibilityManager: ObservableObject {
    static let shared = PTAccessibilityManager()

    @Published private(set) var preferences: AccessibilityPreferences

    private init() {
        self.preferences = AccessibilityPreferences()
        setupAccessibilityNotifications()
    }

    private func setupAccessibilityNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccessibilityPreferencesChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccessibilityPreferencesChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }

    @objc private func handleAccessibilityPreferencesChanged() {
        preferences.updateFromSystem()
        NotificationCenter.default.post(name: .ptAccessibilityPreferencesChanged, object: nil)
    }
}

struct AccessibilityPreferences {
    var reduceMotion: Bool = UIAccessibility.isReduceMotionEnabled
    var darkerSystemColors: Bool = false // This property was deprecated
    var prefersLargeText: Bool = false

    mutating func updateFromSystem() {
        reduceMotion = UIAccessibility.isReduceMotionEnabled
        darkerSystemColors = false // This property was deprecated
        prefersLargeText = false // This property was deprecated
    }
}

// MARK: - Focus Management

extension View {
    func ptFocusOnAppear(_ shouldFocus: Bool = true) -> some View {
        self.onAppear {
            if shouldFocus && UIAccessibility.isVoiceOverRunning {
                UIAccessibility.post(notification: .screenChanged, argument: nil)
            }
        }
    }

    func ptFocusOnChange<T: Equatable>(of value: T, _ shouldFocus: Bool = true) -> some View {
        self.onChange(of: value) { _ in
            if shouldFocus && UIAccessibility.isVoiceOverRunning {
                UIAccessibility.post(notification: .layoutChanged, argument: nil)
            }
        }
    }
}