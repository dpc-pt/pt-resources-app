//
//  PTMediaPlayerView.swift
//  PT Resources
//
//  Now Playing screen matching TalkDetailView design with PT branding
//

import SwiftUI

// PTLogo is already available in this module

struct PTMediaPlayerView: View {
    let resource: ResourceDetail
    @ObservedObject var playerService = PlayerService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var dragOffset: CGFloat = 0
    @State private var showingMoreOptions = false

    init(resource: ResourceDetail) {
        self.resource = resource
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Section with Resource Art & Info
                    heroSection

                    // Media Player Controls
                    mediaPlayerSection
                        .padding(.horizontal, PTDesignTokens.Spacing.md)
                        .padding(.bottom, PTDesignTokens.Spacing.lg)

                    // Resource Information Card
                    resourceInfoSection
                        .padding(.horizontal, PTDesignTokens.Spacing.md)
                        .padding(.bottom, PTDesignTokens.Spacing.lg)

                    // Action Buttons
                    actionButtonsSection
                        .padding(.horizontal, PTDesignTokens.Spacing.md)
                        .padding(.bottom, PTDesignTokens.Spacing.xl)

                    // Related resources
                    if !resource.relatedResources.isEmpty {
                        relatedResourcesSection
                    }
                }
            }
            .background(PTDesignTokens.Colors.background)
            .navigationBarHidden(true)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if dragOffset > 150 {
                        dismiss()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .offset(y: dragOffset)
    }
    
    // MARK: - Hero Section

    private var heroSection: some View {
        GeometryReader { geometry in
            ZStack {
                // Background image or default
                Group {
                    if let imageURL = resource.resourceImageURL {
                        AsyncImage(url: imageURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            defaultArtworkView
                        }
                    } else {
                        defaultArtworkView
                    }
                }
                .clipped()

                // Dark overlay for text readability
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 0) {
                    // Navigation overlay
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(PTFont.ptCardTitle)
                                .foregroundColor(.white)
                                .padding(PTDesignTokens.Spacing.sm)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.4))
                                )
                        }

                        Spacer()

                        HStack(spacing: PTDesignTokens.Spacing.sm) {
                            // Share button
                            Button(action: shareResource) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(PTFont.ptCardTitle)
                                    .foregroundColor(.white)
                                    .padding(PTDesignTokens.Spacing.sm)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.4))
                                    )
                            }
                        }
                    }
                    .padding(PTDesignTokens.Spacing.md)
                    .zIndex(1)

                    Spacer()

                    // Resource info overlay
                    VStack(spacing: PTDesignTokens.Spacing.md) {
                        Text(resource.title)
                            .font(PTFont.ptDisplayMedium)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

                        Text(resource.speaker)
                            .font(PTFont.ptSectionTitle)
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

                        HStack(spacing: PTDesignTokens.Spacing.md) {
                            if !resource.scriptureReference.isEmpty {
                                Text(resource.scriptureReference)
                                    .font(PTFont.ptCaptionText)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, PTDesignTokens.Spacing.sm)
                                    .padding(.vertical, PTDesignTokens.Spacing.xs)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.2))
                                    )
                            }

                            Text(resource.date)
                                .font(PTFont.ptCaptionText)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                    .padding(PTDesignTokens.Spacing.lg)
                    .zIndex(1)
                }
            }
        }
        .frame(height: 320)
        .cornerRadius(PTDesignTokens.BorderRadius.xl, corners: [.bottomLeft, .bottomRight])
    }

    private var defaultArtworkView: some View {
        Rectangle()
            .fill(PTDesignTokens.Colors.veryLight)
            .overlay(
                PTLogo(size: 60, showText: false)
                    .opacity(0.3)
            )
    }
    
    // MARK: - Media Player Section

    private var mediaPlayerSection: some View {
        VStack(spacing: PTDesignTokens.Spacing.lg) {
            // Progress bar
            VStack(spacing: PTDesignTokens.Spacing.sm) {
                ProgressView(value: playerService.currentTime, total: playerService.duration)
                    .progressViewStyle(PTMediaProgressStyle())
                    .frame(height: 6)

                HStack {
                    Text(timeString(from: playerService.currentTime))
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .monospacedDigit()

                    Spacer()

                    Text(timeString(from: playerService.duration))
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .monospacedDigit()
                }
            }

            // Playback controls
            HStack(spacing: PTDesignTokens.Spacing.xxl) {
                // Skip backward (10s)
                Button(action: { playerService.skipBackward() }) {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 24))
                        .foregroundColor(PTDesignTokens.Colors.ink)
                        .padding(PTDesignTokens.Spacing.sm)
                        .background(
                            Circle()
                                .fill(PTDesignTokens.Colors.veryLight)
                        )
                }

                // Play/Pause
                Button(action: {
                if playerService.currentTalk?.id == resource.id {
                    togglePlayback()
                } else {
                    // Load this resource into the player
                    playerService.loadResource(resource)
                    playerService.play()
                }
            }) {
                Image(systemName: playerService.currentTalk?.id == resource.id && playerService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .padding(PTDesignTokens.Spacing.lg)
                    .background(
                        Circle()
                            .fill(PTDesignTokens.Colors.tang)
                            .shadow(color: PTDesignTokens.Colors.tang.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                }
                .scaleEffect(playerService.isPlaying ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: playerService.isPlaying)

                // Skip forward (30s)
                Button(action: { playerService.skipForward() }) {
                    Image(systemName: "goforward.30")
                        .font(.system(size: 24))
                        .foregroundColor(PTDesignTokens.Colors.ink)
                        .padding(PTDesignTokens.Spacing.sm)
                        .background(
                            Circle()
                                .fill(PTDesignTokens.Colors.veryLight)
                        )
                }
            }

            // Speed control
            HStack {
                Text("Playback Speed")
                    .font(PTFont.ptCardSubtitle)
                    .foregroundColor(PTDesignTokens.Colors.ink)

                Spacer()

                Button(action: { playerService.adjustPlaybackSpeed() }) {
                    Text("\(playerService.playbackSpeed, specifier: "%.1f")×")
                        .font(PTFont.ptButtonText)
                        .foregroundColor(PTDesignTokens.Colors.kleinBlue)
                        .padding(.horizontal, PTDesignTokens.Spacing.md)
                        .padding(.vertical, PTDesignTokens.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                .fill(PTDesignTokens.Colors.kleinBlue.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                        .stroke(PTDesignTokens.Colors.kleinBlue, lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(PTDesignTokens.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xl)
                .fill(PTDesignTokens.Colors.surface)
                .shadow(color: PTDesignTokens.Colors.ink.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Resource Info Section

    private var resourceInfoSection: some View {
        VStack(spacing: PTDesignTokens.Spacing.lg) {
            // Conference info (if available)
            if !resource.conference.isEmpty {
                HStack {
                    VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
                        Text("Conference")
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        Text(resource.conference)
                            .font(PTFont.ptCardTitle)
                            .foregroundColor(PTDesignTokens.Colors.ink)
                    }

                    Spacer()

                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 24))
                        .foregroundColor(PTDesignTokens.Colors.kleinBlue)
                }
                .padding(PTDesignTokens.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.lg)
                        .fill(PTDesignTokens.Colors.kleinBlue.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.lg)
                                .stroke(PTDesignTokens.Colors.kleinBlue.opacity(0.2), lineWidth: 1)
                        )
                )
            }

            // Description (if available)
            if !resource.description.isEmpty {
                VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.sm) {
                    Text("About This Resource")
                        .font(PTFont.ptSectionTitle)
                        .foregroundColor(PTDesignTokens.Colors.ink)

                    Text(resource.description)
                        .font(PTFont.ptBodyText)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                        .lineSpacing(PTDesignTokens.Typography.lineHeightRelaxed)
                        .lineLimit(nil)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(PTDesignTokens.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xl)
                        .fill(PTDesignTokens.Colors.surface)
                        .shadow(color: PTDesignTokens.Colors.ink.opacity(0.1), radius: 8, x: 0, y: 4)
                )
            }
        }
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: PTDesignTokens.Spacing.md) {
            // Primary action - Scripture Reference
            if !resource.scriptureReference.isEmpty {
                Button(action: { /* TODO: Implement scripture view */ }) {
                    HStack(spacing: PTDesignTokens.Spacing.md) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 20))
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bible Passage")
                                .font(PTFont.ptButtonText)
                                .foregroundColor(.white)
                            Text(resource.scriptureReference)
                                .font(PTFont.ptCaptionText)
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(PTDesignTokens.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xl)
                            .fill(PTDesignTokens.Colors.kleinBlue)
                            .shadow(color: PTDesignTokens.Colors.kleinBlue.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                }
            }

            // Secondary action - Share
            Button(action: shareResource) {
                HStack(spacing: PTDesignTokens.Spacing.md) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                        .foregroundColor(PTDesignTokens.Colors.ink)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share Resource")
                            .font(PTFont.ptButtonText)
                            .foregroundColor(PTDesignTokens.Colors.ink)
                        Text("Share this resource with others")
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.kleinBlue)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                }
                .padding(PTDesignTokens.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xl)
                        .fill(PTDesignTokens.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xl)
                                .stroke(PTDesignTokens.Colors.light.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: PTDesignTokens.Colors.ink.opacity(0.1), radius: 8, x: 0, y: 4)
                )
            }
        }
    }
    
    // MARK: - Related Resources

    private var relatedResourcesSection: some View {
        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.md) {
            Text("Related Resources")
                .font(PTFont.ptSectionTitle)
                .foregroundColor(PTDesignTokens.Colors.ink)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PTDesignTokens.Spacing.md) {
                    ForEach(resource.relatedResources.prefix(5)) { related in
                        PTRelatedResourceCard(resource: related)
                    }
                }
            }
        }
        .padding(PTDesignTokens.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xl)
                .fill(PTDesignTokens.Colors.surface)
                .shadow(color: PTDesignTokens.Colors.ink.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Helper Methods

    private func togglePlayback() {
        if playerService.isPlaying {
            playerService.pause()
        } else {
            playerService.play()
        }
    }

    private func shareResource() {
        let shareText = "Check out this resource: \(resource.title) by \(resource.speaker)"
        var activityItems: [Any] = [shareText]
        if let audioURL = resource.audioURL {
            activityItems.append(audioURL)
        }
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }

    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Progress View Style

// Note: PTMediaProgressStyle is defined in TalkDetailView.swift to avoid duplication

// MARK: - Related Resource Card

struct PTRelatedResourceCard: View {
    let resource: RelatedResource
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            // TODO: Navigate to related resource
        }) {
            VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.sm) {
                // Artwork
                ZStack {
                    Rectangle()
                        .fill(PTDesignTokens.Colors.veryLight)
                        .frame(width: 140, height: 140)
                        .cornerRadius(PTDesignTokens.BorderRadius.lg)

                    if let imageURL = resource.resourceImageURL {
                        AsyncImage(url: imageURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 140, height: 140)
                                .cornerRadius(PTDesignTokens.BorderRadius.lg)
                        } placeholder: {
                            PTLogo(size: 40, showText: false)
                                .opacity(0.3)
                        }
                    } else {
                        PTLogo(size: 40, showText: false)
                            .opacity(0.3)
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
                    Text(resource.title)
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(resource.speaker)
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .lineLimit(1)

                    Text(resource.date)
                        .font(.caption2)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .lineLimit(1)
                }
                .frame(width: 140, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Preview

struct PTMediaPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        PTMediaPlayerView(
            resource: ResourceDetailResponse.mockData.resource
        )
    }
}