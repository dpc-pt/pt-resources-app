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
    @StateObject private var latestContentService = LatestContentService()
    @State private var latestContent: LatestContentResponse?
    @State private var isLoading = false
    @State private var error: APIError?
    @State private var selectedConferenceId: String?
    @State private var selectedBlogPost: BlogPost?
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
                    PTWelcomeLoadingView()
                } else if let latestContent = latestContent {
                    ScrollView {
                        LazyVStack(spacing: PTDesignTokens.Spacing.lg) {
                            // Welcome Header
                            PTWelcomeHeader()

                            // Quick Actions
                            PTQuickActionsView(selectedTab: $selectedTab)

                            // Content Section
                            VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.md) {
                                Text("Latest Resources")
                                    .font(PTFont.ptSectionTitle)
                                    .foregroundColor(PTDesignTokens.Colors.ink)
                                    .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)

                                // Blog Post Card (Main Featured)
                                if let blogPost = latestContent.blogPost {
                                    PTFeaturedBlogCard(blogPost: blogPost, onTap: {
                                        selectedBlogPost = blogPost.toBlogPost()
                                    })
                                    .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
                                    .ptSectionBackground(
                                        baseColor: PTDesignTokens.Colors.surface.opacity(0.3),
                                        hasLogo: false,
                                        patternOpacity: 0.03
                                    )
                                }

                                // Latest Conference
                                if let latestConference = latestContent.latestConference {
                                    PTConferenceCard(
                                        conference: latestConference,
                                        isLatest: true,
                                        onTap: { selectedConferenceId = latestConference.conferenceId }
                                    )
                                    .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
                                }

                                // Archive Media
                                if let archiveMedia = latestContent.archiveMedia {
                                    PTConferenceCard(
                                        conference: archiveMedia,
                                        isLatest: false,
                                        onTap: { selectedConferenceId = archiveMedia.conferenceId }
                                    )
                                    .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
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
    }
    
    private func loadLatestContent() async {
        isLoading = true
        error = nil
        
        do {
            let content = try await latestContentService.fetchLatestContent()
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
    }
}

// MARK: - Welcome Header

struct PTWelcomeHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
                Text("Welcome")
                    .font(PTFont.ptDisplayLarge)
                    .foregroundColor(PTDesignTokens.Colors.ink)

                Text("to Proclamation Trust")
                    .font(PTFont.ptSectionTitle)
                    .foregroundColor(PTDesignTokens.Colors.tang)
            }

            Text("Here to help you teach the Bible")
                .font(PTFont.ptBodyText)
                .foregroundColor(PTDesignTokens.Colors.medium)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
        .padding(.top, PTDesignTokens.Spacing.lg)
        .padding(.bottom, PTDesignTokens.Spacing.md)
    }
}

// MARK: - Quick Actions

struct PTQuickActionsView: View {
    @Binding var selectedTab: Int

    var body: some View {
        VStack(spacing: PTDesignTokens.Spacing.sm) {
            Text("Quick Actions")
                .font(PTFont.ptCardTitle)
                .foregroundColor(PTDesignTokens.Colors.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)

            HStack(spacing: PTDesignTokens.Spacing.sm) {
                PTQuickActionButton(
                    title: "Browse Talks",
                    subtitle: "Sermons & resources",
                    icon: "headphones",
                    color: PTDesignTokens.Colors.kleinBlue
                ) {
                    selectedTab = 1 // Talks tab
                }

                PTQuickActionButton(
                    title: "Read Blog",
                    subtitle: "Latest updates",
                    icon: "newspaper",
                    color: PTDesignTokens.Colors.tang
                ) {
                    selectedTab = 3 // Blog tab
                }

                PTQuickActionButton(
                    title: "Downloads",
                    subtitle: "Offline access",
                    icon: "arrow.down.circle",
                    color: PTDesignTokens.Colors.lawn
                ) {
                    selectedTab = 2 // Downloads tab
                }
            }
            .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
            .ptSectionBackground(
                baseColor: Color.clear,
                hasLogo: false,
                patternOpacity: 0.02
            )
        }
    }
}

