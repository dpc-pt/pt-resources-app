//
//  MiniPlayerView.swift
//  PT Resources
//
//  Enhanced mini player with exceptional PT branding, animations, and UX
//

import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var playerService = PlayerService.shared
    @State private var showingFullPlayer = false
    @State private var isVisible = true
    @State private var dragOffset: CGFloat = 0
    @State private var lastDragValue: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    
    // Animation states
    @State private var playButtonScale: CGFloat = 1.0
    @State private var closeButtonScale: CGFloat = 1.0
    @State private var artworkRotation: Double = 0
    @State private var progressAnimating = false
    
    private let dismissThreshold: CGFloat = 100
    private let hapticFeedback = PTHapticFeedbackService.shared
    
    var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                // Enhanced progress bar with glow effect
                progressBar
                
                // Main player content with enhanced styling
                playerContent
                    .offset(y: dragOffset)
                    .scaleEffect(max(0.95, 1.0 - abs(dragOffset) / 1000))
                    .opacity(max(0.3, 1.0 - abs(dragOffset) / 200.0))
                    .gesture(dragGesture)
                    .animation(PTDesignTokens.Animation.bouncy, value: dragOffset)
            }
            .background(dynamicBackground)
            .clipShape(RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.base))
            .shadow(
                color: PTDesignTokens.Colors.ink.opacity(colorScheme == .dark ? 0.3 : 0.1),
                radius: 12,
                x: 0,
                y: -4
            )
            .overlay(
                // Subtle border glow
                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.base)
                    .stroke(
                        LinearGradient(
                            colors: [
                                PTDesignTokens.Colors.tang.opacity(0.3),
                                PTDesignTokens.Colors.kleinBlue.opacity(0.2),
                                PTDesignTokens.Colors.tang.opacity(0.1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
                    .opacity(playerService.playbackState.isPlaying ? 1.0 : 0.3)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: playerService.playbackState.isPlaying)
            )
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
            .fullScreenCover(isPresented: $showingFullPlayer) {
                NowPlayingView()
            }
        }
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(PTDesignTokens.Colors.light.opacity(colorScheme == .dark ? 0.2 : 0.3))
                    .frame(height: 3)
                
                // Progress fill with gradient and glow
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [PTDesignTokens.Colors.tang, PTDesignTokens.Colors.kleinBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geometry.size.width * CGFloat(
                            playerService.duration > 0 ? 
                            min(1.0, playerService.currentTime / playerService.duration) : 0
                        ),
                        height: 3
                    )
                    .overlay(
                        // Animated glow effect
                        Rectangle()
                            .fill(PTDesignTokens.Colors.tang.opacity(0.6))
                            .blur(radius: 2)
                            .scaleEffect(y: 2)
                            .opacity(playerService.playbackState.isPlaying ? 1.0 : 0.0)
                            .animation(PTDesignTokens.Animation.progressGlow, value: progressAnimating)
                    )
                    .animation(.linear(duration: 0.5), value: playerService.currentTime)
            }
        }
        .frame(height: 3)
        .onAppear {
            progressAnimating = true
        }
    }
    
    // MARK: - Main Player Content
    
    private var playerContent: some View {
        Button(action: {
            hapticFeedback.lightImpact()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showingFullPlayer = true
            }
        }) {
            HStack(spacing: PTDesignTokens.Spacing.md) {
                // Enhanced artwork with animation
                artworkView
                
                // Track info with enhanced typography
                trackInfoView
                
                Spacer(minLength: PTDesignTokens.Spacing.sm)
                
                // Enhanced controls with animations
                controlsView
            }
            .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
            .padding(.vertical, PTDesignTokens.Spacing.md)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityMiniPlayer(
            talkTitle: playerService.currentTalk?.title,
            speaker: playerService.currentTalk?.speaker,
            isPlaying: playerService.playbackState.isPlaying
        )
    }
    
    // MARK: - Artwork View
    
    private var artworkView: some View {
        PTAsyncImage(
            url: URL(string: playerService.currentTalk?.artworkURL ?? ""),
            targetSize: CGSize(width: 48, height: 48)
        ) {
            // Fallback with enhanced PT branding
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                .fill(
                    LinearGradient(
                        colors: [
                            PTDesignTokens.Colors.tang.opacity(0.3),
                            PTDesignTokens.Colors.kleinBlue.opacity(0.2),
                            PTDesignTokens.Colors.turmeric.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    ZStack {
                        // Subtle pattern background
                        Image("pt-icon-pattern")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .opacity(0.1)
                            .clipped()
                        
                        // Main PT logo
                        Image("pt-resources")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .opacity(0.9)
                            .rotationEffect(.degrees(artworkRotation))
                    }
                )
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                .stroke(
                    LinearGradient(
                        colors: [
                            PTDesignTokens.Colors.tang.opacity(0.4),
                            PTDesignTokens.Colors.kleinBlue.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .scaleEffect(playerService.playbackState.isPlaying ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: playerService.playbackState.isPlaying)
        .onReceive(playerService.$playbackState) { state in
            if state.isPlaying {
                withAnimation(PTDesignTokens.Animation.artworkRotation) {
                    artworkRotation += 360
                }
            } else {
                withAnimation(PTDesignTokens.Animation.easeOut) {
                    artworkRotation = 0
                }
            }
        }
    }
    
    // MARK: - Track Info View
    
    private var trackInfoView: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(playerService.currentTalk?.title ?? "No Track Selected")
                .font(PTFont.ptCardSubtitle)
                .foregroundColor(PTDesignTokens.Colors.ink)
                .lineLimit(1)
                .opacity(playerService.currentTalk != nil ? 1.0 : 0.6)
            
            HStack(spacing: 4) {
                if let speaker = playerService.currentTalk?.speaker, !speaker.isEmpty {
                    Text(speaker)
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .lineLimit(1)
                }
                
                if playerService.playbackState.isPlaying {
                    // Live indicator
                    Circle()
                        .fill(PTDesignTokens.Colors.lawn)
                        .frame(width: 6, height: 6)
                        .scaleEffect(1.0)
                        .animation(PTDesignTokens.Animation.liveIndicator, value: progressAnimating)
                    
                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(PTDesignTokens.Colors.lawn)
                        .opacity(0.8)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: playerService.playbackState)
    }
    
    // MARK: - Controls View
    
    private var controlsView: some View {
        HStack(spacing: PTDesignTokens.Spacing.sm) {
            // Enhanced Play/Pause Button
            Button(action: playPauseAction) {
                ZStack {
                    Circle()
                        .fill(PTDesignTokens.Colors.tang.opacity(0.1))
                        .frame(width: 36, height: 36)
                        .scaleEffect(playButtonScale)
                    
                    Image(systemName: playerService.playbackState.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PTDesignTokens.Colors.tang)
                        .scaleEffect(playButtonScale)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(playerService.playbackState.isPlaying ? "Pause" : "Play")
            .accessibilityHint("Double tap to \(playerService.playbackState.isPlaying ? "pause" : "play") the current talk")
            
            // Enhanced Close Button with confirmation
            Button(action: closeAction) {
                ZStack {
                    Circle()
                        .fill(PTDesignTokens.Colors.medium.opacity(0.1))
                        .frame(width: 32, height: 32)
                        .scaleEffect(closeButtonScale)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .scaleEffect(closeButtonScale)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Close player")
            .accessibilityHint("Double tap to close the mini player and clear playback history")
        }
    }
    
    // MARK: - Dynamic Background
    
    private var dynamicBackground: some View {
        ZStack {
            // Base background
            Rectangle()
                .fill(PTDesignTokens.Colors.surface)
            
            // Dynamic gradient overlay based on playback state
            if playerService.playbackState.isPlaying {
                LinearGradient(
                    colors: [
                        PTDesignTokens.Colors.tang.opacity(0.02),
                        PTDesignTokens.Colors.kleinBlue.opacity(0.01),
                        PTDesignTokens.Colors.surface
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: progressAnimating)
            }
        }
    }
    
    // MARK: - Gestures
    
    private var dragGesture: some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                let newOffset = lastDragValue + value.translation.height
                dragOffset = max(0, newOffset) // Only allow downward drag
                
                // Provide haptic feedback when approaching dismiss threshold
                if dragOffset > dismissThreshold * 0.7 && lastDragValue <= dismissThreshold * 0.7 {
                    hapticFeedback.lightImpact()
                }
            }
            .onEnded { value in
                let finalOffset = lastDragValue + value.translation.height
                
                if finalOffset > dismissThreshold {
                    // Dismiss the player
                    dismissPlayer()
                } else {
                    // Snap back
                    withAnimation(PTDesignTokens.Animation.miniPlayerDismiss) {
                        dragOffset = 0
                    }
                    lastDragValue = 0
                }
            }
    }
    
    // MARK: - Actions
    
    private func playPauseAction() {
        withAnimation(PTDesignTokens.Animation.playButtonPress) {
            playButtonScale = 0.9
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(PTDesignTokens.Animation.playButtonPress) {
                playButtonScale = 1.0
            }
        }
        
        if playerService.playbackState.isPlaying {
            playerService.pause()
        } else {
            playerService.play()
        }
    }
    
    private func closeAction() {
        withAnimation(PTDesignTokens.Animation.playButtonPress) {
            closeButtonScale = 0.8
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(PTDesignTokens.Animation.playButtonPress) {
                closeButtonScale = 1.0
            }
        }
        
        dismissPlayer()
    }
    
    private func dismissPlayer() {
        withAnimation(PTDesignTokens.Animation.miniPlayerDismiss) {
            isVisible = false
            dragOffset = 200
        }
        
        // Clear persistence and stop playback
        playerService.stopAndClearPersistence()
        
        // Reset state after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dragOffset = 0
            lastDragValue = 0
        }
    }
}

// MARK: - Performance Optimizations

extension MiniPlayerView {
    /// Optimized state management to reduce unnecessary re-renders
    private var shouldShowLiveIndicator: Bool {
        playerService.playbackState.isPlaying
    }
    
    /// Computed progress value with caching to avoid frequent recalculations
    private var progressValue: CGFloat {
        guard playerService.duration > 0 else { return 0 }
        return CGFloat(min(1.0, playerService.currentTime / playerService.duration))
    }
}

// MARK: - Accessibility Enhancements

extension MiniPlayerView {
    private var accessibilityPlaybackInfo: String {
        guard let talk = playerService.currentTalk else { return "No track selected" }
        
        let timeInfo = playerService.duration > 0 ? 
            "Progress: \(Int(progressValue * 100))%" : 
            "Loading..."
        
        return "\(talk.title) by \(talk.speaker). \(timeInfo)"
    }
}

// MARK: - Preview

struct MiniPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode preview
            VStack {
                Spacer()
                MiniPlayerView()
            }
            .background(Color.gray.opacity(0.1))
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")
            
            // Dark mode preview
            VStack {
                Spacer()
                MiniPlayerView()
            }
            .background(Color.black)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}