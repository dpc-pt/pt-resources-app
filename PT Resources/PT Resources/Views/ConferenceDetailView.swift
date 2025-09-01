//
//  ConferenceDetailView.swift
//  PT Resources
//
//  Conference detail view with resource list and Download All functionality
//

import SwiftUI

struct ConferenceDetailView: View {
    let conference: ConferenceInfo
    
    @StateObject private var viewModel: ConferencesViewModel
    @StateObject private var downloadService: DownloadService
    @ObservedObject private var playerService = PlayerService.shared
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var conferenceResources: [Talk] = []
    @State private var isLoadingResources = false
    @State private var resourceError: APIError?
    @State private var selectedTalk: Talk?
    @State private var showingDownloadAllAlert = false
    @State private var isDownloadingAll = false
    @State private var downloadAllProgress: [String: Float] = [:]
    
    init(conference: ConferenceInfo) {
        self.conference = conference
        self._viewModel = StateObject(wrappedValue: ConferencesViewModel())
        self._downloadService = StateObject(wrappedValue: DownloadService(apiService: TalksAPIService()))
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Conference Header
                conferenceHeader
                
                // Resources Section
                resourcesSection
            }
        }
        .background(PTDesignTokens.Colors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: PTDesignTokens.Spacing.xs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Back")
                            .font(PTFont.ptBodyText)
                    }
                    .foregroundColor(PTDesignTokens.Colors.ink)
                }
            }
        }
        .navigationDestination(item: $selectedTalk) { talk in
            TalkDetailView(talk: talk, downloadService: downloadService)
        }
        .alert("Download All Resources", isPresented: $showingDownloadAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Download") {
                downloadAllResources()
            }
        } message: {
            Text("Do you want to download all \(conferenceResources.count) resources from \(conference.displayTitle)?")
        }
        .onAppear {
            loadConferenceResources()
        }
    }
    
    // MARK: - Conference Header
    
    private var conferenceHeader: some View {
        VStack(spacing: 0) {
            // Conference Image
            Group {
                if let artworkURL = conference.artworkURL, let url = URL(string: artworkURL) {
                    PTAsyncImage(
                        url: url,
                        targetSize: CGSize(width: 400, height: 300)
                    ) {
                        // Fallback to local PT Resources logo
                        Image("pt-resources")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                } else {
                    // Use local PT Resources logo directly with branded background
                    ZStack {
                        PTBrandingService.shared.createBrandedBackground(
                            for: .conference,
                            hasLogo: true
                        )
                        
                        VStack(spacing: PTDesignTokens.Spacing.md) {
                            PTLogo(size: 64, showText: true)
                                .foregroundColor(.white.opacity(0.9))
                            
                            Text(conference.displayTitle)
                                .font(PTFont.ptDisplaySmall)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
            .aspectRatio(4/3, contentMode: .fill)
            .clipped()
            
            // Conference Info Overlay
            VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.md) {
                // Download All Button in top right
                HStack {
                    Spacer()

                    Button(action: {
                        if hasDownloadableResources {
                            showingDownloadAllAlert = true
                        }
                    }) {
                        HStack(spacing: PTDesignTokens.Spacing.xs) {
                            if isDownloadingAll {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(.white)
                            } else {
                                Image(systemName: hasDownloadableResources ? "arrow.down.circle.fill" : "checkmark.circle.fill")
                                    .font(PTFont.ptButtonText)
                            }

                            Text(downloadAllButtonText)
                                .font(PTFont.ptCaptionText)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, PTDesignTokens.Spacing.sm)
                        .padding(.vertical, PTDesignTokens.Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                .fill(hasDownloadableResources ? PTDesignTokens.Colors.kleinBlue.opacity(0.8) : PTDesignTokens.Colors.lawn.opacity(0.8))
                        )
                    }
                    .disabled(!hasDownloadableResources || isDownloadingAll)
                }

                HStack {
                    VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
                        Text(conference.displayTitle)
                            .font(PTFont.ptDisplaySmall)
                            .foregroundColor(PTDesignTokens.Colors.ink)

                        HStack(spacing: PTDesignTokens.Spacing.sm) {
                            Text(conference.year)
                                .font(PTFont.ptCardSubtitle)
                                .foregroundColor(PTDesignTokens.Colors.tang)

                            Text("•")
                                .foregroundColor(PTDesignTokens.Colors.medium)

                            HStack(spacing: PTDesignTokens.Spacing.xs) {
                                Image(systemName: "doc.text")
                                    .font(.caption)
                                Text("\(conference.resourceCount) resources")
                                    .font(PTFont.ptCardSubtitle)
                            }
                            .foregroundColor(PTDesignTokens.Colors.medium)
                        }
                    }

                    Spacer()
                }
                
                if let description = conference.description, !description.isEmpty {
                    Text(description)
                        .font(PTFont.ptBodyText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(PTDesignTokens.Spacing.cardPadding)
            .background(PTDesignTokens.Colors.surface)
        }
        .cornerRadius(PTDesignTokens.BorderRadius.card, corners: [.bottomLeft, .bottomRight])
        .shadow(
            color: PTDesignTokens.Shadows.card.color,
            radius: PTDesignTokens.Shadows.card.radius,
            x: PTDesignTokens.Shadows.card.x,
            y: PTDesignTokens.Shadows.card.y
        )
        .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
    }
    

    
    // MARK: - Resources Section
    
    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.md) {
            HStack {
                Text("Conference Resources")
                    .font(PTFont.ptSectionTitle)
                    .foregroundColor(PTDesignTokens.Colors.ink)
                
                Spacer()
                
                if !conferenceResources.isEmpty {
                    Text("\(conferenceResources.count) resources")
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                }
            }
            .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
            
            if isLoadingResources {
                PTConferenceResourcesLoadingView()
                    .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
            } else if conferenceResources.isEmpty {
                PTConferenceResourcesEmptyView()
                    .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
            } else {
                LazyVStack(spacing: PTDesignTokens.Spacing.md) {
                    ForEach(conferenceResources) { resource in
                        TalkRowView(
                            talk: resource,
                            isDownloaded: isTalkDownloaded(resource.id),
                            downloadProgress: downloadService.downloadProgress[resource.id],
                            onTalkTap: { selectedTalk = resource },
                            onPlayTap: { playTalk(resource) },
                            onDownloadTap: { downloadTalk(resource) }
                        )
                        .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
                    }
                }
            }
        }
        .padding(.top, PTDesignTokens.Spacing.lg)
        .padding(.bottom, PTDesignTokens.Spacing.xxl)
    }
    
    // MARK: - Helper Properties
    
    private var hasDownloadableResources: Bool {
        return conferenceResources.contains { resource in
            guard let audioURL = resource.audioURL, !audioURL.isEmpty else { return false }
            return !audioURL.contains("vimeo.com")
        }
    }
    
    private var downloadedResourceCount: Int {
        return conferenceResources.filter { isTalkDownloaded($0.id) }.count
    }
    
    private var downloadAllButtonText: String {
        if isDownloadingAll {
            return "Downloading..."
        } else if downloadedResourceCount == conferenceResources.count && downloadedResourceCount > 0 {
            return "Downloaded"
        } else if downloadedResourceCount > 0 {
            return "Download (\(conferenceResources.count - downloadedResourceCount))"
        } else {
            return "Download All"
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadConferenceResources() {
        Task {
            isLoadingResources = true
            resourceError = nil
            
            if let response = await viewModel.fetchConferenceResources(conferenceId: conference.id) {
                conferenceResources = response.talks
            } else {
                resourceError = viewModel.error
            }
            
            isLoadingResources = false
        }
    }
    
    private func isTalkDownloaded(_ talkId: String) -> Bool {
        // Check the download service's synchronous cache
        return downloadService.isDownloadedSync(talkId)
    }
    
    private func playTalk(_ talk: Talk) {
        playerService.loadTalk(talk)
        playerService.play()
    }
    
    private func downloadTalk(_ talk: Talk) {
        Task {
            do {
                try await downloadService.downloadTalk(talk)
            } catch {
                print("Failed to download talk: \(error)")
            }
        }
    }
    
    private func downloadAllResources() {
        guard !isDownloadingAll else { return }
        
        let downloadableResources = conferenceResources.filter { resource in
            guard let audioURL = resource.audioURL, !audioURL.isEmpty else { return false }
            return !audioURL.contains("vimeo.com") && !isTalkDownloaded(resource.id)
        }
        
        guard !downloadableResources.isEmpty else { return }
        
        isDownloadingAll = true
        
        Task {
            for resource in downloadableResources {
                do {
                    try await downloadService.downloadTalk(resource)
                } catch {
                    print("Failed to download \(resource.title): \(error)")
                }
            }
            isDownloadingAll = false
        }
    }
}

// MARK: - Loading and Empty States for Resources

struct PTConferenceResourcesLoadingView: View {
    var body: some View {
        VStack(spacing: PTDesignTokens.Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(PTDesignTokens.Colors.tang)
            
            Text("Loading conference resources...")
                .font(PTFont.ptBodyText)
                .foregroundColor(PTDesignTokens.Colors.medium)
        }
        .padding(PTDesignTokens.Spacing.xl)
    }
}

struct PTConferenceResourcesEmptyView: View {
    var body: some View {
        VStack(spacing: PTDesignTokens.Spacing.md) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(PTDesignTokens.Colors.light)
            
            Text("No Resources Found")
                .font(PTFont.ptCardTitle)
                .foregroundColor(PTDesignTokens.Colors.ink)
            
            Text("This conference doesn't have any available resources at the moment.")
                .font(PTFont.ptBodyText)
                .foregroundColor(PTDesignTokens.Colors.medium)
                .multilineTextAlignment(.center)
        }
        .padding(PTDesignTokens.Spacing.xl)
    }
}


// MARK: - Preview

#Preview {
    NavigationStack {
        ConferenceDetailView(conference: ConferenceInfo.mockConferences.first!)
    }
}