struct PTQuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: PTDesignTokens.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(PTFont.ptCardTitle)
                        .foregroundColor(color)
                }

                VStack(spacing: PTDesignTokens.Spacing.xs) {
                    Text(title)
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                        .fontWeight(.semibold)

                    Text(subtitle)
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, PTDesignTokens.Spacing.sm)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                .fill(PTDesignTokens.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                        .stroke(PTDesignTokens.Colors.light.opacity(0.2), lineWidth: 0.5)
                )
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Welcome Loading View

struct PTWelcomeLoadingView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: PTDesignTokens.Spacing.lg) {
            // Welcome text while loading
            VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.sm) {
                Text("Welcome")
                    .font(PTFont.ptDisplayLarge)
                    .foregroundColor(PTDesignTokens.Colors.ink)

                Text("Preparing your resources...")
                    .font(PTFont.ptBodyText)
                    .foregroundColor(PTDesignTokens.Colors.medium)
            }

            // Animated loading indicator
            VStack(spacing: PTDesignTokens.Spacing.md) {
                PTLogo(size: 48, showText: false)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
                    .onAppear {
                        isAnimating = true
                    }

                Text("Loading the latest talks and resources")
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(PTDesignTokens.Colors.medium)
            }
        }
        .padding(PTDesignTokens.Spacing.xl)
    }
}

// MARK: - Featured Blog Card

struct PTFeaturedBlogCard: View {
    let blogPost: LatestBlogPost
    let onTap: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Image
                AsyncImage(url: blogPost.imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        PTBrandingService.shared.createBrandedBackground(
                            for: .general,
                            hasLogo: true
                        )
                        
                        Image("pt-resources")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 40)
                            .opacity(0.6)
                    }
                }
                .frame(height: 200)
                .clipped()
                
                // Content
                VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.md) {
                    // Category Badge
                    Text(blogPost.category.uppercased())
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.tang)
                        .tracking(0.5)
                    
                    // Title
                    Text(blogPost.title)
                        .font(PTFont.ptSectionTitle)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Excerpt
                    Text(blogPost.excerpt)
                        .font(PTFont.ptBodyText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    // Author and Date
                    HStack {
                        Text(blogPost.author)
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                        
                        Spacer()
                        
                        Text(blogPost.date)
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                    }
                }
                .padding(PTDesignTokens.Spacing.lg)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                .fill(PTDesignTokens.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                        .stroke(PTDesignTokens.Colors.light.opacity(0.2), lineWidth: 0.5)
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Conference Card

struct PTConferenceCard: View {
    let conference: ConferenceMedia
    let isLatest: Bool
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Conference Image
                AsyncImage(url: conference.imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        PTBrandingService.shared.createBrandedBackground(
                            for: .general,
                            hasLogo: true
                        )
                        
                        Image("pt-resources")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 26)
                            .opacity(isLatest ? 0.6 : 0.5)
                    }
                }
                .frame(height: 140)
                .clipped()
                
                // Content
                VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.sm) {
                    // Category Badge
                    HStack {
                        Text(conference.category.uppercased())
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(isLatest ? PTDesignTokens.Colors.kleinBlue : PTDesignTokens.Colors.lawn)
                            .tracking(0.5)
                        
                        Spacer()
                        
                        if isLatest {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(PTDesignTokens.Colors.tang)
                                    .frame(width: 6, height: 6)
                                Text("NEW")
                                    .font(PTFont.ptCaptionText)
                                    .foregroundColor(PTDesignTokens.Colors.tang)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    
                    // Title
                    Text(conference.title)
                        .font(PTFont.ptCardTitle)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Excerpt
                    Text(conference.excerpt)
                        .font(PTFont.ptBodyText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }
                .padding(PTDesignTokens.Spacing.md)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                .fill(PTDesignTokens.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                        .stroke(PTDesignTokens.Colors.light.opacity(0.2), lineWidth: 0.5)
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

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
