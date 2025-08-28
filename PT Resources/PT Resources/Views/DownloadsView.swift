//
//  DownloadsView.swift
//  PT Resources
//
//  Downloads management view with offline mode toggle
//

import SwiftUI
import Combine

struct DownloadsView: View {
    @StateObject private var downloadService: DownloadService
    @StateObject private var networkMonitor = NetworkMonitor()
    @ObservedObject private var playerService = PlayerService.shared
    
    @State private var downloadedTalks: [DownloadedTalk] = []
    @State private var isLoading = false
    @State private var showingStorageInfo = false
    @State private var totalStorageUsed: Int64 = 0
    
    init(apiService: TalksAPIServiceProtocol = TalksAPIService()) {
        self._downloadService = StateObject(wrappedValue: DownloadService(apiService: apiService))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                PTDesignTokens.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with offline mode toggle
                    headerSection
                    
                    // Content
                    if isLoading {
                        PTLoadingView()
                            .frame(maxHeight: .infinity)
                    } else if downloadedTalks.isEmpty {
                        emptyStateView
                    } else {
                        downloadsList
                    }
                    
                    // Mini Player
                    if playerService.currentTalk != nil {
                        MiniPlayerView(playerService: playerService)
                            .transition(.move(edge: .bottom))
                            .background(PTDesignTokens.Colors.surface)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -4)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            loadDownloadedTalks()
            calculateStorageUsage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadCompleted)) { _ in
            loadDownloadedTalks()
            calculateStorageUsage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadDeleted)) { _ in
            loadDownloadedTalks()
            calculateStorageUsage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadFailed)) { _ in
            // Optionally refresh to ensure consistency
            loadDownloadedTalks()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: PTDesignTokens.Spacing.md) {
            // Title and offline toggle
            HStack {
                VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
                    Text("Downloads")
                        .font(PTFont.ptSectionTitle)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                    
                    Text("\(downloadedTalks.count) talks downloaded")
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                }
                
                Spacer()
                
                // Offline mode toggle
                Button(action: { networkMonitor.toggleOfflineMode() }) {
                    HStack(spacing: PTDesignTokens.Spacing.xs) {
                        Image(systemName: networkMonitor.isOfflineMode ? "wifi.slash" : "wifi")
                            .font(.caption)
                        
                        Text(networkMonitor.isOfflineMode ? "Offline" : "Online")
                            .font(PTFont.ptCaptionText)
                    }
                    .foregroundColor(networkMonitor.isOfflineMode ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.medium)
                    .padding(.horizontal, PTDesignTokens.Spacing.sm)
                    .padding(.vertical, PTDesignTokens.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                            .fill(networkMonitor.isOfflineMode ? PTDesignTokens.Colors.tang.opacity(0.1) : PTDesignTokens.Colors.light.opacity(0.3))
                    )
                }
            }
            .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
            
            // Storage info
            Button(action: { showingStorageInfo = true }) {
                HStack {
                    Image(systemName: "internaldrive")
                        .font(.caption)
                    
                    Text("Storage: \(ByteCountFormatter.string(fromByteCount: totalStorageUsed, countStyle: .file))")
                        .font(PTFont.ptCaptionText)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundColor(PTDesignTokens.Colors.medium)
                .padding(.horizontal, PTDesignTokens.Spacing.md)
                .padding(.vertical, PTDesignTokens.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                        .fill(PTDesignTokens.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                                .stroke(PTDesignTokens.Colors.light.opacity(0.2), lineWidth: 0.5)
                        )
                )
            }
            .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
        }
        .padding(.top, PTDesignTokens.Spacing.md)
    }
    
    // MARK: - Downloads List
    
    private var downloadsList: some View {
        ScrollView {
            LazyVStack(spacing: PTDesignTokens.Spacing.md) {
                ForEach(downloadedTalks) { downloadedTalk in
                    DownloadedTalkRowView(
                        downloadedTalk: downloadedTalk,
                        onPlayTap: { playDownloadedTalk(downloadedTalk) },
                        onDeleteTap: { deleteDownloadedTalk(downloadedTalk) }
                    )
                    .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
                }
            }
            .padding(.top, PTDesignTokens.Spacing.sm)
            .padding(.bottom, PTDesignTokens.Spacing.xl)
        }
        .refreshable {
            loadDownloadedTalks()
            calculateStorageUsage()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: PTDesignTokens.Spacing.xl) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 80))
                .foregroundColor(PTDesignTokens.Colors.medium)
            
            VStack(spacing: PTDesignTokens.Spacing.md) {
                Text("No Downloads Yet")
                    .font(PTFont.ptSectionTitle)
                    .foregroundColor(PTDesignTokens.Colors.ink)
                
                Text("Download talks to listen offline when you don't have an internet connection")
                    .font(PTFont.ptBodyText)
                    .foregroundColor(PTDesignTokens.Colors.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, PTDesignTokens.Spacing.xl)
            }
            
            if !networkMonitor.isConnected {
                VStack(spacing: PTDesignTokens.Spacing.sm) {
                    Image(systemName: "wifi.slash")
                        .font(.title2)
                        .foregroundColor(PTDesignTokens.Colors.turmeric)
                    
                    Text("You're currently offline")
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.turmeric)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(PTDesignTokens.Spacing.xl)
    }
    
    // MARK: - Private Methods
    
    private func loadDownloadedTalks() {
        Task {
            isLoading = true
            do {
                let talks = try await downloadService.getDownloadedTalksWithMetadata()
                await MainActor.run {
                    self.downloadedTalks = talks
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                print("Failed to load downloaded talks: \(error)")
            }
        }
    }
    
    private func calculateStorageUsage() {
        Task {
            let storage = await downloadService.getTotalStorageUsed()
            await MainActor.run {
                self.totalStorageUsed = storage
            }
        }
    }
    
    private func playDownloadedTalk(_ downloadedTalk: DownloadedTalk) {
        // Create a Talk object from DownloadedTalk for playback
        let talk = Talk(
            id: downloadedTalk.id,
            title: downloadedTalk.title,
            description: nil,
            speaker: downloadedTalk.speaker,
            series: downloadedTalk.series,
            biblePassage: nil,
            dateRecorded: downloadedTalk.createdAt,
            duration: downloadedTalk.duration,
            audioURL: downloadedTalk.localAudioURL,
            imageURL: nil
        )
        
        playerService.loadTalk(talk)
        playerService.play()
    }
    
    private func deleteDownloadedTalk(_ downloadedTalk: DownloadedTalk) {
        Task {
            do {
                try await downloadService.deleteDownload(for: downloadedTalk.id)
                await MainActor.run {
                    downloadedTalks.removeAll { $0.id == downloadedTalk.id }
                    calculateStorageUsage()
                }
            } catch {
                print("Failed to delete downloaded talk: \(error)")
            }
        }
    }
}

