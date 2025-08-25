//
//  PrivacySettingsView.swift
//  PT Resources
//
//  Privacy and data management settings
//

import SwiftUI

struct PrivacySettingsView: View {
    @StateObject private var privacyService = PrivacyService.shared
    @State private var dataUsageStats: DataUsageStatistics?
    @State private var isLoading = false
    @State private var showingExportOptions = false
    @State private var showingDeleteOptions = false
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    @State private var exportResult: ExportResult?

    var body: some View {
        NavigationStack {
            Form {
                // Data Usage Section
                Section("Data Usage") {
                    if let stats = dataUsageStats {
                        DataUsageRow(title: "Total Talks", value: "\(stats.totalTalks)")
                        DataUsageRow(title: "Downloaded Talks", value: "\(stats.downloadedTalks)")
                        DataUsageRow(title: "Bookmarks", value: "\(stats.bookmarks)")
                        DataUsageRow(title: "Storage Used", value: stats.totalDownloadedSizeFormatted)
                    } else {
                        ProgressView()
                            .onAppear {
                                loadDataUsageStats()
                            }
                    }
                }

                // Data Export Section
                Section("Export Your Data") {
                    Button(action: { showingExportOptions = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.ptPrimary)
                            Text("Export Data")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.ptMediumGray)
                        }
                    }
                    .accessibilityHint("Export your data for backup or transfer")

                    if let result = exportResult {
                        ExportResultRow(result: result)
                    }
                }

                // Data Management Section
                Section("Manage Your Data") {
                    Button(action: { showingDeleteOptions = true }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.ptSecondary)
                            Text("Delete Data")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.ptMediumGray)
                        }
                    }
                    .accessibilityHint("Delete specific types of data or all data")

                    Button(action: {
                        Task {
                            await clearCache()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.ptTurquoise)
                            Text("Clear Cache")
                            Spacer()
                            if isLoading {
                                ProgressView()
                            }
                        }
                    }
                    .accessibilityHint("Clear image cache and temporary files")
                    .disabled(isLoading)
                }

                // Privacy Documents Section
                Section("Legal") {
                    Button(action: { showingPrivacyPolicy = true }) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.ptPrimary)
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.ptMediumGray)
                        }
                    }
                    .accessibilityHint("Read our privacy policy")

                    Button(action: { showingTermsOfService = true }) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundColor(.ptPrimary)
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.ptMediumGray)
                        }
                    }
                    .accessibilityHint("Read our terms of service")
                }

                // Analytics Section
                Section {
                    Toggle("Analytics", isOn: Binding(
                        get: { Config.analyticsEnabled },
                        set: { Config.analyticsEnabled = $0 }
                    ))
                        .accessibilityHint("Allow anonymous usage statistics to help improve the app")
                } header: {
                    Text("Analytics")
                } footer: {
                    Text("Help us improve the app by sharing anonymous usage statistics.")
                }
            }
            .navigationTitle("Privacy & Data")
            .navigationBarTitleDisplayMode(.large)
            .overlay {
                if isLoading {
                    ProgressView("Processing...")
                        .padding()
                        .background(Color.ptSurface.opacity(0.9))
                        .cornerRadius(PTCornerRadius.medium)
                }
            }
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(onExportComplete: { result in
                self.exportResult = result
                self.showingExportOptions = false
            })
        }
        .sheet(isPresented: $showingDeleteOptions) {
            DeleteOptionsView(onDeleteComplete: {
                self.showingDeleteOptions = false
                self.loadDataUsageStats()
            })
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyDocumentView(document: .privacyPolicy)
        }
        .sheet(isPresented: $showingTermsOfService) {
            PrivacyDocumentView(document: .termsOfService)
        }
    }

    private func loadDataUsageStats() {
        Task {
            dataUsageStats = await privacyService.getDataUsageStatistics()
        }
    }

    private func clearCache() async {
        isLoading = true
        defer { isLoading = false }

        do {
            await ImageCacheService.shared.clearCache()
            PTVoiceOver.announce("Cache cleared successfully")

            // Reload data usage stats
            loadDataUsageStats()
        } catch {
            PTLogger.general.error("Failed to clear cache: \(error.localizedDescription)")
            PTVoiceOver.announceError(error)
        }
    }
}

// MARK: - Supporting Views

struct DataUsageRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.ptPrimary)
            Spacer()
            Text(value)
                .foregroundColor(.ptDarkGray)
                .fontWeight(.medium)
        }
    }
}

struct ExportResultRow: View {
    let result: ExportResult

    var body: some View {
        HStack {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .ptSuccess : .ptSecondary)

            VStack(alignment: .leading) {
                Text(result.success ? "Export Complete" : "Export Failed")
                    .font(.headline)
                if let fileURL = result.fileURL {
                    Text(fileURL.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.ptMediumGray)
                }
                if let error = result.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.ptSecondary)
                }
            }
        }
    }
}

