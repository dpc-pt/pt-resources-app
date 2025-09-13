//
//  ConferencesListView.swift
//  PT Resources
//
//  Main conferences list view with beautiful card layout matching PT brand guidelines
//

import SwiftUI

struct ConferencesListView: View {
    @ObservedObject private var playerService = PlayerService.shared
    @StateObject private var viewModel: ConferencesViewModel
    @State private var showingFilters = false
    @State private var selectedConference: ConferenceInfo?
    
    init() {
        self._viewModel = StateObject(wrappedValue: ConferencesViewModel())
    }
    
    // Grid layout for conferences - adaptive grid that looks good on all screen sizes
    private let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 400), spacing: PTDesignTokens.Spacing.md)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                PTDesignTokens.Colors.background.ignoresSafeArea()
                    .ptCornerPattern(position: .topLeft, size: .medium, hasLogo: false)
                    .ptCornerPattern(position: .bottomRight, size: .large, hasLogo: false)
                
                VStack(spacing: 0) {
                    // Header
                    conferencesHeader
                    
                    // Search and Filter Controls
                    VStack(spacing: PTDesignTokens.Spacing.md) {
                        // Search Bar
                        PTSearchBar(text: $viewModel.searchText, onSearchButtonClicked: {
                            viewModel.searchConferences()
                        })
                        .accessibilityIdentifier("ConferencesSearchBar")
                        
                        // Filter Bar (if we have conferences)
                        if !viewModel.conferences.isEmpty || !viewModel.selectedFilters.isEmpty {
                            PTConferenceFilterBar(
                                showingFilters: $showingFilters,
                                activeFiltersCount: activeFiltersCount,
                                availableYears: viewModel.availableYears,
                                selectedYears: viewModel.selectedFilters.years,
                                onYearToggle: { year in
                                    if viewModel.selectedFilters.years.contains(year) {
                                        viewModel.removeYearFilter(year)
                                    } else {
                                        viewModel.filterByYear(year)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
                    .padding(.bottom, PTDesignTokens.Spacing.sm)
                    
                    // Main Content
                    if viewModel.isLoading && viewModel.conferences.isEmpty {
                        PTConferencesLoadingView()
                            .frame(maxHeight: .infinity)
                    } else if viewModel.filteredConferences.isEmpty {
                        PTConferencesEmptyStateView()
                            .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: PTDesignTokens.Spacing.lg) {
                                ForEach(viewModel.filteredConferences) { conference in
                                    PTConferenceListCard(conference: conference) {
                                        selectedConference = conference
                                    }
                                    .padding(.horizontal, PTDesignTokens.Spacing.xs)
                                    .accessibilityIdentifier("ConferenceCard_\(conference.id)")
                                }
                                
                                // Load More Indicator
                                if viewModel.hasMorePages && !viewModel.isLoading {
                                    Button(action: {
                                        viewModel.loadMoreConferences()
                                    }) {
                                        HStack(spacing: PTDesignTokens.Spacing.sm) {
                                            if viewModel.isLoading {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                            } else {
                                                Image(systemName: "arrow.down.circle")
                                                    .font(PTFont.ptButtonText)
                                            }
                                            Text("Load More Conferences")
                                                .font(PTFont.ptButtonText)
                                        }
                                        .foregroundColor(PTDesignTokens.Colors.tang)
                                        .padding(PTDesignTokens.Spacing.md)
                                    }
                                    .disabled(viewModel.isLoading)
                                }
                            }
                            .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
                            .padding(.top, PTDesignTokens.Spacing.sm)
                            .padding(.bottom, PTDesignTokens.Spacing.xxl)
                        }
                        .refreshable {
                            viewModel.refreshConferences()
                        }
                    }
                }
                
                // Mini Player
                if playerService.currentTalk != nil {
                    VStack {
                        Spacer()
                        MiniPlayerView(playerService: playerService)
                            .transition(.move(edge: .bottom))
                            .background(PTDesignTokens.Colors.surface)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -4)
                    }
                }
            }
        }
        .sheet(item: $selectedConference) { conference in
            NavigationStack {
                ConferenceDetailView(conference: conference)
            }
        }
        .onAppear {
            viewModel.loadConferences()
        }
    }
    
    // MARK: - Header
    
    private var conferencesHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
                Text("Conferences")
                    .font(PTFont.ptDisplaySmall)
                    .foregroundColor(PTDesignTokens.Colors.ink)
                
                Text("Explore past events and their resources")
                    .font(PTFont.ptBodyText)
                    .foregroundColor(PTDesignTokens.Colors.medium)
            }
            
            Spacer()
            
            PTLogo(size: 32, showText: false)
        }
        .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
        .padding(.vertical, PTDesignTokens.Spacing.md)
    }
    
    // MARK: - Helper Properties
    
    private var activeFiltersCount: Int {
        var count = 0
        if !viewModel.selectedFilters.query.isEmpty { count += 1 }
        if !viewModel.selectedFilters.years.isEmpty { count += viewModel.selectedFilters.years.count }
        return count
    }
}

// MARK: - Conference Card

