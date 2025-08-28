//
//  TalksListView.swift
//  PT Resources
//
//  Main talks list view with search and filtering
//

import SwiftUI
import Combine

// MARK: - Navigation Item

struct ResourceNavigationItem: Identifiable {
    let id = UUID()
    let resourceId: String
}

struct TalksListView: View {
    
    @StateObject private var viewModel: TalksViewModel
    @ObservedObject private var playerService = PlayerService.shared
    @StateObject private var downloadService: DownloadService
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var filtersAPIService: FiltersAPIService
    
    @State private var showingFilters = false
    @State private var showingSortOptions = false
    @State private var selectedTalk: Talk?
    @State private var selectedResourceId: String?
    @State private var downloadedTalks: [DownloadedTalk] = []
    @State private var isLoadingDownloadedTalks = false
    
    init(apiService: TalksAPIServiceProtocol = TalksAPIService(), filtersAPIService: FiltersAPIService = FiltersAPIService(), initialFilters: TalkSearchFilters? = nil) {
        self._filtersAPIService = StateObject(wrappedValue: filtersAPIService)
        self._viewModel = StateObject(wrappedValue: TalksViewModel(apiService: apiService, filtersAPIService: filtersAPIService, initialFilters: initialFilters))
        self._downloadService = StateObject(wrappedValue: DownloadService(apiService: apiService))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                PTDesignTokens.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Authentic PT Brand Header
                    PTBrandHeader("Resources", subtitle: "Sermons and talks from Proclamation Trust")
                    
                    VStack(spacing: PTDesignTokens.Spacing.md) {
                        // Search Bar with PT styling
                        PTSearchBar(text: $viewModel.searchText, onSearchButtonClicked: {
                            viewModel.searchTalks()
                        })
                        
                        // Filter and Sort Bar with PT styling
                        PTFilterSortBar(
                            showingFilters: $showingFilters,
                            showingSortOptions: $showingSortOptions,
                            activeFiltersCount: activeFiltersCount,
                            currentSortOption: viewModel.sortOption
                        )
                        
                        // Quick Filters
                        if !viewModel.isLoading || !viewModel.talks.isEmpty {
                            QuickFiltersView(
                                quickFilters: filtersAPIService.getQuickFilters(),
                                onFilterTap: { quickFilter in
                                    viewModel.applyQuickFilter(quickFilter)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
                    .padding(.bottom, PTDesignTokens.Spacing.sm)
                
                    // Talks List with PT styling
                    if networkMonitor.shouldShowOfflineContent {
                        // Show downloaded talks in offline mode
                        offlineTalksList
                    } else if viewModel.isLoading && viewModel.talks.isEmpty {
                        PTLoadingView()
                            .frame(maxHeight: .infinity)
                    } else if viewModel.talks.isEmpty {
                        PTEmptyStateView()
                            .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: PTDesignTokens.Spacing.md) {
                                ForEach(viewModel.filteredTalks) { talk in
                                    TalkRowView(
                                        talk: talk,
                                        isDownloaded: isTalkDownloaded(talk.id),
                                        downloadProgress: downloadService.downloadProgress[talk.id],
                                        onTalkTap: { selectedTalk = talk },
                                        onPlayTap: { playTalk(talk) },
                                        onDownloadTap: { downloadTalk(talk) }
                                    )
                                    .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
                                    
                                    // Load more when near the end
                                    if talk == viewModel.filteredTalks.last && viewModel.hasMorePages {
                                        HStack {
                                            PTLogo(size: 16, showText: false)
                                                .rotationEffect(.degrees(360))
                                                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: true)
                                            Text("Loading more...")
                                                .font(PTFont.ptCaptionText)
                                                .foregroundColor(PTDesignTokens.Colors.medium)
                                        }
                                        .padding()
                                        .onAppear {
                                            viewModel.loadMoreTalks()
                                        }
                                    }
                                }
                            }
                            .padding(.top, PTDesignTokens.Spacing.sm)
                            .padding(.bottom, PTDesignTokens.Spacing.xl)
                        }
                        .refreshable {
                            viewModel.refreshTalks()
                        }
                    }
                
                    // Mini Player with PT styling
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
        .sheet(isPresented: $showingFilters) {
            EnhancedFilterView(
                filters: viewModel.selectedFilters,
                filtersAPIService: filtersAPIService,
                onFiltersChanged: { newFilters in
                    viewModel.applyFilters(newFilters)
                }
            )
        }
        .sheet(isPresented: $showingSortOptions) {
            SortOptionsSheetView(
                selectedOption: viewModel.sortOption,
                onOptionSelected: { option in
                    viewModel.changeSortOption(option)
                }
            )
        }
        .sheet(item: $selectedTalk) { talk in
            TalkDetailView(talk: talk, playerService: playerService, downloadService: downloadService)
        }
        .sheet(item: Binding<ResourceNavigationItem?>(
            get: { selectedResourceId.map { ResourceNavigationItem(resourceId: $0) } },
            set: { _ in selectedResourceId = nil }
        )) { item in
            ResourceDetailView(resourceId: item.resourceId)
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
            Button("Retry") {
                viewModel.refreshTalks()
                viewModel.error = nil
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An error occurred")
        }
    }
    
    // MARK: - Computed Properties
    
    private var activeFiltersCount: Int {
        var count = 0
        if !viewModel.selectedFilters.query.isEmpty { count += 1 }
        if viewModel.selectedFilters.speaker != nil { count += 1 }
        if viewModel.selectedFilters.series != nil { count += 1 }
        if viewModel.selectedFilters.dateFrom != nil { count += 1 }
        if viewModel.selectedFilters.dateTo != nil { count += 1 }
        return count
    }
    
    // MARK: - Private Methods
    
    private func playTalk(_ talk: Talk) {
        playerService.loadTalk(talk)
        playerService.play()
    }
    
    private func downloadTalk(_ talk: Talk) {
        Task {
            do {
                try await downloadService.downloadTalk(talk)
            } catch {
                // Handle download error
                print("Download failed: \(error)")
            }
        }
    }
    
    private func isTalkDownloaded(_ talkID: String) -> Bool {
        return downloadedTalks.contains { $0.id == talkID }
    }
    
    private func loadDownloadedTalks() {
        Task {
            isLoadingDownloadedTalks = true
            do {
                let talks = try await downloadService.getDownloadedTalksWithMetadata()
                await MainActor.run {
                    self.downloadedTalks = talks
                    self.isLoadingDownloadedTalks = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingDownloadedTalks = false
                }
                print("Failed to load downloaded talks: \(error)")
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
                }
            } catch {
                print("Failed to delete downloaded talk: \(error)")
            }
        }
    }
}

// MARK: - Offline Talks List

private extension TalksListView {
    