// MARK: - Storage Info Sheet

struct StorageInfoSheet: View {
    let totalStorageUsed: Int64
    let downloadedTalks: [DownloadedTalk]
    let onCleanup: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: PTDesignTokens.Spacing.lg) {
                // Storage summary
                VStack(spacing: PTDesignTokens.Spacing.md) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 48))
                        .foregroundColor(PTDesignTokens.Colors.tang)
                    
                    Text(ByteCountFormatter.string(fromByteCount: totalStorageUsed, countStyle: .file))
                        .font(PTFont.ptSectionTitle)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                    
                    Text("Total Storage Used")
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                }
                
                // Statistics
                VStack(spacing: PTDesignTokens.Spacing.md) {
                    HStack {
                        Text("Downloaded Talks")
                            .font(PTFont.ptCardTitle)
                            .foregroundColor(PTDesignTokens.Colors.ink)
                        
                        Spacer()
                        
                        Text("\(downloadedTalks.count)")
                            .font(PTFont.ptCardTitle)
                            .foregroundColor(PTDesignTokens.Colors.tang)
                    }
                    
                    HStack {
                        Text("Average Size")
                            .font(PTFont.ptCardTitle)
                            .foregroundColor(PTDesignTokens.Colors.ink)
                        
                        Spacer()
                        
                        Text(downloadedTalks.isEmpty ? "0 MB" : ByteCountFormatter.string(fromByteCount: totalStorageUsed / Int64(downloadedTalks.count), countStyle: .file))
                            .font(PTFont.ptCardTitle)
                            .foregroundColor(PTDesignTokens.Colors.tang)
                    }
                }
                .padding(PTDesignTokens.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                        .fill(PTDesignTokens.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                                .stroke(PTDesignTokens.Colors.light.opacity(0.2), lineWidth: 0.5)
                        )
                )
                
                Spacer()
                
                // Cleanup button
                Button(action: onCleanup) {
                    Text("Clean Up Old Downloads")
                        .font(PTFont.ptButtonText)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PTDesignTokens.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                .fill(PTDesignTokens.Colors.tang)
                        )
                }
                .disabled(downloadedTalks.isEmpty)
            }
            .padding(PTDesignTokens.Spacing.lg)
            .navigationTitle("Storage Info")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

struct DownloadsView_Previews: PreviewProvider {
    static var previews: some View {
        DownloadsView()
    }
}
