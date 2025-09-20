//
//  HomeView.swift
//  PT Resources
//
//  Beautiful homepage matching PT design guidelines
//

import SwiftUI

// MARK: - Navigation Items

struct ConferenceNavigationItem: Identifiable {
    let id = UUID()
    let conferenceId: String
}

struct BlogPostNavigationItem: Identifiable {
    let id = UUID()
    let blogPost: BlogPost
}

struct HomeView: View {
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @ObservedObject private var playerService = PlayerService.shared
    @State private var latestContent: LatestContentResponse?
    @State private var isLoading = false
    @State private var error: APIError?
    @State private var selectedConferenceId: String?
    @State private var selectedBlogPost: BlogPost?
    @State private var showingSettings = false
    @Binding var selectedTab: Int

    init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                PTDesignTokens.Colors.background.ignoresSafeArea()
                    .ptCornerPattern(position: .topRight, size: .large, hasLogo: false)
                    .ptCornerPattern(position: .bottomLeft, size: .medium, hasLogo: false)
                
                if isLoading && latestContent == nil {
                    PTWelcomeLoadingView(onSettingsTap: { showingSettings = true })
                } else if let latestContent = latestContent {
                    ScrollView {
                        LazyVStack(spacing: PTDesignTokens.Spacing.lg) {
                            // Welcome Header
                            PTWelcomeHeader(onSettingsTap: { showingSettings = true })

                            // Content Section
                            VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.md) {
                                Text("Latest Resources")
                                    .font(PTFont.ptSectionTitle)
                                    .foregroundColor(PTDesignTokens.Colors.ink)
                                    .padding([.horizontal], PTDesignTokens.Spacing.screenEdges)

                                // Blog Post Card (Main Featured)
                                if let blogPost = latestContent.blogPost {
                                    PTFeaturedBlogCard(blogPost: blogPost.toBlogPost(), onTap: {
                                        selectedBlogPost = blogPost.toBlogPost()
                                    })
                                    .padding([.horizontal], PTDesignTokens.Spacing.screenEdges)
                                    .ptSectionBackground(
                                        baseColor: PTDesignTokens.Colors.surface.opacity(0.3),
                                        hasLogo: false,
                                        patternOpacity: 0.03
                                    )
                                }

                                // Latest Conference
                                if let latestConference = latestContent.latestConference {
                                    PTConferenceCard(
                                        conference: latestConference.toConferenceInfo(),
                                        isLatest: true,
                                        onTap: { selectedConferenceId = latestConference.conferenceId }
                                    )
                                    .padding([.horizontal], PTDesignTokens.Spacing.screenEdges)
                                }

                                // Archive Media
                                if let archiveMedia = latestContent.archiveMedia {
                                    PTConferenceCard(
                                        conference: archiveMedia.toConferenceInfo(),
                                        isLatest: false,
                                        onTap: { selectedConferenceId = archiveMedia.conferenceId }
                                    )
                                    .padding([.horizontal], PTDesignTokens.Spacing.screenEdges)
                                }
                            }
                        }
                        .padding(.top, PTDesignTokens.Spacing.md)
                        .padding(.bottom, PTDesignTokens.Spacing.xxl)
                    }
                    .refreshable {
                        await loadLatestContent()
                    }
                } else {
                    PTEmptyStateView()
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
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadLatestContent()
        }
        .sheet(item: Binding<ConferenceNavigationItem?>(
            get: { selectedConferenceId.map { ConferenceNavigationItem(conferenceId: $0) } },
            set: { _ in selectedConferenceId = nil }
        )) { item in
            TalksListView(initialFilters: TalkSearchFilters.forConference(item.conferenceId))
        }
        .sheet(item: $selectedBlogPost) { blogPost in
            BlogDetailView(blogPost: blogPost)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    private func loadLatestContent() async {
        let timingToken = PerformanceMonitor.shared.startTiming("load_latest_content")

        isLoading = true
        error = nil

        do {
            let content = try await PerformanceMonitor.measureTime("fetch_latest_content") {
                try await serviceContainer.latestContentService.fetchLatestContent()
            }

            await MainActor.run {
                latestContent = content
            }
        } catch let apiError as APIError {
            await MainActor.run {
                error = apiError
            }
        } catch {
            await MainActor.run {
                self.error = APIError.networkError(error)
            }
        }

        isLoading = false
        PerformanceMonitor.shared.endTiming(timingToken)
    }
}

// Components are now defined in PTComponents.swift and PTCardComponents.swift

// MARK: - Previews

struct HomeView_Previews: PreviewProvider {
    @State static var selectedTab = 0

    static var previews: some View {
        HomeView(selectedTab: $selectedTab)
            .preferredColorScheme(.light)

        HomeView(selectedTab: $selectedTab)
            .preferredColorScheme(.dark)
    }
}
