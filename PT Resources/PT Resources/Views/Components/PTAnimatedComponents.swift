//
//  PTAnimatedComponents.swift
//  PT Resources
//
//  Modern SwiftUI animated components for showcase media experience
//

import SwiftUI

// MARK: - Animated Media Control Button

struct AnimatedMediaButton: View {
    let icon: String
    let action: () -> Void
    let isActive: Bool
    let size: CGFloat
    let style: MediaButtonStyle
    
    @State private var isPressed = false
    @State private var pulseScale: CGFloat = 1.0
    
    init(
        icon: String,
        isActive: Bool = false,
        size: CGFloat = 50,
        style: MediaButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.isActive = isActive
        self.size = size
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            SimpleHapticService.shared.lightImpact()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                action()
            }
        }) {
            ZStack {
                // Background circle with glassmorphism effect
                Circle()
                    .fill(backgroundGradient)
                    .frame(width: size, height: size)
                    .shadow(color: shadowColor, radius: isPressed ? 2 : 8, x: 0, y: isPressed ? 1 : 4)
                    .overlay(
                        Circle()
                            .stroke(borderGradient, lineWidth: 1)
                    )
                    .scaleEffect(isPressed ? 0.95 : pulseScale)
                
                // Icon with dynamic color
                Image(systemName: icon)
                    .font(.system(size: size * 0.4, weight: .medium, design: .rounded))
                    .foregroundStyle(iconGradient)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .onAppear {
            if style == .pulse {
                startPulseAnimation()
            }
        }
    }
    
    private var backgroundGradient: some ShapeStyle {
        switch style {
        case .primary:
            return AnyShapeStyle(
                LinearGradient(
                    colors: isActive ? [.blue.opacity(0.8), .purple.opacity(0.6)] : [.gray.opacity(0.2), .gray.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .secondary:
            return AnyShapeStyle(.ultraThinMaterial)
        case .pulse:
            return AnyShapeStyle(
                RadialGradient(
                    colors: [.orange.opacity(0.6), .red.opacity(0.4)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size/2
                )
            )
        }
    }
    
    private var borderGradient: some ShapeStyle {
        AnyShapeStyle(
            LinearGradient(
                colors: [.white.opacity(0.3), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    private var iconGradient: some ShapeStyle {
        switch style {
        case .primary:
            return AnyShapeStyle(isActive ? .white : .primary)
        case .secondary:
            return AnyShapeStyle(.primary)
        case .pulse:
            return AnyShapeStyle(.white)
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .primary:
            return isActive ? .blue.opacity(0.3) : .black.opacity(0.1)
        case .secondary:
            return .black.opacity(0.1)
        case .pulse:
            return .orange.opacity(0.4)
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
    }
}

enum MediaButtonStyle {
    case primary
    case secondary
    case pulse
}

// MARK: - Animated Progress Bar

struct AnimatedProgressBar: View {
    let progress: Double
    let duration: Double
    let isBuffering: Bool
    
    @State private var animatedProgress: Double = 0
    @State private var bufferShimmer: Double = 0
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background track
            RoundedRectangle(cornerRadius: 4)
                .fill(.ultraThinMaterial)
                .frame(height: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                )
            
            // Buffering shimmer effect
            if isBuffering {
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.3), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 8)
                    .offset(x: bufferShimmer)
                    .clipped()
            }
            
            // Progress fill with gradient
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * animatedProgress, height: 8)
                    .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 0)
            }
            .frame(height: 8)
        }
        .onChange(of: progress) { _, newProgress in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animatedProgress = newProgress
            }
        }
        .onAppear {
            animatedProgress = progress
            if isBuffering {
                startBufferAnimation()
            }
        }
    }
    
    private func startBufferAnimation() {
        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            bufferShimmer = 200
        }
    }
}

// MARK: - Floating Media Widget

struct FloatingMediaWidget: View {
    let isPlaying: Bool
    let title: String
    let artist: String
    let artwork: UIImage?
    let onTap: () -> Void
    let onPlayPause: () -> Void
    
