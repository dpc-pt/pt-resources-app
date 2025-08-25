//
//  ResourceDetailView.swift
//  PT Resources
//
//  Detailed view for individual resources
//

import SwiftUI

struct ResourceDetailView: View {
    let resourceId: String
    @StateObject private var resourceService = ResourceDetailService()
    @StateObject private var playerService = PlayerService()
    @StateObject private var downloadService = DownloadService(apiService: TalksAPIService())
    
    @State private var resource: ResourceDetail?
    @State private var isLoading = true
    @State private var error: APIError?
    @State private var showingMediaPlayer = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.ptBackground.ignoresSafeArea()
                
                if isLoading {
                    PTLoadingView()
                } else if let resource = resource {
                    ScrollView {
                        VStack(spacing: PTSpacing.lg) {
                            // Hero section
                            heroSection(resource: resource)
                            
                            // Content section
                            contentSection(resource: resource)
                            
                            // Related resources
                            if !resource.relatedResources.isEmpty {
                                relatedResourcesSection(resource: resource)
                            }
                        }
                        .padding(.bottom, PTSpacing.xxl)
                    }
                } else if error != nil {
                    PTEmptyStateView()
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            await loadResource()
        }
        .fullScreenCover(isPresented: $showingMediaPlayer) {
            if let resource = resource {
                PTMediaPlayerView(resource: resource, playerService: playerService)
            }
        }
    }
    
    // MARK: - Hero Section
    
    private func heroSection(resource: ResourceDetail) -> some View {
        VStack(spacing: 0) {
            // Navigation bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                        .padding()
                }
                
                Spacer()
                
                Button(action: {
                    // TODO: Share functionality
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                        .padding()
                }
            }
            
            // Artwork and basic info
            VStack(spacing: PTSpacing.lg) {
                // Artwork
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [PTDesignTokens.Colors.tang.opacity(0.1), PTDesignTokens.Colors.kleinBlue.opacity(0.1)],
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
                    .frame(width: 240, height: 240)
                    .cornerRadius(PTCornerRadius.large)
                    .shadow(color: PTDesignTokens.Colors.ink.opacity(0.1), radius: 10, x: 0, y: 5)
                
                // Title and info
                VStack(spacing: PTSpacing.sm) {
                    Text(resource.title)
                        .font(PTFont.ptSectionTitle)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, PTSpacing.lg)
                    
                    Text(resource.speaker)
                        .font(PTFont.ptCardTitle)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                    
                    HStack {
                        Text(resource.conference)
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                        
                        Text("•")
                            .foregroundColor(PTDesignTokens.Colors.medium)
                        
                        Text(resource.date)
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                    }
                    
                    if !resource.scriptureReference.isEmpty {
                        Text(resource.scriptureReference)
                            .font(PTFont.ptBodyText)
                            .foregroundColor(PTDesignTokens.Colors.kleinBlue)
                            .padding(.horizontal, PTSpacing.md)
                            .padding(.vertical, PTSpacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                    .fill(PTDesignTokens.Colors.kleinBlue.opacity(0.1))
                            )
                    }
                }
            }
            .padding(.horizontal, PTSpacing.screenPadding)
            
            // Action buttons
            actionButtonsSection(resource: resource)
        }
    }
    
    // MARK: - Action Buttons
    
    private func actionButtonsSection(resource: ResourceDetail) -> some View {
        HStack(spacing: PTSpacing.md) {
            // Play button
            Button(action: {
                if resource.audioURL != nil {
                    showingMediaPlayer = true
                    // TODO: Start audio playback
                } else if resource.videoURL != nil {
                    showingMediaPlayer = true
                    // TODO: Start video playback
                }
            }) {
                HStack(spacing: PTSpacing.sm) {
                    Image(systemName: resource.videoUrl.isEmpty ? "play.fill" : "play.rectangle.fill")
                        .font(.title3)
                    Text(resource.videoUrl.isEmpty ? "Listen" : "Watch")
                        .font(PTFont.ptCardTitle)
                }
                .foregroundColor(.white)
                .padding(.horizontal, PTSpacing.xl)
                .padding(.vertical, PTSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: PTCornerRadius.button)
                        .fill(PTDesignTokens.Colors.tang)
                )
            }
            .disabled(resource.audioURL == nil && resource.videoURL == nil)
            
            // Download button
            Button(action: {
                // TODO: Download functionality
            }) {
                Image(systemName: "arrow.down.circle")
                    .font(.title2)
                    .foregroundColor(PTDesignTokens.Colors.ink)
                    .padding()
                    .background(
                        Circle()
                            .fill(Color.ptSurface)
                            .overlay(
                                Circle()
                                    .stroke(PTDesignTokens.Colors.medium.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            
            // Share button
            Button(action: {
                // TODO: Share functionality
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title2)
                    .foregroundColor(PTDesignTokens.Colors.ink)
                    .padding()
                    .background(
                        Circle()
                            .fill(Color.ptSurface)
                            .overlay(
                                Circle()
                                    .stroke(PTDesignTokens.Colors.medium.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
        }
        .padding(.horizontal, PTSpacing.screenPadding)
        .padding(.vertical, PTSpacing.lg)
    }
    
    // MARK: - Content Section
    
    private func contentSection(resource: ResourceDetail) -> some View {
        VStack(alignment: .leading, spacing: PTSpacing.lg) {
            if !resource.description.isEmpty {
                VStack(alignment: .leading, spacing: PTSpacing.sm) {
                    Text("Description")
                        .font(PTFont.ptCardTitle)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                    
                    Text(resource.description)
                        .font(PTFont.ptBodyText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .lineSpacing(4)
                }
            }
            
            // Conference info
            VStack(alignment: .leading, spacing: PTSpacing.sm) {
                Text("Conference Details")
                    .font(PTFont.ptCardTitle)
                    .foregroundColor(PTDesignTokens.Colors.ink)
                
                PTInfoRow(title: "Conference", value: resource.conference)
                PTInfoRow(title: "Speaker", value: resource.speaker)
                PTInfoRow(title: "Date", value: resource.date)
                PTInfoRow(title: "Category", value: resource.category)
                
                if !resource.scriptureReference.isEmpty {
                    PTInfoRow(title: "Scripture", value: resource.scriptureReference)
                }
            }
        }
        .padding(.horizontal, PTSpacing.screenPadding)
    }
    
    // MARK: - Related Resources
    
    private func relatedResourcesSection(resource: ResourceDetail) -> some View {
        VStack(alignment: .leading, spacing: PTSpacing.md) {
            HStack {
                Text("Related Resources")
                    .font(PTFont.ptCardTitle)
                    .foregroundColor(PTDesignTokens.Colors.ink)
                    .padding(.horizontal, PTSpacing.screenPadding)
                
                Spacer()
            }
            
            LazyVStack(spacing: PTSpacing.sm) {
                ForEach(resource.relatedResources) { related in
                    PTRelatedResourceRow(resource: related)
                        .padding(.horizontal, PTSpacing.screenPadding)
                }
            }
        }
    }
    
    // MARK: - Load Resource
    
    private func loadResource() async {
        isLoading = true
        error = nil
        
        do {
            let response = try await resourceService.fetchResourceDetail(id: resourceId)
            await MainActor.run {
                resource = response.resource
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

// MARK: - Info Row Component

struct PTInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(PTFont.ptBodyText)
                .foregroundColor(PTDesignTokens.Colors.medium)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(PTFont.ptBodyText)
                .foregroundColor(PTDesignTokens.Colors.medium)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Related Resource Row

struct PTRelatedResourceRow: View {
    let resource: RelatedResource
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // TODO: Navigate to related resource
        }) {
            HStack(spacing: PTSpacing.md) {
                // Artwork
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [PTDesignTokens.Colors.lawn.opacity(0.1), PTDesignTokens.Colors.kleinBlue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image("pt-resources")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 10)
                            .opacity(0.5)
                    )
                    .frame(width: 56, height: 56)
                    .cornerRadius(PTCornerRadius.small)
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(resource.title)
                        .font(PTFont.ptBodyText)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(resource.speaker)
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                    
                    Text(resource.conference)
                        .font(.caption2)
                        .foregroundColor(PTDesignTokens.Colors.medium.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(PTDesignTokens.Colors.medium)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, PTDesignTokens.Spacing.xs)
        .padding(.horizontal, PTDesignTokens.Spacing.md)
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

// MARK: - Preview

struct ResourceDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ResourceDetailView(resourceId: "506ce344-825f-4124-8667-97f7e84ee5aa")
    }
}
