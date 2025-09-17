//
//  NowPlayingView.swift
//  PT Resources
//
//  Enhanced Now Playing view with transcription integration and PT brand design
//

import SwiftUI
import MediaPlayer
import AVKit

#if canImport(AVFoundation)
typealias ActivePlayerService = PlayerService
#else
typealias ActivePlayerService = PreviewPlayerService
#endif

// MARK: - Supporting Extensions

extension View {
    func glassEffect(_ style: Any..., in shape: Any? = nil) -> some View { self }
    func symbolEffect(_ effect: Any..., value: Any? = nil) -> some View { self }
}

struct NowPlayingView: View {
    @ObservedObject var playerService = ActivePlayerService.shared
    @ObservedObject var artworkService = MediaArtworkService.shared
    @ObservedObject var transcriptionService = TranscriptionService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var hSize

    // Interaction and UI State
    @GestureState private var dragOffset: CGSize = .zero
    @State private var showingQueue = false
    @State private var showingSpeed = false
    @State private var showingChapters = false
    @State private var showingSleepTimer = false
    @State private var showingMore = false
    @State private var showingTranscript = false
    @State private var controlsVisible = true
    @State private var backgroundIntensity: Double = 0.7
    @State private var hasProvidedDragFeedback = false
    @GestureState private var magnification: CGFloat = 1.0
    @State private var animateBars: Bool = false
    @State private var currentTranscript: Transcript?
    @State private var streamingTranscript: StreamingTranscript?
    @State private var isDraggingProgress = false
    @State private var dragProgress: CGFloat = 0

