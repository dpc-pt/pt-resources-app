//
//  HomeView.swift
//  PT Resources
//
//  Beautiful homepage matching PT design guidelines
//

import SwiftUI

// MARK: - Navigation Item

struct ConferenceNavigationItem: Identifiable {
    let id = UUID()
    let conferenceId: String
}

struct HomeView: View {
    @StateObject private var latestContentService = LatestContentService()
    @State private var latestContent: LatestContentResponse?
    @State private var isLoading = false
    @State private var error: APIError?
    @State private var selectedConferenceId: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.ptBackground.ignoresSafeArea()
                
                if isLoading && latestContent == nil {
                    PTLoadingView()
                } else if let latestContent = latestContent {
                    ScrollView {
                        LazyVStack(spacing: PTSpacing.lg) {
                            // Blog Post Card (Main Featured)
                            if let blogPost = latestContent.blogPost {
                                PTFeaturedBlogCard(blogPost: blogPost)
                                    .padding(.horizontal, PTSpacing.screenPadding)
                            }
                            
                            // Latest Conference
                            if let latestConference = latestContent.latestConference {
                                PTConferenceCard(
                                    conference: latestConference,
                                    isLatest: true,
                                    onTap: { selectedConferenceId = latestConference.conferenceId }
                                )
                                .padding(.horizontal, PTSpacing.screenPadding)
                            }
                            
                            // Archive Media
                            if let archiveMedia = latestContent.archiveMedia {
                                PTConferenceCard(
                                    conference: archiveMedia,
                                    isLatest: false,
                                    onTap: { selectedConferenceId = archiveMedia.conferenceId }
                                )
                                .padding(.horizontal, PTSpacing.screenPadding)
                            }
                        }
                        .padding(.top, PTSpacing.md)
                        .padding(.bottom, PTSpacing.xxl)
                    }
                    .refreshable {
                        await loadLatestContent()
                    }
                } else {
                    PTEmptyStateView()
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await loadLatestContent()
        }
        .sheet(item: Binding<ConferenceNavigationItem?>(
            get: { selectedConferenceId.map { ConferenceNavigationItem(conferenceId: $0) } },
            set: { _ in selectedConferenceId = nil }
        )) { item in
            TalksListView() // TODO: Filter by conference ID
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

// MARK: - Featured Blog Card

struct PTFeaturedBlogCard: View {
    let blogPost: LatestBlogPost
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // TODO: Open blog post
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Image
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.ptCoral.opacity(0.1), Color.ptTurquoise.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image("pt-resources")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 40)
                            .opacity(0.6)
                    )
                .frame(height: 200)
                .clipped()
                
                // Content
                VStack(alignment: .leading, spacing: PTSpacing.md) {
                    // Category Badge
                    Text(blogPost.category.uppercased())
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(.ptCoral)
                        .tracking(0.5)
                    
                    // Title
                    Text(blogPost.title)
                        .font(PTFont.ptSectionTitle)
                        .foregroundColor(.ptPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Excerpt
                    Text(blogPost.excerpt)
                        .font(PTFont.ptBodyText)
                        .foregroundColor(.ptDarkGray)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    // Author and Date
                    HStack {
                        Text(blogPost.author)
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(.ptDarkGray)
                        
                        Spacer()
                        
                        Text(blogPost.date)
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(.ptDarkGray)
                    }
                }
                .padding(PTSpacing.lg)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .ptCardStyle(isPressed: isPressed)
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
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                isLatest ? Color.ptRoyalBlue.opacity(0.1) : Color.ptGreen.opacity(0.1),
                                isLatest ? Color.ptTurquoise.opacity(0.1) : Color.ptCoral.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image("pt-resources")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 26)
                            .opacity(isLatest ? 0.6 : 0.5)
                    )
                .frame(height: 140)
                .clipped()
                
                // Content
                VStack(alignment: .leading, spacing: PTSpacing.sm) {
                    // Category Badge
                    HStack {
                        Text(conference.category.uppercased())
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(isLatest ? .ptRoyalBlue : .ptGreen)
                            .tracking(0.5)
                        
                        Spacer()
                        
                        if isLatest {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.ptCoral)
                                    .frame(width: 6, height: 6)
                                Text("NEW")
                                    .font(PTFont.ptCaptionText)
                                    .foregroundColor(.ptCoral)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    
                    // Title
                    Text(conference.title)
                        .font(PTFont.ptCardTitle)
                        .foregroundColor(.ptPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Excerpt
                    Text(conference.excerpt)
                        .font(PTFont.ptBodyText)
                        .foregroundColor(.ptDarkGray)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }
                .padding(PTSpacing.md)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .ptCardStyle(isPressed: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Previews

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .preferredColorScheme(.light)
        
        HomeView()
            .preferredColorScheme(.dark)
    }
}
