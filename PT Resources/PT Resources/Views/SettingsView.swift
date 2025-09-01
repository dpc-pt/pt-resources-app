//
//  SettingsView.swift
//  PT Resources
//
//  Comprehensive settings with PT branding and full functionality
//

import SwiftUI

struct SettingsView: View {
    // MARK: - State Management

    @AppStorage("playbackSpeed") private var playbackSpeed: Double = 1.0
    @AppStorage("skipInterval") private var skipInterval: Int = 30
    @AppStorage("autoPlay") private var autoPlay: Bool = false
    @AppStorage("autoDeleteDays") private var autoDeleteDays: Int = 90
    @AppStorage("maxStorageGB") private var maxStorageGB: Int = 5
    @AppStorage("downloadQuality") private var downloadQuality: String = "High"
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("newContentNotifications") private var newContentNotifications: Bool = true
    @AppStorage("downloadNotifications") private var downloadNotifications: Bool = true
    @AppStorage("appearance") private var appearance: String = "System"
    @AppStorage("fontSize") private var fontSize: String = "Medium"
    @AppStorage("showTranscriptByDefault") private var showTranscriptByDefault: Bool = false

    @State private var showingPrivacySettings = false
    @State private var showingStorageAlert = false

    // MARK: - Constants

    private let playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    private let skipIntervals = [10, 15, 30, 60]
    private let autoDeleteOptions = [30, 60, 90, 180, 365]
    private let storageOptions = [1, 2, 5, 10, 25, 50]
    private let downloadQualities = ["Low", "Medium", "High"]
    private let appearanceOptions = ["Light", "Dark", "System"]
    private let fontSizeOptions = ["Small", "Medium", "Large"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PTDesignTokens.Spacing.xl) {
                    // Header with PT Logo
                    VStack(spacing: PTDesignTokens.Spacing.md) {
                        PTLogo(size: 48, showText: false)
                        Text("Settings")
                            .font(PTFont.ptDisplaySmall)
                            .foregroundColor(PTDesignTokens.Colors.ink)
                    }
                    .padding(.vertical, PTDesignTokens.Spacing.lg)

                    // Settings Sections
                    VStack(spacing: PTDesignTokens.Spacing.lg) {
                        playbackSection
                        storageSection
                        notificationsSection
                        appearanceSection
                        aboutSection
                    }
                    .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
                }
            }
            .background(PTDesignTokens.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingPrivacySettings) {
                PrivacySettingsView()
            }
            .alert("Storage Limit Reached", isPresented: $showingStorageAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You've reached your storage limit. Consider increasing your limit or deleting old downloads.")
            }
        }
    }

    // MARK: - Playback Section

    private var playbackSection: some View {
        SettingsSection(title: "Playback", icon: "play.circle.fill") {
            VStack(spacing: PTDesignTokens.Spacing.md) {
                // Playback Speed
                SettingRow(
                    title: "Playback Speed",
                    subtitle: "\(String(format: "%.1f", playbackSpeed))x"
                ) {
                    Picker("", selection: $playbackSpeed) {
                        ForEach(playbackSpeeds, id: \.self) { speed in
                            Text("\(String(format: "%.1f", speed))x")
                                .tag(speed)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }

                Divider()

                // Skip Interval
                SettingRow(
                    title: "Skip Interval",
                    subtitle: "\(skipInterval) seconds"
                ) {
                    Picker("", selection: $skipInterval) {
                        ForEach(skipIntervals, id: \.self) { interval in
                            Text("\(interval)s")
                                .tag(interval)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }

                Divider()

                // Auto-play
                SettingRow(
                    title: "Auto-play Next",
                    subtitle: "Automatically play the next talk"
                ) {
                    Toggle("", isOn: $autoPlay)
                        .labelsHidden()
                }
            }
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        SettingsSection(title: "Storage", icon: "internaldrive.fill") {
            VStack(spacing: PTDesignTokens.Spacing.md) {
                // Storage Limit
                SettingRow(
                    title: "Storage Limit",
                    subtitle: "\(maxStorageGB) GB"
                ) {
                    Picker("", selection: $maxStorageGB) {
                        ForEach(storageOptions, id: \.self) { gb in
                            Text("\(gb) GB")
                                .tag(gb)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }

                Divider()

                // Auto-delete
                SettingRow(
                    title: "Auto-delete Downloads",
                    subtitle: "After \(autoDeleteDays) days"
                ) {
                    Picker("", selection: $autoDeleteDays) {
                        ForEach(autoDeleteOptions, id: \.self) { days in
                            Text("\(days) days")
                                .tag(days)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }

                Divider()

                // Download Quality
                SettingRow(
                    title: "Download Quality",
                    subtitle: downloadQuality
                ) {
                    Picker("", selection: $downloadQuality) {
                        ForEach(downloadQualities, id: \.self) { quality in
                            Text(quality)
                                .tag(quality)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
            }
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        SettingsSection(title: "Notifications", icon: "bell.fill") {
            VStack(spacing: PTDesignTokens.Spacing.md) {
                // Master Notifications Toggle
                SettingRow(
                    title: "Enable Notifications",
                    subtitle: "Receive notifications from the app"
                ) {
                    Toggle("", isOn: $notificationsEnabled)
                        .labelsHidden()
                }

                if notificationsEnabled {
                    Divider()

                    // New Content
                    SettingRow(
                        title: "New Content",
                        subtitle: "When new talks and resources are available"
                    ) {
                        Toggle("", isOn: $newContentNotifications)
                            .labelsHidden()
                    }

                    Divider()

                    // Downloads
                    SettingRow(
                        title: "Downloads",
                        subtitle: "When downloads are complete"
                    ) {
                        Toggle("", isOn: $downloadNotifications)
                            .labelsHidden()
                    }
                }
            }
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        SettingsSection(title: "Appearance", icon: "eye.fill") {
            VStack(spacing: PTDesignTokens.Spacing.md) {
                // Theme
                SettingRow(
                    title: "Theme",
                    subtitle: appearance
                ) {
                    Picker("", selection: $appearance) {
                        ForEach(appearanceOptions, id: \.self) { option in
                            Text(option)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }

                Divider()

                // Font Size
                SettingRow(
                    title: "Font Size",
                    subtitle: fontSize
                ) {
                    Picker("", selection: $fontSize) {
                        ForEach(fontSizeOptions, id: \.self) { size in
                            Text(size)
                                .tag(size)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }

                Divider()

                // Show Transcript
                SettingRow(
                    title: "Show Transcript by Default",
                    subtitle: "Display transcripts when available"
                ) {
                    Toggle("", isOn: $showTranscriptByDefault)
                        .labelsHidden()
                }
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(spacing: PTDesignTokens.Spacing.md) {
            // Privacy Settings
            Button(action: { showingPrivacySettings = true }) {
                HStack(spacing: PTDesignTokens.Spacing.md) {
                    Image(systemName: "hand.raised.fill")
                        .font(PTFont.ptSectionTitle)
                        .foregroundColor(PTDesignTokens.Colors.kleinBlue)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Privacy & Data")
                            .font(PTFont.ptBodyText)
                            .foregroundColor(PTDesignTokens.Colors.ink)

                        Text("Manage your privacy and data")
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.light)
                }
                .padding(PTDesignTokens.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                        .fill(PTDesignTokens.Colors.surface.opacity(0.5))
                )
            }
            .buttonStyle(.plain)

            // Version Info
            VStack(spacing: PTDesignTokens.Spacing.xs) {
                Text("PT Resources")
                    .font(PTFont.ptSectionTitle)
                    .foregroundColor(PTDesignTokens.Colors.ink)

                Text("Version 1.0.0")
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(PTDesignTokens.Colors.medium)

                Text("© 2024 Proclamation Trust")
                    .font(PTFont.ptSmallText)
                    .foregroundColor(PTDesignTokens.Colors.light)
            }
            .padding(PTDesignTokens.Spacing.md)
        }
    }
}

// MARK: - Supporting Components

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.md) {
            HStack(spacing: PTDesignTokens.Spacing.sm) {
                Image(systemName: icon)
                    .font(PTFont.ptSectionTitle)
                    .foregroundColor(PTDesignTokens.Colors.kleinBlue)

                Text(title)
                    .font(PTFont.ptSectionTitle)
                    .foregroundColor(PTDesignTokens.Colors.ink)
            }

            VStack(spacing: 0) {
                content
            }
            .padding(PTDesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                    .fill(PTDesignTokens.Colors.surface.opacity(0.5))
            )
        }
    }
}

struct SettingRow<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: PTDesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PTFont.ptBodyText)
                    .foregroundColor(PTDesignTokens.Colors.ink)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                }
            }

            Spacer()

            content
        }
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