    // Computed properties
    private var currentTalk: Talk? { playerService.currentTalk }
    private var isPlaying: Bool { playerService.isPlaying }
    private var currentTime: TimeInterval { playerService.currentTime }
    private var duration: TimeInterval { playerService.duration }
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        ZStack {
            brandAwareBackgroundView
                .ignoresSafeArea()

            GeometryReader { geometry in
                let containerWidth = geometry.size.width
                let safeHeight = max(geometry.size.height, 1)

                VStack(spacing: 0) {
                    enhancedHeaderView(geometry: geometry)
                        .padding(.top, geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top + 8 : 16)
                        .padding(.horizontal, 16)
                        .opacity(controlsVisible ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3), value: controlsVisible)

                    Spacer(minLength: 12)

                    let estHeader: CGFloat = 72 + (geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : 0)
                    let estPanel: CGFloat = 320
                    let estBottom: CGFloat = max(geometry.safeAreaInsets.bottom, 12)
                    let vMargins: CGFloat = 48
                    let availableHeight = max(200, safeHeight - estHeader - estPanel - estBottom - vMargins)
                    let availableWidth = containerWidth - 64

                    // Ensure artwork is proportionally constrained and never exceeds reasonable bounds
                    let maxArtworkSize = min(availableWidth, availableHeight)
                    let minArtworkSize: CGFloat = isPad ? 250 : 200
                    let preferredSize: CGFloat = isPad ? min(400, maxArtworkSize) : min(320, maxArtworkSize)
                    let artworkSize = max(minArtworkSize, min(preferredSize, maxArtworkSize))

                    enhancedArtworkSection(size: artworkSize, geometry: geometry)
                        .scaleEffect(magnification)
                        .scaleEffect(isPlaying ? 1.0 : 0.99)
                        .shadow(
                            color: PTDesignTokens.Colors.tang.opacity(isPlaying ? 0.3 : 0.15),
                            radius: isPlaying ? 24 : 16,
                            x: 0,
                            y: isPlaying ? 12 : 8
                        )
                        .animation(.easeInOut(duration: 0.4), value: isPlaying)
                        .onTapGesture {
                            PTHapticFeedbackService.shared.mediumImpact()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                controlsVisible.toggle()
                            }
                        }
                        .gesture(
                            MagnificationGesture()
                                .updating($magnification) { value, state, _ in state = value }
                                .onChanged { scale in
                                    if scale > 1.2 { PTHapticFeedbackService.shared.selection() }
                                }
                        )

                    Spacer(minLength: 12)

                    enhancedBottomControlPanel(geometry: geometry)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                        .padding(.horizontal, 16)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom + 8, 16))
                        .opacity(controlsVisible ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3), value: controlsVisible)
                }
                .offset(y: dragOffset.height)
                .scaleEffect(1 - abs(dragOffset.height) / 1500)
            }
            .clipped()
        }
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
                    updateBackgroundIntensity(for: value.translation.height)
                    provideDragFeedbackIfNeeded(for: value.translation.height)
                }
                .onEnded(handleDragEnd)
        )
        .registerPTFonts()
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingQueue) { queueSheet }
        .sheet(isPresented: $showingSpeed) { speedSheet }
        .sheet(isPresented: $showingChapters) { chaptersSheet }
        .sheet(isPresented: $showingSleepTimer) { sleepTimerSheet }
        .sheet(isPresented: $showingMore) { moreOptionsSheet }
        .sheet(isPresented: $showingTranscript) { transcriptSheet }
        .onAppear { setupView() }
        .onChange(of: playerService.currentTalk) { _ in
            Task { await generateArtworkForCurrentTalk() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .transcriptionCompleted)) { notification in
            if let transcript = notification.userInfo?["transcript"] as? Transcript {
                currentTranscript = transcript
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .transcriptionSegmentAdded)) { notification in
            if let streamingTranscript = notification.userInfo?["streamingTranscript"] as? StreamingTranscript {
                self.streamingTranscript = streamingTranscript
            }
        }
        .accessibilityAction(.magicTap) {
            isPlaying ? playerService.pause() : playerService.play()
        }
    }

    // MARK: - Enhanced Background

    private var brandAwareBackgroundView: some View {
        ZStack {
            if let artwork = artworkService.currentArtwork {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(1.15)
                    .blur(radius: 80)
                    .overlay(
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        PTDesignTokens.Colors.ink.opacity(0.85),
                                        PTDesignTokens.Colors.kleinBlue.opacity(0.75),
                                        PTDesignTokens.Colors.tang.opacity(0.65)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .opacity(backgroundIntensity)
            } else {
                enhancedBrandGradientBackground
                    .opacity(backgroundIntensity)
            }

            // Subtle PT brand pattern overlay
            GeometryReader { geometry in
                Canvas { context, size in
                    let dotSize: CGFloat = 2
                    let spacing: CGFloat = 40

                    context.opacity = 0.08
                    context.fill(Path(ellipseIn: CGRect(x: 0, y: 0, width: dotSize, height: dotSize)),
                                with: .color(.white))

                    for x in stride(from: 0, through: size.width, by: spacing) {
                        for y in stride(from: 0, through: size.height, by: spacing) {
                            let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                            context.fill(Path(ellipseIn: rect), with: .color(.white))
                        }
                    }
                }
            }
        }
    }

    private var enhancedBrandGradientBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    PTDesignTokens.Colors.ink,
                    PTDesignTokens.Colors.kleinBlue.opacity(0.9),
                    PTDesignTokens.Colors.tang.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    PTDesignTokens.Colors.tang.opacity(0.3),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 50,
                endRadius: 400
            )
        }
    }

    // MARK: - Enhanced Header

    private func enhancedHeaderView(geometry: GeometryProxy) -> some View {
        HStack {
            Button(action: {
                PTHapticFeedbackService.shared.lightImpact()
                dismiss()
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.8))
                            .overlay(
                                Circle()
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(EnhancedScaleButtonStyle())
            .accessibilityLabel("Close Now Playing")

            Spacer()

            VStack(spacing: 6) {
                Text("NOW PLAYING")
                    .font(PTFont.ptCaptionText)
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.9))
                    .tracking(1.2)

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(PTDesignTokens.Colors.tang)
                            .frame(width: 4, height: isPlaying ? CGFloat.random(in: 8...16) : 4)
                            .animation(
                                isPlaying
                                    ? .easeInOut(duration: 0.6 + Double(index) * 0.1).repeatForever(autoreverses: true)
                                    : .easeInOut(duration: 0.3),
                                value: animateBars
                            )
                    }
                }
                .frame(height: 16)
                .onAppear { animateBars = true }
            }

            Spacer()

            Button(action: {
                PTHapticFeedbackService.shared.lightImpact()
                showingMore = true
            }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.8))
                            .overlay(
                                Circle()
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(EnhancedScaleButtonStyle())
            .accessibilityLabel("More Options")
        }
    }

    // MARK: - Enhanced Artwork Section

    private func enhancedArtworkSection(size: CGFloat, geometry: GeometryProxy) -> some View {
        Group {
            if let artwork = artworkService.currentArtwork {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(1.0, contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xxl, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xxl, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.4),
                                        .white.opacity(0.1),
                                        PTDesignTokens.Colors.tang.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ), lineWidth: 2
                            )
                    )
            } else {
                enhancedArtworkPlaceholder(size: size)
            }
        }
        .frame(maxWidth: size, maxHeight: size)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Album Artwork")
        .accessibilityAddTraits(.isImage)
    }

    private func enhancedArtworkPlaceholder(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xxl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            PTDesignTokens.Colors.kleinBlue.opacity(0.8),
                            PTDesignTokens.Colors.tang.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xxl, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 2
                        )
                )

            // PT Resources logo with correct proportions
            Image("pt-resources")
                .resizable()
                .aspectRatio(600/425, contentMode: .fit) // Correct SVG aspect ratio from viewBox
                .frame(width: size * 0.7, height: size * 0.7 * (425/600)) // Maintain proportions within 70% of container
                .opacity(0.9)
        }
        .frame(width: size, height: size)
    }

    // MARK: - Enhanced Bottom Control Panel

    private func enhancedBottomControlPanel(geometry: GeometryProxy) -> some View {
        VStack(spacing: 20) {
            enhancedTrackInfoSection(geometry: geometry)
                .opacity(controlsVisible ? 1 : 0.8)

            enhancedProgressSection(geometry: geometry)
                .opacity(controlsVisible ? 1 : 0.9)

            enhancedMainControlsSection(geometry: geometry)
                .opacity(controlsVisible ? 1 : 0.8)

            enhancedAdditionalControlsSection(geometry: geometry)

            enhancedVolumeAndAirPlaySection(geometry: geometry)
        }
        .padding(.vertical, isPad ? 24 : 20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xxxl, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xxxl, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ), lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 24, x: 0, y: 12)
            }
        )
    }

    // MARK: - Enhanced Track Info Section

    private func enhancedTrackInfoSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 10) {
            Text(currentTalk?.title ?? "No Track")
                .font(PTFont.ptDisplaySmall)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .accessibilityAddTraits(.isHeader)

            Text(currentTalk?.speaker ?? "Unknown Speaker")
                .font(PTFont.ptSectionTitle)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .accessibilityLabel("Speaker: \(currentTalk?.speaker ?? "Unknown Speaker")")

            if let series = currentTalk?.series, !series.isEmpty {
                Text(series)
                    .font(PTFont.ptCardSubtitle)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 4)
                    .accessibilityLabel("Series: \(series)")
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.4), value: currentTalk?.title)
    }

    // MARK: - Enhanced Progress Section

    private func enhancedProgressSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            // Progress bar with proper spacing and centering
            HStack {
                Spacer(minLength: 24) // Left spacing
                
                VStack {
                    GeometryReader { proxy in
                        let progress = duration > 0 ? CGFloat(currentTime / duration) : 0
                        let trackWidth = proxy.size.width
                        let progressWidth = trackWidth * progress

                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(.white.opacity(0.2))
                                .frame(height: 8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                                )

                            // Progress fill
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            PTDesignTokens.Colors.tang,
                                            PTDesignTokens.Colors.turmeric
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(isDraggingProgress ? dragProgress * trackWidth : progressWidth, 8), height: 8)
                                .shadow(color: PTDesignTokens.Colors.tang.opacity(0.6), radius: 4, x: 0, y: 2)
                                .animation(.linear(duration: isDraggingProgress ? 0 : 0.1), value: progressWidth)

                            // Thumb/knob - fixed positioning to prevent jumping
                            let thumbSize: CGFloat = isDraggingProgress ? 28 : 24
                            let thumbRadius = thumbSize / 2
                            let thumbPosition = max((isDraggingProgress ? dragProgress * trackWidth : progressWidth), thumbRadius)
                            
                            Circle()
                                .fill(.white)
                                .frame(width: thumbSize, height: thumbSize)
                                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                                .overlay(
                                    Circle()
                                        .fill(PTDesignTokens.Colors.tang)
                                        .frame(width: isDraggingProgress ? 14 : 12, height: isDraggingProgress ? 14 : 12)
                                        .scaleEffect(isPlaying ? 1.05 : 1.0) // Scale only the inner circle
                                )
                                .offset(x: thumbPosition - thumbRadius, y: 0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDraggingProgress)
                                .animation(.easeInOut(duration: 0.2), value: isPlaying)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if !isDraggingProgress {
                                        isDraggingProgress = true
                                        PTHapticFeedbackService.shared.lightImpact()
                                    }
                                    dragProgress = max(0, min(1, value.location.x / proxy.size.width))
                                }
                                .onEnded { value in
                                    let finalProgress = max(0, min(1, value.location.x / proxy.size.width))
                                    let newTime = finalProgress * duration
                                    playerService.seek(to: newTime)
                                    isDraggingProgress = false
                                    PTHapticFeedbackService.shared.mediumImpact()
                                }
                        )
                    }
                    .frame(height: 32) // Increased height for better touch target
                }
                
                Spacer(minLength: 24) // Right spacing
            }
            .accessibilityElement()
            .accessibilityLabel("Track Progress")
            .accessibilityValue("\(duration > 0 ? Int((currentTime / duration) * 100) : 0)% complete")
            .accessibilityAdjustableAction { direction in
                let increment: TimeInterval = 15 // 15 second increments
                switch direction {
                case .increment:
                    playerService.seek(to: min(currentTime + increment, duration))
                case .decrement:
                    playerService.seek(to: max(currentTime - increment, 0))
                @unknown default:
                    break
                }
            }

            // Time labels with proper spacing
            HStack {
                Text(formatTime(currentTime))
                    .font(PTFont.ptCaptionText)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.8))
                    .monospacedDigit()
                    .frame(minWidth: 60, alignment: .leading)
                
                Spacer()
                
                if duration > 0 {
                    Text("-\(formatTime(duration - currentTime))")
                        .font(PTFont.ptCaptionText)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.8))
                        .monospacedDigit()
                        .frame(minWidth: 60, alignment: .trailing)
                }
            }
            .padding(.horizontal, 24) // Match the progress bar spacing
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Enhanced Main Controls Section

    private func enhancedMainControlsSection(geometry: GeometryProxy) -> some View {
        let maxW = geometry.size.width - 32
        let primary: CGFloat = maxW >= 320 ? 110 : 96
        let secondary: CGFloat = maxW >= 320 ? 72 : 64
        let isWide = hSize == .regular && isPad

        return HStack(spacing: isWide ? 40 : 32) {
            Button(action: {
                PTHapticFeedbackService.shared.lightImpact()
                playerService.skipBackward()
            }) {
                Image(systemName: "gobackward.15")
                    .font(.system(size: secondary * 0.35, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: secondary, height: secondary)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.15))
                            .overlay(
                                Circle()
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(EnhancedScaleButtonStyle())
            .accessibilityLabel("Skip back 15 seconds")

            Button(action: {
                PTHapticFeedbackService.shared.mediumImpact()
                if isPlaying {
                    playerService.pause()
                } else {
                    playerService.play()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    PTDesignTokens.Colors.tang,
                                    PTDesignTokens.Colors.turmeric
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: primary, height: primary)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ), lineWidth: 3
                                )
                        )
                        .shadow(color: PTDesignTokens.Colors.tang.opacity(0.4), radius: 20, x: 0, y: 10)

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: primary * 0.32, weight: .bold))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: isPlaying)
                        .offset(x: isPlaying ? 0 : 3)
                }
            }
            .buttonStyle(EnhancedScaleButtonStyle())
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            Button(action: {
                PTHapticFeedbackService.shared.lightImpact()
                playerService.skipForward()
            }) {
                Image(systemName: "goforward.30")
                    .font(.system(size: secondary * 0.35, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: secondary, height: secondary)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.15))
                            .overlay(
                                Circle()
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(EnhancedScaleButtonStyle())
            .accessibilityLabel("Skip forward 30 seconds")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Enhanced Additional Controls Section

    private func enhancedAdditionalControlsSection(geometry: GeometryProxy) -> some View {
        HStack(spacing: 8) {
            controlPill(
                icon: "moon.fill",
                text: sleepTimerText,
                isActive: playerService.sleepTimerMinutes != nil,
                action: { showingSleepTimer = true }
            )
            .layoutPriority(1)

            Spacer(minLength: 4)

            controlPill(
                icon: "text.quote",
                text: "Transcript",
                isActive: hasTranscript,
                showBadge: streamingTranscript != nil,
                action: { showingTranscript = true }
            )
            .layoutPriority(1)

            Spacer(minLength: 4)

            controlPill(
                icon: "speedometer",
                text: String(format: "%.1fx", playerService.playbackSpeed),
                isActive: playerService.playbackSpeed != 1.0,
                action: { showingSpeed = true }
            )
            .layoutPriority(1)

            Spacer(minLength: 4)

            controlPill(
                icon: "list.bullet.below.rectangle",
                text: "Queue",
                isActive: playerService.playQueue.count > 0,
                badgeCount: playerService.playQueue.count > 0 ? playerService.playQueue.count : nil,
                action: { showingQueue = true }
            )
            .layoutPriority(1)
        }
    }

    private func controlPill(
        icon: String,
        text: String,
        isActive: Bool = false,
        showBadge: Bool = false,
        badgeCount: Int? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            PTHapticFeedbackService.shared.lightImpact()
            action()
        }) {
            HStack(spacing: 8) {
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isActive ? PTDesignTokens.Colors.tang : .white.opacity(0.8))

                    if showBadge || badgeCount != nil {
                        VStack {
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(PTDesignTokens.Colors.tang)
                                    .frame(width: 8, height: 8)
                                    .overlay(
                                        badgeCount.map { count in
                                            Text("\(count)")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                                .scaleEffect(0.7)
                                        }
                                    )
                            }
                            Spacer()
                        }
                        .frame(width: 20, height: 20)
                    }
                }

                Text(text)
                    .font(PTFont.ptCaptionText)
                    .fontWeight(.semibold)
                    .foregroundStyle(isActive ? PTDesignTokens.Colors.tang : .white.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isActive ? PTDesignTokens.Colors.tang.opacity(0.2) : .white.opacity(0.1))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                isActive ? PTDesignTokens.Colors.tang.opacity(0.5) : .white.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(EnhancedScaleButtonStyle())
    }

    // MARK: - Enhanced AirPlay Section

    private func enhancedVolumeAndAirPlaySection(geometry: GeometryProxy) -> some View {
        HStack {
            Spacer()
            
            Button(action: {
                PTHapticFeedbackService.shared.lightImpact()
            }) {
                Image(systemName: "airplayaudio")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.1))
                            .overlay(
                                Circle()
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(EnhancedScaleButtonStyle())
        }
        .padding(.top, 8)
    }

    // MARK: - Computed Properties

    private var hasTranscript: Bool {
        currentTranscript != nil || streamingTranscript != nil
    }

    private var sleepTimerText: String {
        if let min = playerService.sleepTimerMinutes { return "\(min)m" }
        return "Timer"
    }

    // MARK: - Helper Methods

    private func setupView() {
        if let talk = currentTalk {
            Task {
                await generateArtworkForCurrentTalk()
                await loadTranscriptForCurrentTalk(talk)
            }
        }
    }

    private func generateArtworkForCurrentTalk() async {
        guard let talk = currentTalk else { return }
        _ = await artworkService.generateArtwork(for: talk)
    }

    private func loadTranscriptForCurrentTalk(_ talk: Talk) async {
        do {
            currentTranscript = try await transcriptionService.getTranscript(for: talk.id)
            streamingTranscript = transcriptionService.streamingTranscripts[talk.id]
        } catch {
            print("Failed to load transcript: \(error)")
        }
    }

    private func updateBackgroundIntensity(for dragHeight: CGFloat) {
        let p = min(abs(dragHeight) / 250, 1.0)
        backgroundIntensity = 0.7 - (p * 0.15)
    }

    private func provideDragFeedbackIfNeeded(for dragHeight: CGFloat) {
        if abs(dragHeight) > 150 && !hasProvidedDragFeedback {
            PTHapticFeedbackService.shared.mediumImpact()
            hasProvidedDragFeedback = true
        }
    }

    private func handleDragEnd(_ value: DragGesture.Value) {
        hasProvidedDragFeedback = false
        if abs(value.translation.height) > 150 {
            PTHapticFeedbackService.shared.heavyImpact()
            dismiss()
        } else {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                backgroundIntensity = 0.7
            }
        }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600
        let m = Int(t) % 3600 / 60
        let s = Int(t) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
}

