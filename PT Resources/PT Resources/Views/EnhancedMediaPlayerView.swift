//
//  EnhancedMediaPlayerView.swift
//  PT Resources
//
//  Modern, enhanced media player with beautiful UI, animations, and advanced controls
//

import SwiftUI
import MediaPlayer
import AVKit
import Combine

struct EnhancedMediaPlayerView: View {
    let resource: ResourceDetail
    @ObservedObject var playerService = PlayerService.shared
    @ObservedObject var artworkService = MediaArtworkService.shared
    @ObservedObject var mediaWidgetService = MediaWidgetService.shared
    @ObservedObject var transitionService = MediaTransitionService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // UI State
    @State private var dragOffset: CGFloat = 0
    @State private var isShowingChapters = false
    @State private var isShowingSpeed = false
    @State private var isShowingQueue = false
    @State private var hasGeneratedHaptic = false
    @State private var showingVideoPlayer = false
    
    // Animation states
    @State private var isArtworkScaled = false
    @State private var controlsOpacity: Double = 1.0
    @State private var artworkRotation: Double = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with adaptive blur
                backgroundView
                    .ignoresSafeArea()
                
                // Main content
                VStack(spacing: 0) {
                    // Header
                    headerView
                        .padding(.top, 20)
                    
                    // Artwork section
                    artworkSection
                        .frame(height: geometry.size.height * 0.45)
                    
                    // Controls section
                    VStack(spacing: 24) {
                        // Track info
                        trackInfoSection
                        
                        // Progress section
                        progressSection
                        
                        // Main controls
                        mainControlsSection
                        
                        // Additional controls
                        additionalControlsSection
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                    .opacity(controlsOpacity)
                }
                
                // Media transition overlay
                MediaTransitionOverlay(
                    isTransitioning: transitionService.isTransitioning,
                    progress: transitionService.transitionProgress,
                    fromType: transitionService.currentMediaType == .audio ? "Audio" : "Video",
                    toType: transitionService.currentMediaType == .audio ? "Video" : "Audio"
                )
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupMediaPlayer()
        }
        .onDisappear {
            cleanup()
        }
        .gesture(
            DragGesture()
                .onChanged(handleDrag)
                .onEnded(handleDragEnd)
        )
        .sheet(isPresented: $showingVideoPlayer) {
            if let videoURL = resource.videoURL {
                VideoPlayerSheet(url: videoURL, title: resource.title)
            }
        }
        .offset(y: dragOffset)
        .fullScreenCover(isPresented: $isShowingChapters) {
            ChaptersView(chapters: playerService.chapters, currentTime: playerService.currentTime)
        }
        .sheet(isPresented: $isShowingSpeed) {
            PlaybackSpeedView(currentSpeed: playerService.playbackSpeed) { speed in
                playerService.setPlaybackSpeed(speed)
            }
        }
        .sheet(isPresented: $isShowingQueue) {
            PlaybackQueueView()
        }
    }
    
    // MARK: - Background View
    
    private var backgroundView: some View {
        ZStack {
            // Adaptive background based on artwork
            if let artwork = artworkService.currentArtwork {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(1.2)
                    .blur(radius: 60)
                    .overlay(
                        Rectangle()
                            .fill(colorScheme == .dark ? .black.opacity(0.7) : .white.opacity(0.8))
                    )
            } else {
                // Fallback gradient
                LinearGradient(
                    colors: [
                        PTDesignTokens.Colors.kleinBlue.opacity(0.8),
                        PTDesignTokens.Colors.tang.opacity(0.6),
                        PTDesignTokens.Colors.ink.opacity(0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button(action: { 
                generateHapticFeedback(.light)
                dismiss() 
            }) {
                Image(systemName: "chevron.down")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding()
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("NOW PLAYING")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                
                Text("FROM PT RESOURCES")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .tracking(0.3)
            }
            
            Spacer()
            
            Button(action: { 
                generateHapticFeedback(.light)
                // Show more options
            }) {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding()
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Artwork Section
    
    private var artworkSection: some View {
        VStack {
            Spacer()
            
            ZStack {
                // Shadow
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black.opacity(0.3))
                    .frame(width: 280, height: 280)
                    .offset(x: 0, y: 8)
                    .blur(radius: 20)
                
                // Main artwork
                Group {
                    if let artwork = artworkService.currentArtwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        // Loading state
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                VStack {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                    Text("Loading artwork...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 8)
                                }
                            )
                    }
                }
                .frame(width: 280, height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .scaleEffect(isArtworkScaled ? 0.95 : 1.0)
                .rotationEffect(.degrees(artworkRotation))
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        artworkRotation += 180
                    }
                    generateHapticFeedback(.medium)
                }
                .onLongPressGesture(minimumDuration: 0.1) {
                    // No action needed, just for press effect
                } onPressingChanged: { pressing in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isArtworkScaled = pressing
                    }
                }
                
                // Video indicator overlay
                if resource.videoURL != nil {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                generateHapticFeedback(.medium)
                                showingVideoPlayer = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.caption)
                                    Text("VIDEO")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(.black.opacity(0.7))
                                        .overlay(
                                            Capsule()
                                                .stroke(.white.opacity(0.3), lineWidth: 0.5)
                                        )
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(16)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Track Info Section
    
    private var trackInfoSection: some View {
        VStack(spacing: 8) {
            Text(resource.title)
                .font(PTFont.ptDisplayMedium)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            
            Text(resource.speaker)
                .font(PTFont.ptSectionTitle)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            if !resource.conference.isEmpty {
                Text(resource.conference)
                    .font(PTFont.ptBodyText)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        VStack(spacing: 12) {
            // Enhanced animated progress bar
            AnimatedProgressBar(
                progress: playerService.duration > 0 ? playerService.currentTime / playerService.duration : 0,
                duration: playerService.duration,
                isBuffering: playerService.isBuffering
            )
            .overlay(
                // Invisible slider for interaction
                Slider(
                    value: Binding(
                        get: { playerService.currentTime },
                        set: { playerService.seek(to: $0) }
                    ),
                    in: 0...playerService.duration,
                    onEditingChanged: { editing in
                        if editing {
                            SimpleHapticService.shared.seekingFeedback()
                        }
                    }
                )
                .opacity(0.01) // Nearly invisible but still functional
            )
            
            // Time labels
            HStack {
                Text(formatTime(playerService.currentTime))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                
                Spacer()
                
                Text("-\(formatTime(playerService.duration - playerService.currentTime))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
    }
    
    // MARK: - Main Controls
    
    private var mainControlsSection: some View {
        HStack(spacing: 60) {
            // Previous/Skip Back
            AnimatedMediaButton(
                icon: "gobackward.15",
                size: 50,
                style: .secondary
            ) {
                playerService.skipBackward()
            }
            
            // Play/Pause with enhanced animation
            AnimatedMediaButton(
                icon: playerService.isPlaying ? "pause.fill" : "play.fill",
                isActive: playerService.isPlaying,
                size: 80,
                style: .pulse
            ) {
                if playerService.isPlaying {
                    playerService.pause()
                } else {
                    playerService.play()
                }
            }
            
            // Next/Skip Forward
            AnimatedMediaButton(
                icon: "goforward.30",
                size: 50,
                style: .secondary
            ) {
                playerService.skipForward()
            }
        }
    }
    
    // MARK: - Additional Controls
    
    private var additionalControlsSection: some View {
        HStack(spacing: 0) {
            // Speed control
            Button(action: {
                generateHapticFeedback(.light)
                isShowingSpeed.toggle()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.body)
                    Text("\(playerService.playbackSpeed, specifier: "%.1f")×")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(.tertiary, lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            // Chapters (if available)
            if !playerService.chapters.isEmpty {
                Button(action: {
                    generateHapticFeedback(.light)
                    isShowingChapters.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.body)
                        Text("Chapters")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(.tertiary, lineWidth: 0.5)
                            )
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
            
            Spacer()
            
            // Queue/Up Next
            Button(action: {
                generateHapticFeedback(.light)
                isShowingQueue.toggle()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet.below.rectangle")
                        .font(.body)
                    Text("Queue")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(.tertiary, lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupMediaPlayer() {
        // Load resource into player service if not already loaded
        if playerService.currentTalk?.id != resource.id {
            playerService.loadResource(resource)
        }
        
        // Generate artwork for enhanced experience
        Task {
            await artworkService.generateArtwork(for: resource)
        }
        
        // Start artwork rotation animation
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            artworkRotation = 360
        }
    }
    
    private func cleanup() {
        // Reset animation states
        artworkRotation = 0
        controlsOpacity = 1.0
        isArtworkScaled = false
    }
    
    private func handleDrag(_ value: DragGesture.Value) {
        if value.translation.height > 0 {
            dragOffset = value.translation.height
            
            // Fade controls as user drags down
            let dragProgress = min(value.translation.height / 200, 1.0)
            controlsOpacity = 1.0 - dragProgress * 0.5
        }
    }
    
    private func handleDragEnd(_ value: DragGesture.Value) {
        if dragOffset > 150 {
            generateHapticFeedback(.medium)
            dismiss()
        } else {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                dragOffset = 0
                controlsOpacity = 1.0
            }
        }
    }
    
    private func generateHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Custom Progress Slider

struct ProgressSlider: View {
    @Binding var value: Double
    let maxValue: Double
    let onEditingChanged: (Bool) -> Void
    
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 3)
                    .fill(.tertiary)
                    .frame(height: 6)
                
                // Progress
                RoundedRectangle(cornerRadius: 3)
                    .fill(.primary)
                    .frame(
                        width: max(0, CGFloat((isDragging ? dragValue : value) / maxValue) * geometry.size.width),
                        height: 6
                    )
                
                // Thumb
                Circle()
                    .fill(.white)
                    .frame(width: isDragging ? 20 : 16, height: isDragging ? 20 : 16)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .offset(x: CGFloat((isDragging ? dragValue : value) / maxValue) * geometry.size.width - (isDragging ? 10 : 8))
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    if !isDragging {
                        isDragging = true
                        onEditingChanged(true)
                    }
                    
                    let percent = min(max(0, gesture.location.x / geometry.size.width), 1)
                    dragValue = percent * maxValue
                }
                .onEnded { _ in
                    value = dragValue
                    isDragging = false
                    onEditingChanged(false)
                }
        )
        .animation(.easeOut(duration: 0.1), value: isDragging)
    }
    
    private var geometry: GeometryProxy {
        GeometryReader { proxy in
            Color.clear
        } as! GeometryProxy
    }
}

// MARK: - Custom Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Supporting Views

struct VideoPlayerSheet: View {
    let url: URL
    let title: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if #available(iOS 16.0, *) {
                    VideoPlayer(player: AVPlayer(url: url))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Done") {
                                    dismiss()
                                }
                            }
                        }
                } else {
                    // Fallback for older iOS versions
                    Text("Video playback requires iOS 16 or later")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct ChaptersView: View {
    let chapters: [Chapter]
    let currentTime: TimeInterval
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(chapters) { chapter in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(chapter.title)
                            .font(.headline)
                        Text(chapter.formattedStartTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if currentTime >= chapter.startTime && 
                       (chapter.endTime == nil || currentTime < chapter.endTime!) {
                        Image(systemName: "waveform")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    PlayerService.shared.jumpToChapter(chapter)
                    dismiss()
                }
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PlaybackSpeedView: View {
    let currentSpeed: Float
    let onSpeedSelected: (Float) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    
    var body: some View {
        NavigationView {
            List(speeds, id: \.self) { speed in
                HStack {
                    Text("\(speed, specifier: "%.2g")×")
                        .font(.headline)
                    Spacer()
                    if abs(speed - currentSpeed) < 0.01 {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onSpeedSelected(speed)
                    dismiss()
                }
            }
            .navigationTitle("Playback Speed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PlaybackQueueView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var playerService = PlayerService.shared
    
    var body: some View {
        NavigationView {
            List {
                Section("Up Next") {
                    if playerService.playQueue.isEmpty {
                        Text("No items in queue")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(playerService.playQueue.indices, id: \.self) { index in
                            let talk = playerService.playQueue[index]
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(talk.title)
                                        .font(.headline)
                                        .lineLimit(1)
                                    Text(talk.speaker)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if index == playerService.currentQueueIndex {
                                    Image(systemName: "speaker.wave.2")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .onMove(perform: moveQueueItems)
                        .onDelete(perform: deleteQueueItems)
                    }
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func moveQueueItems(from source: IndexSet, to destination: Int) {
        // Implement queue reordering
    }
    
    private func deleteQueueItems(at offsets: IndexSet) {
        // Implement queue item removal
    }
}

// MARK: - Preview

struct EnhancedMediaPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedMediaPlayerView(
            resource: ResourceDetailResponse.mockData.resource
        )
    }
}