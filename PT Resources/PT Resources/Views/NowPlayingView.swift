//
//  NowPlayingView.swift
//  PT Resources
//
//  Stunning now playing screen with immersive experience and PT branding
//

import SwiftUI
import MediaPlayer
import AVKit

struct NowPlayingView: View {
    @ObservedObject var playerService = PlayerService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Animation and interaction state
    @State private var dragOffset: CGSize = .zero
    @State private var isArtworkRotating = false
    @State private var showingQueue = false
    @State private var showingSpeed = false
    @State private var showingChapters = false
    @State private var showingSleepTimer = false
    @State private var controlsVisible = true
    @State private var artworkScale: CGFloat = 1.0
    @State private var backgroundIntensity: Double = 0.7
    
    // Gesture state
    @GestureState private var magnification: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Immersive background
                backgroundView
                    .ignoresSafeArea()
                
                // Main content
                VStack(spacing: 0) {
                    // Header
                    headerView
                        .padding(.top, max(geometry.safeAreaInsets.top, 20))
                        .opacity(controlsVisible ? 1 : 0)
                    
                    Spacer(minLength: 20)
                    
                    // Artwork section - takes center stage
                    artworkSection
                        .frame(maxHeight: min(geometry.size.width - 80, 320))
                        .scaleEffect(artworkScale * magnification)
                    
                    Spacer(minLength: 30)
                    
                    // Track information and controls
                    VStack(spacing: 32) {
                        // Track info
                        trackInfoSection
                            .opacity(controlsVisible ? 1 : 0.7)
                        
                        // Progress section
                        progressSection
                            .opacity(controlsVisible ? 1 : 0.8)
                        
                        // Main playback controls
                        mainControlsSection
                            .opacity(controlsVisible ? 1 : 0.6)
                        
                        // Additional controls
                        additionalControlsSection
                            .opacity(controlsVisible ? 1 : 0.4)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: max(geometry.safeAreaInsets.bottom, 20))
                }
                .offset(y: dragOffset.height)
                .scaleEffect(1 - abs(dragOffset.height) / 1000)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupView()
        }
        .gesture(
            DragGesture()
                .onChanged(handleDrag)
                .onEnded(handleDragEnd)
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        controlsVisible.toggle()
                    }
                }
        )
        .sheet(isPresented: $showingQueue) {
            PlaybackQueueView()
        }
        .sheet(isPresented: $showingSpeed) {
            PlaybackSpeedView(
                currentSpeed: playerService.playbackSpeed,
                onSpeedSelected: { speed in
                    playerService.setPlaybackSpeed(speed)
                }
            )
        }
        .sheet(isPresented: $showingChapters) {
            if !playerService.chapters.isEmpty {
                ChaptersView(
                    chapters: playerService.chapters,
                    currentTime: playerService.currentTime
                )
            }
        }
        .sheet(isPresented: $showingSleepTimer) {
            SleepTimerView()
        }
    }
    
    // MARK: - Background View
    
    private var backgroundView: some View {
        ZStack {
            // Dynamic background based on artwork or brand colors
            if let imageURL = playerService.currentTalk?.imageURL,
               let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(1.2) // Subtle zoom for depth
                        .blur(radius: 50)
                        .opacity(backgroundIntensity)
                } placeholder: {
                    brandGradientBackground
                }
            } else {
                brandGradientBackground
            }
            
            // Overlay for readability
            Rectangle()
                .fill(
                    colorScheme == .dark 
                    ? Color.black.opacity(0.4)
                    : Color.white.opacity(0.2)
                )
        }
    }
    
    private var brandGradientBackground: some View {
        LinearGradient(
            colors: [
                PTDesignTokens.Colors.kleinBlue.opacity(0.8),
                PTDesignTokens.Colors.tang.opacity(0.6),
                PTDesignTokens.Colors.ink.opacity(0.9)
            ],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
        .overlay(
            // Subtle pattern overlay
            PTPatternView()
                .opacity(0.1)
        )
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            // Dismiss button
            Button(action: {
                HapticFeedbackService.shared.lightImpact()
                dismiss()
            }) {
                Image(systemName: "chevron.down")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            // Now Playing indicator
            VStack(spacing: 4) {
                Text("NOW PLAYING")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .tracking(1.0)
                
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(PTDesignTokens.Colors.tang)
                            .frame(width: 3, height: playerService.isPlaying ? 12 : 4)
                            .animation(
                                .easeInOut(duration: 0.5 + Double(index) * 0.1)
                                .repeatForever(autoreverses: true),
                                value: playerService.isPlaying
                            )
                    }
                }
                .frame(height: 12)
            }
            
            Spacer()
            
            // More options
            Button(action: {
                HapticFeedbackService.shared.lightImpact()
                // TODO: Show more options
            }) {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Artwork Section
    
    private var artworkSection: some View {
        ZStack {
            // Drop shadow
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xl)
                .fill(.black.opacity(0.3))
                .frame(width: 280, height: 280)
                .offset(x: 0, y: 12)
                .blur(radius: 24)
            
            // Main artwork container
            Group {
                if let imageURL = playerService.currentTalk?.imageURL,
                   let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        artworkPlaceholder
                    }
                } else {
                    artworkPlaceholder
                }
            }
            .frame(width: 280, height: 280)
            .clipShape(RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xl)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .rotationEffect(.degrees(isArtworkRotating ? 1 : 0))
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    isArtworkRotating.toggle()
                }
                HapticFeedbackService.shared.mediumImpact()
            }
            .scaleEffect(playerService.isPlaying ? 1.0 : 0.98)
            .animation(.easeInOut(duration: 0.3), value: playerService.isPlaying)
        }
        .gesture(
            MagnificationGesture()
                .updating($magnification) { currentScale, gestureScale, _ in
                    gestureScale = currentScale
                }
                .onChanged { _ in
                    HapticFeedbackService.shared.selection()
                }
        )
    }
    
    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xl)
            .fill(
                LinearGradient(
                    colors: [
                        PTDesignTokens.Colors.tang.opacity(0.3),
                        PTDesignTokens.Colors.kleinBlue.opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                VStack(spacing: 16) {
                    Image(systemName: "waveform")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.primary.opacity(0.6))
                    
                    Text("PT Resources")
                        .font(PTFont.ptCardTitle)
                        .foregroundColor(.primary.opacity(0.8))
                }
            )
    }
    
    // MARK: - Track Information
    
    private var trackInfoSection: some View {
        VStack(spacing: 12) {
            Text(playerService.currentTalk?.title ?? "No Track")
                .font(PTFont.ptDisplaySmall)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            
            Text(playerService.currentTalk?.speaker ?? "Unknown Speaker")
                .font(PTFont.ptSectionTitle)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if let series = playerService.currentTalk?.series, !series.isEmpty {
                Text(series)
                    .font(PTFont.ptCardSubtitle)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: playerService.currentTalk?.title)
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        VStack(spacing: 16) {
            // Enhanced progress bar
            PTProgressBar(
                value: playerService.duration > 0 ? playerService.currentTime / playerService.duration : 0,
                onChanged: { newValue in
                    let newTime = newValue * playerService.duration
                    playerService.seek(to: newTime)
                }
            )
            
            // Time labels
            HStack {
                Text(formatTime(playerService.currentTime))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                
                Spacer()
                
                if playerService.duration > 0 {
                    Text("-\(formatTime(playerService.duration - playerService.currentTime))")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }
    
    // MARK: - Main Controls
    
    private var mainControlsSection: some View {
        HStack(spacing: 60) {
            // Skip backward
            PTMediaButton(
                icon: "gobackward.15",
                size: 52,
                style: .secondary
            ) {
                playerService.skipBackward()
            }
            
            // Play/Pause - main action
            PTMediaButton(
                icon: playerService.isPlaying ? "pause.fill" : "play.fill",
                size: 88,
                style: .primary(isActive: playerService.isPlaying)
            ) {
                if playerService.isPlaying {
                    playerService.pause()
                } else {
                    playerService.play()
                }
            }
            
            // Skip forward
            PTMediaButton(
                icon: "goforward.30",
                size: 52,
                style: .secondary
            ) {
                playerService.skipForward()
            }
        }
    }
    
    // MARK: - Additional Controls
    
    private var additionalControlsSection: some View {
        HStack(spacing: 0) {
            // Sleep timer
            PTControlPill(
                icon: "moon.fill",
                text: sleepTimerText,
                isActive: playerService.sleepTimerMinutes != nil
            ) {
                showingSleepTimer = true
            }
            
            Spacer()
            
            // Playback speed
            PTControlPill(
                icon: "speedometer",
                text: String(format: "%.1fx", playerService.playbackSpeed)
            ) {
                showingSpeed = true
            }
            
            Spacer()
            
            // Queue
            PTControlPill(
                icon: "list.bullet.below.rectangle",
                text: "Queue",
                badge: playerService.playQueue.count > 0 ? "\(playerService.playQueue.count)" : nil
            ) {
                showingQueue = true
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var sleepTimerText: String {
        if let minutes = playerService.sleepTimerMinutes {
            return "\(minutes)m"
        }
        return "Timer"
    }
    
    // MARK: - Helper Methods
    
    private func setupView() {
        // Start subtle animations
        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
            isArtworkRotating = true
        }
    }
    
    private func handleDrag(_ value: DragGesture.Value) {
        dragOffset = value.translation
        
        // Adjust background intensity based on drag
        let dragProgress = min(abs(value.translation.height) / 200, 1.0)
        backgroundIntensity = 0.7 - (dragProgress * 0.2)
        
        // Provide haptic feedback at certain thresholds
        if abs(dragOffset.height) > 150 && !hasProvidedFeedback {
            HapticFeedbackService.shared.mediumImpact()
            hasProvidedFeedback = true
        }
    }
    
    @State private var hasProvidedFeedback = false
    
    private func handleDragEnd(_ value: DragGesture.Value) {
        hasProvidedFeedback = false
        
        if abs(dragOffset.height) > 150 {
            // Dismiss with heavy haptic
            HapticFeedbackService.shared.heavyImpact()
            dismiss()
        } else {
            // Bounce back
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                dragOffset = .zero
                backgroundIntensity = 0.7
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Custom Components

struct PTProgressBar: View {
    let value: Double
    let onChanged: (Double) -> Void
    
    @State private var isDragging = false
    @State private var tempValue: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(.tertiary.opacity(0.3))
                    .frame(height: 6)
                
                // Progress
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [PTDesignTokens.Colors.tang, PTDesignTokens.Colors.kleinBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: max(0, CGFloat(isDragging ? tempValue : value) * geometry.size.width),
                        height: 6
                    )
                
                // Thumb
                Circle()
                    .fill(.white)
                    .frame(width: isDragging ? 20 : 16, height: isDragging ? 20 : 16)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    .offset(x: CGFloat(isDragging ? tempValue : value) * geometry.size.width - (isDragging ? 10 : 8))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            HapticFeedbackService.shared.selection()
                        }
                        
                        let percent = max(0, min(1, gesture.location.x / geometry.size.width))
                        tempValue = percent
                    }
                    .onEnded { _ in
                        onChanged(tempValue)
                        isDragging = false
                        HapticFeedbackService.shared.lightImpact()
                    }
            )
        }
        .frame(height: 20)
        .animation(.easeOut(duration: 0.1), value: isDragging)
    }
}

struct PTMediaButton: View {
    let icon: String
    let size: CGFloat
    let style: Style
    let action: () -> Void
    
    enum Style {
        case primary(isActive: Bool = false)
        case secondary
    }
    
    var body: some View {
        Button(action: {
            HapticFeedbackService.shared.mediumImpact()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(foregroundColor)
                .frame(width: size, height: size)
                .background {
                    switch style {
                    case .primary:
                        Circle().fill(backgroundColor)
                    case .secondary:
                        Circle().fill(.ultraThinMaterial)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(strokeColor, lineWidth: strokeWidth)
                )
                .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var iconSize: CGFloat {
        size * 0.35
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary(let isActive):
            return isActive ? .white : PTDesignTokens.Colors.tang
        case .secondary:
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary(let isActive):
            return isActive ? PTDesignTokens.Colors.tang : .clear
        case .secondary:
            return .clear // Will use .background(.ultraThinMaterial) in the view
        }
    }
    
    private var strokeColor: Color {
        switch style {
        case .primary:
            return PTDesignTokens.Colors.tang
        case .secondary:
            return .clear
        }
    }
    
    private var strokeWidth: CGFloat {
        switch style {
        case .primary:
            return 2
        case .secondary:
            return 0
        }
    }
    
    private var shadowColor: Color {
        .black.opacity(0.15)
    }
    
    private var shadowRadius: CGFloat {
        size * 0.1
    }
    
    private var shadowY: CGFloat {
        size * 0.05
    }
}

struct PTControlPill: View {
    let icon: String
    let text: String
    let badge: String?
    let isActive: Bool
    let action: () -> Void
    
    init(icon: String, text: String, badge: String? = nil, isActive: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.text = text
        self.badge = badge
        self.isActive = isActive
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticFeedbackService.shared.lightImpact()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(isActive ? PTDesignTokens.Colors.tang : .secondary)
                
                Text(text)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isActive ? PTDesignTokens.Colors.tang : .secondary)
                
                if let badge = badge {
                    Text(badge)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PTDesignTokens.Colors.tang, in: Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(isActive ? PTDesignTokens.Colors.tang.opacity(0.5) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// ScaleButtonStyle is defined in EnhancedMediaPlayerView.swift

struct PTPatternView: View {
    var body: some View {
        Canvas { context, size in
            // Create subtle PT pattern
            let step: CGFloat = 40
            context.opacity = 0.1
            
            for x in stride(from: 0, through: size.width, by: step) {
                for y in stride(from: 0, through: size.height, by: step) {
                    let rect = CGRect(x: x, y: y, width: 2, height: 2)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(.primary))
                }
            }
        }
    }
}

// MARK: - Supporting Views
// PlaybackQueueView, PlaybackSpeedView, and ChaptersView are defined in EnhancedMediaPlayerView.swift

struct SleepTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var playerService = PlayerService.shared
    
    private let timerOptions = [5, 10, 15, 30, 45, 60]
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(timerOptions, id: \.self) { minutes in
                        HStack {
                            Text("\(minutes) minutes")
                                .font(PTFont.ptCardTitle)
                            Spacer()
                            if playerService.sleepTimerMinutes == minutes {
                                Image(systemName: "checkmark")
                                    .foregroundColor(PTDesignTokens.Colors.tang)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            playerService.setSleepTimer(minutes: minutes)
                            dismiss()
                        }
                    }
                }
                
                if playerService.sleepTimerMinutes != nil {
                    Section {
                        Button("Cancel Sleep Timer") {
                            playerService.cancelSleepTimer()
                            dismiss()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

struct NowPlayingView_Previews: PreviewProvider {
    static var previews: some View {
        NowPlayingView()
            .onAppear {
                // Mock data for preview
                let mockTalk = Talk(
                    id: "preview",
                    title: "The Greatest Story Ever Told",
                    description: "A powerful message about hope and redemption",
                    speaker: "John Stott",
                    series: "Keswick Convention 2023",
                    biblePassage: "Romans 8:28-39",
                    dateRecorded: Date(),
                    duration: 2400,
                    audioURL: nil,
                    videoURL: nil,
                    imageURL: nil
                )
                PlayerService.shared.loadTalk(mockTalk)
                PlayerService.shared.play()
            }
    }
}