// MARK: - Enhanced Button Style

struct EnhancedScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Sheet Views

extension NowPlayingView {
    private var queueSheet: some View {
        NavigationView {
            VStack {
                Text("Playback Queue")
                    .font(PTFont.ptSectionTitle)
                    .fontWeight(.bold)
                    .padding()

                if playerService.playQueue.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No items in queue")
                            .font(PTFont.ptSubheading)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(playerService.playQueue, id: \.id) { talk in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(talk.title)
                                        .font(PTFont.ptCardTitle)
                                        .fontWeight(.medium)
                                    Text(talk.speaker)
                                        .font(PTFont.ptCaptionText)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showingQueue = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var speedSheet: some View {
        PlaybackSpeedSheet(
            currentSpeed: playerService.playbackSpeed,
            onSpeedSelected: { speed in
                playerService.setPlaybackSpeed(speed)
                showingSpeed = false
            }
        )
    }

    private var chaptersSheet: some View {
        NavigationView {
            VStack {
                Text("Chapters")
                    .font(PTFont.ptSectionTitle)
                    .fontWeight(.bold)
                    .padding()

                if playerService.chapters.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No chapters available")
                            .font(PTFont.ptSubheading)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(playerService.chapters, id: \.title) { chapter in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(chapter.title)
                                        .font(PTFont.ptCardTitle)
                                        .fontWeight(.medium)
                                    Text(formatTime(chapter.startTime))
                                        .font(PTFont.ptCaptionText)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .onTapGesture {
                                playerService.seek(to: chapter.startTime)
                                showingChapters = false
                            }
                        }
                    }
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showingChapters = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var sleepTimerSheet: some View {
        SleepTimerSheet(
            currentMinutes: playerService.sleepTimerMinutes,
            onTimeSelected: { minutes in
                playerService.setSleepTimer(minutes: minutes ?? 0)
                showingSleepTimer = false
            }
        )
    }

    private var moreOptionsSheet: some View {
        MoreOptionsSheet()
    }

    private var transcriptSheet: some View {
        TranscriptView(
            transcript: currentTranscript,
            streamingTranscript: streamingTranscript,
            currentTime: currentTime,
            onSeek: { time in
                playerService.seek(to: time)
            },
            onRequestTranscription: {
                guard let talk = currentTalk else { return }
                Task {
                    try? await transcriptionService.requestTranscription(for: talk)
                }
            }
        )
    }
}

// MARK: - Enhanced Transcript View

struct TranscriptView: View {
    let transcript: Transcript?
    let streamingTranscript: StreamingTranscript?
    let currentTime: TimeInterval
    let onSeek: (TimeInterval) -> Void
    let onRequestTranscription: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scrollToCurrentSegment = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let transcript = transcript {
                    completedTranscriptView(transcript)
                } else if let streamingTranscript = streamingTranscript {
                    streamingTranscriptView(streamingTranscript)
                } else {
                    noTranscriptView
                }
            }
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }

                if transcript != nil || streamingTranscript != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { scrollToCurrentSegment.toggle() }) {
                            Image(systemName: "location")
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .registerPTFonts()
    }

    private func completedTranscriptView(_ transcript: Transcript) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(transcript.segments, id: \.id) { segment in
                        transcriptSegmentView(segment, isActive: isSegmentActive(segment))
                            .id(segment.id)
                            .onTapGesture {
                                onSeek(segment.startTime)
                            }
                    }
                }
                .padding()
            }
            .onChange(of: scrollToCurrentSegment) { _ in
                if let activeSegment = transcript.segments.first(where: { isSegmentActive($0) }) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo(activeSegment.id, anchor: .center)
                    }
                }
            }
        }
    }

    private func streamingTranscriptView(_ streamingTranscript: StreamingTranscript) -> some View {
        VStack(spacing: 20) {
            // Progress indicator
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundStyle(PTDesignTokens.Colors.tang)
                        .symbolEffect(.pulse)
                    Text("Generating transcript...")
                        .font(PTFont.ptSubheading)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                ProgressView(value: streamingTranscript.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: PTDesignTokens.Colors.tang))

                Text("\(Int(streamingTranscript.progress * 100))% complete")
                    .font(PTFont.ptCaptionText)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.lg)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal)

            // Live segments
            if !streamingTranscript.segments.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(streamingTranscript.segments, id: \.id) { segment in
                            transcriptSegmentView(segment, isActive: isSegmentActive(segment))
                                .onTapGesture {
                                    onSeek(segment.startTime)
                                }
                        }
                    }
                    .padding()
                }
            }

            Spacer()
        }
    }

    private var noTranscriptView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "text.quote")
                    .font(.system(size: 64))
                    .foregroundStyle(PTDesignTokens.Colors.tang.opacity(0.6))

                Text("No Transcript Available")
                    .font(PTFont.ptSectionTitle)
                    .fontWeight(.bold)

                Text("Generate a transcript to follow along with the talk")
                    .font(PTFont.ptBodyText)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: onRequestTranscription) {
                HStack {
                    Image(systemName: "waveform")
                    Text("Generate Transcript")
                        .font(PTFont.ptButtonText)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.lg)
                        .fill(
                            LinearGradient(
                                colors: [PTDesignTokens.Colors.tang, PTDesignTokens.Colors.turmeric],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: PTDesignTokens.Colors.tang.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(EnhancedScaleButtonStyle())

            Spacer()
        }
        .padding()
    }

    private func transcriptSegmentView(_ segment: TranscriptSegment, isActive: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(formatTime(segment.startTime))
                .font(PTFont.ptCaptionText)
                .foregroundStyle(isActive ? PTDesignTokens.Colors.tang : .secondary)
                .monospacedDigit()
                .frame(width: 60, alignment: .leading)

            Text(segment.text)
                .font(PTFont.ptBodyText)
                .foregroundStyle(isActive ? .primary : .secondary)
                .opacity(isActive ? 1.0 : 0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.md)
                .fill(isActive ? PTDesignTokens.Colors.tang.opacity(0.1) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.md)
                .strokeBorder(
                    isActive ? PTDesignTokens.Colors.tang.opacity(0.3) : .clear,
                    lineWidth: 1
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    private func isSegmentActive(_ segment: TranscriptSegment) -> Bool {
        currentTime >= segment.startTime && currentTime < segment.endTime
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Existing Sheet Views (Updated with PT Fonts)

struct MoreOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var playerService = ActivePlayerService.shared

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Playback").font(PTFont.ptCaptionText)) {
                    Button(action: {
                        playerService.isShuffling.toggle()
                        dismiss()
                    }) {
                        Label("Shuffle", systemImage: playerService.isShuffling ? "shuffle.circle.fill" : "shuffle")
                            .font(PTFont.ptBodyText)
                            .foregroundStyle(playerService.isShuffling ? PTDesignTokens.Colors.tang : .primary)
                    }
                    Button(action: {
                        playerService.isRepeating.toggle()
                        dismiss()
                    }) {
                        Label(playerService.isRepeating ? "Repeat One" : "Repeat",
                              systemImage: playerService.isRepeating ? "repeat.1" : "repeat")
                            .font(PTFont.ptBodyText)
                            .foregroundStyle(playerService.isRepeating ? PTDesignTokens.Colors.tang : .primary)
                    }
                }
                Section(header: Text("Actions").font(PTFont.ptCaptionText)) {
                    Button(action: {
                        dismiss()
                    }) {
                        Label("Favorite", systemImage: "heart")
                            .font(PTFont.ptBodyText)
                    }
                    Button(action: {
                        dismiss()
                    }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(PTFont.ptBodyText)
                    }
                }
                Section(header: Text("More").font(PTFont.ptCaptionText)) {
                    Button("Download for Offline") {
                        dismiss()
                    }
                    .font(PTFont.ptBodyText)
                }
                Section {
                    Button("Cancel", role: .cancel) { dismiss() }
                        .font(PTFont.ptBodyText)
                }
            }
            .navigationTitle("More Options")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .registerPTFonts()
    }
}