    var offlineTalksList: some View {
        VStack(spacing: PTDesignTokens.Spacing.md) {
            // Offline mode header
            offlineModeHeader
            
            // Downloaded talks list
            if isLoadingDownloadedTalks {
                PTLoadingView()
                    .frame(maxHeight: .infinity)
            } else if downloadedTalks.isEmpty {
                offlineEmptyState
            } else {
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
                }
            }
        }
        .onAppear {
            loadDownloadedTalks()
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadCompleted)) { _ in
            loadDownloadedTalks()
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadDeleted)) { _ in
            loadDownloadedTalks()
        }
    }
    
    var offlineModeHeader: some View {
        HStack {
            Image(systemName: networkMonitor.isOfflineMode ? "wifi.slash" : "wifi")
                .foregroundColor(PTDesignTokens.Colors.tang)
            
            Text(networkMonitor.connectionStatusDescription)
                .font(PTFont.ptCardTitle)
                .foregroundColor(PTDesignTokens.Colors.ink)
            
            Spacer()
            
            if networkMonitor.isOfflineMode {
                Button("Exit Offline") {
                    networkMonitor.disableOfflineMode()
                }
                .font(PTFont.ptCaptionText)
                .foregroundColor(PTDesignTokens.Colors.kleinBlue)
            }
        }
        .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
        .padding(.vertical, PTDesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                .fill(PTDesignTokens.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                        .stroke(PTDesignTokens.Colors.light.opacity(0.2), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
    }
    
    var offlineEmptyState: some View {
        VStack(spacing: PTDesignTokens.Spacing.lg) {
            Image(systemName: "arrow.down.circle")
                .font(PTFont.ptDisplayLarge)
                .foregroundColor(PTDesignTokens.Colors.medium)
            
            Text("No Downloaded Talks")
                .font(PTFont.ptSectionTitle)
                .foregroundColor(PTDesignTokens.Colors.ink)
            
            Text("Download talks when you're online to listen offline")
                .font(PTFont.ptBodyText)
                .foregroundColor(PTDesignTokens.Colors.medium)
                .multilineTextAlignment(.center)
            
            if !networkMonitor.isConnected {
                Text("You're currently offline")
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(PTDesignTokens.Colors.turmeric)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(PTDesignTokens.Spacing.xl)
    }
}

// MARK: - Supporting Views

struct FilterSortBar: View {
    @Binding var showingFilters: Bool
    @Binding var showingSortOptions: Bool
    let activeFiltersCount: Int
    let currentSortOption: TalkSortOption
    
    var body: some View {
        HStack {
            Button(action: { showingFilters = true }) {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("Filter")
                    if activeFiltersCount > 0 {
                        Text("(\(activeFiltersCount))")
                            .foregroundColor(PTDesignTokens.Colors.kleinBlue)
                    }
                }
            }
            
            Spacer()
            
            Button(action: { showingSortOptions = true }) {
                HStack {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(currentSortOption.displayName)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .foregroundColor(.primary)
    }
}

struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading talks...")
                .padding(.top)
                .foregroundColor(.secondary)
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(PTFont.ptDisplayLarge)
                .foregroundColor(.secondary)
            
            Text("No Talks Found")
                .font(PTFont.ptSectionTitle)
                .fontWeight(.medium)
            
            Text("Try adjusting your search or filters")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Preview

struct TalksListView_Previews: PreviewProvider {
    static var previews: some View {
        TalksListView(apiService: MockTalksAPIService())
    }
}
