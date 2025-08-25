//
//  TalksListView.swift
//  PT Resources
//
//  Main talks list view with search and filtering
//

import SwiftUI

// MARK: - Navigation Item

struct ResourceNavigationItem: Identifiable {
    let id = UUID()
    let resourceId: String
}

struct TalksListView: View {
    
    @StateObject private var viewModel: TalksViewModel
    @StateObject private var playerService: PlayerService
    @StateObject private var downloadService: DownloadService
    
    @State private var showingFilters = false
    @State private var showingSortOptions = false
    @State private var selectedTalk: Talk?
    @State private var selectedResourceId: String?
    
    init(apiService: TalksAPIServiceProtocol = TalksAPIService()) {
        self._viewModel = StateObject(wrappedValue: TalksViewModel(apiService: apiService))
        self._playerService = StateObject(wrappedValue: PlayerService())
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
                    }
                    .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
                    .padding(.bottom, PTDesignTokens.Spacing.sm)
                
                    // Talks List with PT styling
                    if viewModel.isLoading && viewModel.talks.isEmpty {
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
                                        isDownloaded: downloadService.downloadProgress[talk.id] != nil || false, // TODO: Check actual download status
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
            FilterSheetView(
                filters: viewModel.selectedFilters,
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
}

// MARK: - Supporting Views

struct SearchBar: View {
    @Binding var text: String
    let onSearchButtonClicked: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search talks...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit {
                    onSearchButtonClicked()
                }
            
            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .foregroundColor(PTDesignTokens.Colors.kleinBlue)
            }
        }
        .padding()
    }
}

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
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Talks Found")
                .font(.title2)
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