    @State private var isVisible = false
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork with shimmer effect
            Group {
                if let artwork = artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.6), .purple.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.title3)
                        )
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            
            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Play/Pause button
            AnimatedMediaButton(
                icon: isPlaying ? "pause.fill" : "play.fill",
                isActive: isPlaying,
                size: 40,
                style: .secondary,
                action: onPlayPause
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        )
        .offset(dragOffset)
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    withAnimation(.spring()) {
                        dragOffset = .zero
                    }
                    
                    // If dragged significantly, could dismiss
                    if abs(value.translation.height) > 100 {
                        withAnimation(.spring()) {
                            isVisible = false
                        }
                    }
                }
        )
        .onTapGesture {
            SimpleHapticService.shared.mediumImpact()
            onTap()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Waveform Visualizer

struct WaveformVisualizer: View {
    let isPlaying: Bool
    let amplitude: Double
    
    @State private var waveformData: [Double] = Array(repeating: 0.1, count: 50)
    @State private var animationPhase: Double = 0
    
    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<waveformData.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: max(4, waveformData[index] * 60))
                    .animation(
                        .easeInOut(duration: 0.1)
                        .delay(Double(index) * 0.02),
                        value: waveformData[index]
                    )
            }
        }
        .frame(height: 60)
        .onAppear {
            if isPlaying {
                startWaveformAnimation()
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                startWaveformAnimation()
            } else {
                stopWaveformAnimation()
            }
        }
    }
    
    private func startWaveformAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if isPlaying {
                updateWaveform()
            }
        }
    }
    
    private func stopWaveformAnimation() {
        withAnimation(.easeOut(duration: 0.5)) {
            waveformData = Array(repeating: 0.1, count: waveformData.count)
        }
    }
    
    private func updateWaveform() {
        for i in 0..<waveformData.count {
            let phase = animationPhase + Double(i) * 0.2
            let baseAmplitude = amplitude * 0.7
            let variation = sin(phase) * 0.3
            waveformData[i] = max(0.1, baseAmplitude + variation + Double.random(in: -0.1...0.1))
        }
        animationPhase += 0.3
    }
}

// MARK: - Media Transition Overlay

struct MediaTransitionOverlay: View {
    let isTransitioning: Bool
    let progress: Double
    let fromType: String
    let toType: String
    
    var body: some View {
        ZStack {
            if isTransitioning {
                // Background blur
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Animated transition icon
                    ZStack {
                        Circle()
                            .fill(.ultraThickMaterial)
                            .frame(width: 100, height: 100)
                            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                        
                        // Rotating arrows
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .rotationEffect(.degrees(progress * 360))
                            .scaleEffect(1 + sin(progress * .pi * 4) * 0.1)
                    }
                    
                    // Transition text
                    VStack(spacing: 8) {
                        Text("Switching Media")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            Text(fromType)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: Capsule())
                                .opacity(1 - progress)
                            
                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                            
                            Text(toType)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.blue.opacity(0.2), in: Capsule())
                                .opacity(progress)
                        }
                    }
                    
                    // Progress bar
                    VStack(spacing: 8) {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .frame(width: 200)
                            .scaleEffect(y: 2)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isTransitioning)
    }
}

// MARK: - Preview Providers

#Preview("Animated Media Button") {
    VStack(spacing: 20) {
        AnimatedMediaButton(icon: "play.fill", isActive: true, style: .primary) {}
        AnimatedMediaButton(icon: "pause.fill", style: .secondary) {}
        AnimatedMediaButton(icon: "heart.fill", style: .pulse) {}
    }
    .padding()
}

#Preview("Progress Bar") {
    VStack(spacing: 20) {
        AnimatedProgressBar(progress: 0.3, duration: 180, isBuffering: false)
        AnimatedProgressBar(progress: 0.7, duration: 240, isBuffering: true)
    }
    .padding()
}

#Preview("Floating Widget") {
    FloatingMediaWidget(
        isPlaying: true,
        title: "The Gospel According to Mark",
        artist: "John Stott",
        artwork: nil,
        onTap: {},
        onPlayPause: {}
    )
    .padding()
}