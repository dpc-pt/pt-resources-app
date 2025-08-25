//
//  PTMediaPlayerView.swift
//  PT Resources
//
//  Modern media player with PT branding inspired by Apple Music/Spotify
//

import SwiftUI

struct PTMediaPlayerView: View {
    let resource: ResourceDetail
    @StateObject private var playerService: PlayerService
    @Environment(\.dismiss) private var dismiss
    
    @State private var isExpanded = false
    @State private var showingMoreOptions = false
    @State private var dragOffset: CGFloat = 0
    @State private var isPressed = false
    
    init(resource: ResourceDetail, playerService: PlayerService) {
        self.resource = resource
        self._playerService = StateObject(wrappedValue: playerService)
    }
    
    var body: some View {
        ZStack {
            // Background with blur effect
            backgroundView
            
            VStack(spacing: 0) {
                // Drag indicator
                dragIndicator
                
                // Artwork and basic info
                artworkSection
                
                // Controls section
                controlsSection
                
                // Progress and time
                progressSection
                
                // Action buttons
                actionButtons
                
                // Related resources
                if !resource.relatedResources.isEmpty {
                    relatedResourcesSection
                }
                
                Spacer()
            }
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
    
    // MARK: - Background View
    
    private var backgroundView: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        PTDesignTokens.Colors.ink,
                        PTDesignTokens.Colors.kleinBlue.opacity(0.8),
                        Color.ptBackground
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .ignoresSafeArea()
    }
    
    // MARK: - Drag Indicator
    
    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white.opacity(0.3))
            .frame(width: 36, height: 4)
            .padding(.top, 8)
    }
    
    // MARK: - Artwork Section
    
    private var artworkSection: some View {
        VStack(spacing: PTSpacing.lg) {
            // Close button
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.down")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                }
                
                Spacer()
                
                Button(action: { showingMoreOptions = true }) {
                    Image(systemName: "ellipsis")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                }
            }
            
            // Artwork
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [PTDesignTokens.Colors.tang.opacity(0.3), PTDesignTokens.Colors.kleinBlue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Image("pt-resources")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 40)
                        .opacity(0.8)
                )
                .frame(width: 280, height: 280)
                .cornerRadius(PTCornerRadius.large)
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            
            // Track info
            VStack(spacing: PTSpacing.xs) {
                Text(resource.title)
                    .font(PTFont.ptSectionTitle)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(resource.speaker)
                    .font(PTFont.ptBodyText)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(resource.conference)
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, PTSpacing.md)
                    .padding(.vertical, PTSpacing.xs)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                    )
            }
        }
        .padding(.horizontal, PTSpacing.screenPadding)
    }
    
    // MARK: - Controls Section
    
    private var controlsSection: some View {
        HStack(spacing: PTSpacing.xxl) {
            // Previous (Skip back 30s)
            Button(action: { playerService.skipBackward() }) {
                Image(systemName: "gobackward.30")
                    .font(.title)
                    .foregroundColor(.white)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            
            // Play/Pause
            Button(action: { 
                if playerService.isPlaying {
                    playerService.pause()
                } else {
                    playerService.play()
                }
            }) {
                Image(systemName: playerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.white)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            
            // Next (Skip forward 30s)
            Button(action: { playerService.skipForward() }) {
                Image(systemName: "goforward.30")
                    .font(.title)
                    .foregroundColor(.white)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .padding(.vertical, PTSpacing.lg)
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        VStack(spacing: PTSpacing.sm) {
            // Progress bar
            ProgressView(value: playerService.currentTime, total: playerService.duration)
                .progressViewStyle(PTMediaProgressStyle())
                .frame(height: 4)
            
            // Time labels
            HStack {
                Text(timeString(from: playerService.currentTime))
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Text("-\(timeString(from: playerService.duration - playerService.currentTime))")
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, PTSpacing.screenPadding)
        .padding(.vertical, PTSpacing.md)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: PTSpacing.xl) {
            // Speed control
            Button(action: { 
                playerService.adjustPlaybackSpeed()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Text("\(playerService.playbackSpeed, specifier: "%.1f")x")
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Spacer()
            
            // Download
            Button(action: { 
                // TODO: Implement download
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Text("Download")
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Spacer()
            
            // Share
            Button(action: { 
                // TODO: Implement share
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Text("Share")
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Spacer()
            
            // More options
            Button(action: { showingMoreOptions = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Text("More")
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, PTSpacing.screenPadding)
        .padding(.vertical, PTSpacing.lg)
    }
    
    // MARK: - Related Resources
    
    private var relatedResourcesSection: some View {
        VStack(alignment: .leading, spacing: PTSpacing.md) {
            HStack {
                Text("Related Resources")
                    .font(PTFont.ptCardTitle)
                    .foregroundColor(.white)
                    .padding(.horizontal, PTSpacing.screenPadding)
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PTSpacing.md) {
                    ForEach(resource.relatedResources.prefix(5)) { related in
                        PTRelatedResourceCard(resource: related)
                    }
                }
                .padding(.horizontal, PTSpacing.screenPadding)
            }
        }
        .padding(.vertical, PTSpacing.md)
    }
    
    // MARK: - Helper Methods
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Progress View Style

struct PTMediaProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack(alignment: .leading) {
            // Background
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.3))
                .frame(height: 4)
            
            // Progress
            RoundedRectangle(cornerRadius: 2)
                .fill(PTDesignTokens.Colors.tang)
                .frame(
                    width: CGFloat(configuration.fractionCompleted ?? 0) * UIScreen.main.bounds.width * 0.8,
                    height: 4
                )
        }
    }
}

// MARK: - Related Resource Card

struct PTRelatedResourceCard: View {
    let resource: RelatedResource
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // TODO: Navigate to related resource
        }) {
            VStack(alignment: .leading, spacing: PTSpacing.sm) {
                // Artwork
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [PTDesignTokens.Colors.lawn.opacity(0.3), PTDesignTokens.Colors.kleinBlue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image("pt-resources")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 20)
                            .opacity(0.6)
                    )
                    .frame(width: 140, height: 140)
                    .cornerRadius(PTCornerRadius.medium)
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(resource.title)
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(resource.speaker)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
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
            resource: ResourceDetailResponse.mockData.resource,
            playerService: PlayerService()
        )
    }
}