struct ExportOptionsView: View {
    let onExportComplete: (ExportResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    @State private var exportType: ExportType = .full

    enum ExportType {
        case full
        case talks
        case history
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Export Type") {
                    Picker("What to export", selection: $exportType) {
                        Text("All Data").tag(ExportType.full)
                        Text("Downloaded Talks").tag(ExportType.talks)
                        Text("Listening History").tag(ExportType.history)
                    }
                    .pickerStyle(.inline)
                }

                Section {
                    Button("Export") {
                        Task {
                            await performExport()
                        }
                    }
                    .disabled(isExporting)
                }

                Section {
                    Text("Your data will be exported as a JSON file that you can save to your device or share with other apps.")
                        .font(.caption)
                        .foregroundColor(.ptDarkGray)
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isExporting {
                    ProgressView("Exporting...")
                        .padding()
                        .background(Color.ptSurface.opacity(0.9))
                        .cornerRadius(PTCornerRadius.medium)
                }
            }
        }
    }

    private func performExport() async {
        isExporting = true
        defer { isExporting = false }

        do {
            let fileURL: URL

            switch exportType {
            case .full:
                fileURL = try await PrivacyService.shared.exportUserData()
            case .talks:
                fileURL = try await PrivacyService.shared.exportDownloadedTalks()
            case .history:
                fileURL = try await PrivacyService.shared.exportListeningHistory()
            }

            let result = ExportResult(success: true, fileURL: fileURL, error: nil)
            onExportComplete(result)

            PTVoiceOver.announce("Data export completed successfully")

        } catch {
            let result = ExportResult(success: false, fileURL: nil, error: error.localizedDescription)
            onExportComplete(result)

            PTLogger.general.error("Data export failed: \(error.localizedDescription)")
            PTVoiceOver.announceError(error)
        }
    }
}

struct DeleteOptionsView: View {
    let onDeleteComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isDeleting = false
    @State private var deleteType: DeleteType = .downloaded
    @State private var showingConfirmation = false

    enum DeleteType {
        case downloaded
        case history
        case all
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Delete Data") {
                    Picker("What to delete", selection: $deleteType) {
                        Text("Downloaded Content").tag(DeleteType.downloaded)
                        Text("Listening History").tag(DeleteType.history)
                        Text("All Data").tag(DeleteType.all)
                    }
                    .pickerStyle(.inline)
                }

                Section {
                    Button("Delete") {
                        showingConfirmation = true
                    }
                    .foregroundColor(.ptSecondary)
                    .disabled(isDeleting)
                }

                Section {
                    Text(deleteWarningText)
                        .font(.caption)
                        .foregroundColor(.ptSecondary)
                }
            }
            .navigationTitle("Delete Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isDeleting {
                    ProgressView("Deleting...")
                        .padding()
                        .background(Color.ptSurface.opacity(0.9))
                        .cornerRadius(PTCornerRadius.medium)
                }
            }
            .confirmationDialog(
                "Delete Data",
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task {
                        await performDelete()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(deleteConfirmationText)
            }
        }
    }

    private var deleteWarningText: String {
        switch deleteType {
        case .downloaded:
            return "This will delete all downloaded talks from your device. You can re-download them later."
        case .history:
            return "This will clear your listening history, bookmarks, and playback positions."
        case .all:
            return "This will permanently delete all your data including downloads, history, and preferences. This action cannot be undone."
        }
    }

    private var deleteConfirmationText: String {
        switch deleteType {
        case .downloaded:
            return "Are you sure you want to delete all downloaded content?"
        case .history:
            return "Are you sure you want to clear your listening history?"
        case .all:
            return "Are you sure you want to delete all data? This action cannot be undone."
        }
    }

    private func performDelete() async {
        isDeleting = true
        defer { isDeleting = false }

        do {
            switch deleteType {
            case .downloaded:
                try await PrivacyService.shared.deleteDownloadedContent()
                PTVoiceOver.announce("Downloaded content deleted successfully")
            case .history:
                try await PrivacyService.shared.deleteListeningHistory()
                PTVoiceOver.announce("Listening history deleted successfully")
            case .all:
                try await PrivacyService.shared.deleteAllUserData()
                PTVoiceOver.announce("All data deleted successfully")
            }

            onDeleteComplete()

        } catch {
            PTLogger.general.error("Data deletion failed: \(error.localizedDescription)")
            PTVoiceOver.announceError(error)
        }
    }
}

struct PrivacyDocumentView: View {
    let document: PrivacyDocument

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PTSpacing.lg) {
                    Text(document.title)
                        .font(PTFont.ptSectionTitle)
                        .foregroundColor(.ptPrimary)

                    Text("Last updated: \(document.lastUpdated.formatted(date: .long, time: .omitted))")
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(.ptDarkGray)

                    Text(document.content)
                        .font(PTFont.ptBodyTextDynamic)
                        .foregroundColor(.ptPrimary)
                        .lineSpacing(4)

                    if let url = document.url {
                        Link("Read Full Document", destination: url)
                            .ptPrimaryButton()
                            .padding(.top, PTSpacing.md)
                    }
                }
                .padding(PTSpacing.lg)
            }
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct ExportResult {
    let success: Bool
    let fileURL: URL?
    let error: String?
}

// MARK: - Preview

struct PrivacySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacySettingsView()
    }
}

