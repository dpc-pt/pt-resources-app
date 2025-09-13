//
//  DownloadsView.swift
//  PT Resources
//
//  Downloads management view with offline mode toggle
//

import SwiftUI
import Combine

struct DownloadsView: View {
    @EnvironmentObject private var downloadService: DownloadService
    @StateObject private var networkMonitor = NetworkMonitor()
    @ObservedObject private var playerService = PlayerService.shared
    
    @State private var downloadedTalks: [DownloadedTalk] = []
    @State private var isLoading = false
    @State private var sortOption: SortOption = .dateDownloaded
    @State private var showingSortOptions = false
    @State private var lastRefreshTime = Date()
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var selectedDownloadedTalk: DownloadedTalk? = nil
    @State private var isInitialLoad = true
    
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
            // Show cached data immediately if available
            if downloadService.isCacheValid && !downloadService.cachedDownloadedTalks.isEmpty {
                downloadedTalks = downloadService.cachedDownloadedTalks
                isInitialLoad = false
            }
            
            Task {
                await loadDownloadedTalks()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadCompleted)) { _ in
            Task {
                await refreshDownloads()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadDeleted)) { _ in
            Task {
                await refreshDownloads()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadFailed)) { _ in
            Task {
                await loadDownloadedTalks()
            }
        }
        .onReceive(downloadService.$cachedDownloadedTalks) { cachedTalks in
            // Update UI when cache is updated in background
            if !cachedTalks.isEmpty && !isInitialLoad {
                downloadedTalks = cachedTalks
            }
        }
        .confirmationDialog("Sort Downloads", isPresented: $showingSortOptions) {
            ForEach(SortOption.allCases, id: \.self) { option in
                Button(option.displayName) {
                    sortOption = option
                }
            }
        } message: {
            Text("Choose how to sort your downloaded talks")
        }

        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(item: $selectedDownloadedTalk) { downloadedTalk in
            let talk = Talk(
                id: downloadedTalk.id,
                title: downloadedTalk.title,
                description: nil,
                speaker: downloadedTalk.speaker,
                series: downloadedTalk.series,
                biblePassage: nil,
                dateRecorded: downloadedTalk.createdAt,
                duration: downloadedTalk.duration,
                audioURL: nil, // Let PlayerService find the local file using talk ID
                imageURL: downloadedTalk.artworkURL
            )

            TalkDetailView(talk: talk)
        }
    }
    
    // MARK: - Header Section
    
        private var headerSection: some View {
        VStack(spacing: PTDesignTokens.Spacing.md) {
            // Header with title, subtitle, and logo
            HStack {
                VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
                    Text("Downloads")
                        .font(PTFont.ptDisplaySmall)
                        .foregroundColor(PTDesignTokens.Colors.ink)

                    Text("Listen offline to your saved talks")
                        .font(PTFont.ptBodyText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                }

                Spacer()

                PTLogo(size: 32, showText: false)
            }
            .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
            .padding(.vertical, PTDesignTokens.Spacing.md)

            // Sort Options (only show if we have downloads)
            if !downloadedTalks.isEmpty {
                HStack {
                    Button(action: { showingSortOptions = true }) {
                        HStack(spacing: PTDesignTokens.Spacing.xs) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.caption)

                            Text(sortOption.displayName)
                                .font(PTFont.ptCaptionText)
                        }
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .padding(.horizontal, PTDesignTokens.Spacing.sm)
                        .padding(.vertical, PTDesignTokens.Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                                .fill(PTDesignTokens.Colors.light.opacity(0.3))
                        )
                    }
                    .accessibilityLabel("Sort downloads by \(sortOption.displayName)")
                    .accessibilityHint("Double tap to change how downloads are sorted")

                    Spacer()
                }
                .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
            }
        }
    }
    
    // MARK: - Downloads List
    
    private var downloadsList: some View {
        List {
            ForEach(sortedDownloadedTalks) { downloadedTalk in
                DownloadedTalkRowView(
                    downloadedTalk: downloadedTalk,
                    onPlayTap: { playDownloadedTalk(downloadedTalk) },
                    onDeleteTap: { deleteDownloadedTalk(downloadedTalk) },
                    onTap: { showTalkDetail(downloadedTalk) }
                )
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Delete") {
                        deleteDownloadedTalk(downloadedTalk)
                    }
                    .tint(.red)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(PTDesignTokens.Colors.background)
        .refreshable {
            await refreshDownloads()
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
            

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(PTDesignTokens.Spacing.xl)
    }
    
    // MARK: - Private Methods
    
    
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
            audioURL: nil, // Let PlayerService find the local file using talk ID
            imageURL: downloadedTalk.artworkURL
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
                }
            } catch {
                PTLogger.general.error("Failed to delete downloaded talk: \(error.localizedDescription)")
                await MainActor.run {
                    self.errorMessage = "Unable to delete talk. Please try again."
                    self.showingError = true
                }
            }
        }
    }

    private func showTalkDetail(_ downloadedTalk: DownloadedTalk) {
        selectedDownloadedTalk = downloadedTalk
    }
    
    // MARK: - Computed Properties
    
    private var sortedDownloadedTalks: [DownloadedTalk] {
        switch sortOption {
        case .title:
            return downloadedTalks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .speaker:
            return downloadedTalks.sorted { $0.speaker.localizedCaseInsensitiveCompare($1.speaker) == .orderedAscending }
        case .dateDownloaded:
            return downloadedTalks.sorted { $0.createdAt > $1.createdAt }
        case .lastPlayed:
            return downloadedTalks.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
        case .fileSize:
            return downloadedTalks.sorted { $0.fileSize > $1.fileSize }
        case .duration:
            return downloadedTalks.sorted { $0.duration > $1.duration }
        }
    }
    
    // MARK: - Enhanced Methods
    
    private func refreshDownloads() async {
        await loadDownloadedTalks()
        lastRefreshTime = Date()
    }
    
    private func loadDownloadedTalks() async {
        // Only show loading if this is the initial load and we don't have cached data
        if isInitialLoad && downloadedTalks.isEmpty {
            isLoading = true
        }
        
        do {
            let talks = try await downloadService.getDownloadedTalksWithMetadata()
            await MainActor.run {
                self.downloadedTalks = talks
                self.isLoading = false
                self.isInitialLoad = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.isInitialLoad = false
                self.errorMessage = "Unable to load downloaded talks. Please try again."
                self.showingError = true
            }
            PTLogger.general.error("Failed to load downloaded talks: \(error.localizedDescription)")
        }
    }
    

    

    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Sort Options

enum SortOption: String, CaseIterable {
    case dateDownloaded = "dateDownloaded"
    case title = "title"
    case speaker = "speaker"
    case lastPlayed = "lastPlayed"
    case fileSize = "fileSize"
    case duration = "duration"
    
    var displayName: String {
        switch self {
        case .dateDownloaded: return "Date Downloaded"
        case .title: return "Title"
        case .speaker: return "Speaker"
        case .lastPlayed: return "Last Played"
        case .fileSize: return "File Size"
        case .duration: return "Duration"
        }
    }
}



// MARK: - Preview

struct DownloadsView_Previews: PreviewProvider {
    static var previews: some View {
        DownloadsView()
    }
}