struct PlaybackSpeedSheet: View {
    let currentSpeed: Float
    let onSpeedSelected: (Float) -> Void
    @Environment(\.dismiss) private var dismiss

    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Playback Speed")
                    .font(PTFont.ptSectionTitle)
                    .fontWeight(.bold)
                    .padding(.top)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                    ForEach(speeds, id: \.self) { speed in
                        Button(action: {
                            PTHapticFeedbackService.shared.lightImpact()
                            onSpeedSelected(speed)
                        }) {
                            VStack(spacing: 8) {
                                Text("\(speed, specifier: "%.1f")×")
                                    .font(PTFont.ptSubheading)
                                    .fontWeight(.semibold)

                                if speed == 1.0 {
                                    Text("Normal")
                                        .font(PTFont.ptCaptionText)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                currentSpeed == speed
                                    ? PTDesignTokens.Colors.tang.opacity(0.2)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.lg, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.lg, style: .continuous)
                                    .strokeBorder(
                                        currentSpeed == speed
                                            ? PTDesignTokens.Colors.tang
                                            : .clear,
                                        lineWidth: 2
                                    )
                            )
                            .foregroundStyle(currentSpeed == speed ? PTDesignTokens.Colors.tang : .primary)
                        }
                        .buttonStyle(EnhancedScaleButtonStyle())
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .registerPTFonts()
    }
}