struct PTConferenceListCard: View {
    let conference: ConferenceInfo
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Conference Image
                Group {
                    if let artworkURL = conference.artworkURL, let url = URL(string: artworkURL) {
                        PTAsyncImage(
                            url: url,
                            targetSize: CGSize(width: 400, height: 240)
                        ) {
                            // Fallback to local PT Resources logo
                            Image("pt-resources")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                    } else {
                        // Use local PT Resources logo directly
                        Image("pt-resources")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                }
                .aspectRatio(5/3, contentMode: .fill)
                .clipped()
                
                // Conference Info
                VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
                            Text(conference.displayTitle)
                                .font(PTFont.ptCardTitle)
                                .foregroundColor(PTDesignTokens.Colors.ink)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            
                            Text(conference.year)
                                .font(PTFont.ptCardSubtitle)
                                .foregroundColor(PTDesignTokens.Colors.tang)
                        }
                        
                        Spacer()
                        
                        // Resource count badge
                        HStack(spacing: PTDesignTokens.Spacing.xs) {
                            Image(systemName: "doc.text")
                                .font(.caption)
                            Text("\(conference.resourceCount)")
                                .font(PTFont.ptCaptionText)
                        }
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .padding(.horizontal, PTDesignTokens.Spacing.sm)
                        .padding(.vertical, PTDesignTokens.Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                                .fill(PTDesignTokens.Colors.veryLight)
                        )
                    }
                    
                    if let description = conference.description, !description.isEmpty {
                        Text(description)
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(PTDesignTokens.Spacing.cardPadding)
            }
        }
        .background(PTDesignTokens.Colors.surface)
        .cornerRadius(PTDesignTokens.BorderRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                .stroke(PTDesignTokens.Colors.border.opacity(0.5), lineWidth: 0.5)
        )
        .shadow(
            color: PTDesignTokens.Shadows.card.color,
            radius: PTDesignTokens.Shadows.card.radius,
            x: PTDesignTokens.Shadows.card.x,
            y: PTDesignTokens.Shadows.card.y
        )
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Conference Filter Bar

struct PTConferenceFilterBar: View {
    @Binding var showingFilters: Bool
    let activeFiltersCount: Int
    let availableYears: [String]
    let selectedYears: [String]
    let onYearToggle: (String) -> Void
    
    var body: some View {
        VStack(spacing: PTDesignTokens.Spacing.sm) {
            HStack(spacing: PTDesignTokens.Spacing.md) {
                // Filter Button
                Button(action: { showingFilters = true }) {
                    HStack(spacing: PTDesignTokens.Spacing.xs) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(PTFont.ptButtonText)
                        Text("Filter")
                            .font(PTFont.ptButtonText)
                        if activeFiltersCount > 0 {
                            Text("(\(activeFiltersCount))")
                                .font(PTFont.ptCaptionText)
                                .foregroundColor(PTDesignTokens.Colors.tang)
                        }
                    }
                    .foregroundColor(PTDesignTokens.Colors.ink)
                    .padding(.horizontal, PTDesignTokens.Spacing.md)
                    .padding(.vertical, PTDesignTokens.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                            .fill(activeFiltersCount > 0 ? PTDesignTokens.Colors.tang.opacity(0.1) : PTDesignTokens.Colors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                    .stroke(activeFiltersCount > 0 ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.medium.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                Spacer()
            }
            
            // Quick Year Filters
            if !availableYears.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PTDesignTokens.Spacing.sm) {
                        ForEach(availableYears, id: \.self) { year in
                            Button(action: { onYearToggle(year) }) {
                                Text(year)
                                    .font(PTFont.ptCaptionText)
                                    .foregroundColor(
                                        selectedYears.contains(year) ? .white : PTDesignTokens.Colors.medium
                                    )
                                    .padding(.horizontal, PTDesignTokens.Spacing.md)
                                    .padding(.vertical, PTDesignTokens.Spacing.xs)
                                    .background(
                                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                            .fill(
                                                selectedYears.contains(year) ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.veryLight
                                            )
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
                }
            }
        }
    }
}

// MARK: - Loading and Empty States

struct PTConferencesLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: PTDesignTokens.Spacing.lg) {
            PTLogo(size: 48, showText: false)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
                .onAppear {
                    isAnimating = true
                }
            
            Text("Loading conferences...")
                .font(PTFont.ptSectionTitle)
                .foregroundColor(PTDesignTokens.Colors.ink)
            
            Text("Discovering upcoming and past events")
                .font(PTFont.ptBodyText)
                .foregroundColor(PTDesignTokens.Colors.medium)
                .multilineTextAlignment(.center)
        }
        .padding(PTDesignTokens.Spacing.xl)
    }
}

struct PTConferencesEmptyStateView: View {
    var body: some View {
        VStack(spacing: PTDesignTokens.Spacing.lg) {
            PTLogo(size: 64, showText: false)
            
            Text("No Conferences Found")
                .font(PTFont.ptSectionTitle)
                .foregroundColor(PTDesignTokens.Colors.ink)
            
            Text("Try adjusting your search or filter criteria to discover more conferences")
                .font(PTFont.ptBodyText)
                .foregroundColor(PTDesignTokens.Colors.medium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PTDesignTokens.Spacing.lg)
        }
        .padding(PTDesignTokens.Spacing.xl)
    }
}

// MARK: - Previews

#Preview {
    ConferencesListView()
}