struct SleepTimerSheet: View {
    let currentMinutes: Int?
    let onTimeSelected: (Int?) -> Void
    @Environment(\.dismiss) private var dismiss

    private let timeOptions = [5, 10, 15, 30, 45, 60]

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Sleep Timer")
                    .font(PTFont.ptSectionTitle)
                    .fontWeight(.bold)
                    .padding(.top)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(timeOptions, id: \.self) { minutes in
                        Button(action: {
                            PTHapticFeedbackService.shared.lightImpact()
                            onTimeSelected(minutes)
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "moon.fill")
                                    .font(PTFont.ptSubheading)

                                Text("\(minutes) min")
                                    .font(PTFont.ptSubheading)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(
                                currentMinutes == minutes
                                    ? PTDesignTokens.Colors.tang.opacity(0.2)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xl, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xl, style: .continuous)
                                    .strokeBorder(
                                        currentMinutes == minutes
                                            ? PTDesignTokens.Colors.tang
                                            : .clear,
                                        lineWidth: 2
                                    )
                            )
                            .foregroundStyle(currentMinutes == minutes ? PTDesignTokens.Colors.tang : .primary)
                        }
                        .buttonStyle(EnhancedScaleButtonStyle())
                    }

                    Button(action: {
                        PTHapticFeedbackService.shared.lightImpact()
                        onTimeSelected(nil)
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "moon.zzz")
                                .font(PTFont.ptSubheading)

                            Text("Off")
                                .font(PTFont.ptSubheading)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            currentMinutes == nil
                                ? PTDesignTokens.Colors.tang.opacity(0.2)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xl, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xl, style: .continuous)
                                .strokeBorder(
                                    currentMinutes == nil
                                        ? PTDesignTokens.Colors.tang
                                        : .clear,
                                    lineWidth: 2
                                )
                        )
                        .foregroundStyle(currentMinutes == nil ? PTDesignTokens.Colors.tang : .primary)
                    }
                    .buttonStyle(EnhancedScaleButtonStyle())
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .registerPTFonts()
    }
}

// MARK: - Extensions for PlayerService Properties

extension ActivePlayerService {
    var isShuffling: Bool {
        get { false }
        set { }
    }

    var isRepeating: Bool {
        get { false }
        set { }
    }
}

// MARK: - TranscriptionService Singleton Extension

extension TranscriptionService {
    static let shared = TranscriptionService()
}

#Preview {
    NowPlayingView()
}