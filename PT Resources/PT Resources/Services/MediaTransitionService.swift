//
//  MediaTransitionService.swift
//  PT Resources
//
//  Service for seamless transitions between video and audio playback
//

import Foundation
import AVFoundation
import UIKit
import SwiftUI

@MainActor
final class MediaTransitionService: ObservableObject {
    
    // MARK: - Singleton Instance
    
    static let shared = MediaTransitionService()
    
    // MARK: - Published Properties
    
    @Published var isTransitioning = false
    @Published var transitionProgress: Double = 0.0
    @Published var currentMediaType: MediaType = .audio
    
    // MARK: - Private Properties
    
    private var transitionAnimator: UIViewPropertyAnimator?
    private var currentResource: ResourceDetail?
    private var savedPlaybackTime: TimeInterval = 0
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Transition from video to audio playback with saved position
    func transitionFromVideoToAudio(resource: ResourceDetail, currentTime: TimeInterval) async {
        guard !isTransitioning else { return }
        
        PTLogger.general.info("Starting video to audio transition")
        
        isTransitioning = true
        transitionProgress = 0.0
        currentResource = resource
        savedPlaybackTime = currentTime
        
        // Generate transition haptic feedback
        PTHapticFeedbackService.shared.videoTransition()
        
        // Configure audio session for media playback
        PTEnhancedAudioSessionService.shared.configureForMediaPlayback()
        
        await performTransitionAnimation()
        
        // Load audio into player service
        PlayerService.shared.loadResource(resource, startTime: savedPlaybackTime)
        
        // Start audio playback
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay for smooth transition
        PlayerService.shared.play()
        
        currentMediaType = .audio
        isTransitioning = false
        transitionProgress = 1.0
        
        PTLogger.general.info("Video to audio transition completed")
    }
    
    /// Transition from audio to video playback with saved position
    func transitionFromAudioToVideo(resource: ResourceDetail, currentTime: TimeInterval) async {
        guard !isTransitioning else { return }
        guard resource.videoURL != nil else {
            PTLogger.general.error("No video URL available for transition")
            return
        }
        
        PTLogger.general.info("Starting audio to video transition")
        
        isTransitioning = true
        transitionProgress = 0.0
        currentResource = resource
        savedPlaybackTime = currentTime
        
        // Pause audio playback
        PlayerService.shared.pause()
        
        // Generate transition haptic feedback
        PTHapticFeedbackService.shared.videoTransition()
        
        // Configure audio session for video playback
        PTEnhancedAudioSessionService.shared.configureForVideoPlayback()
        
        await performTransitionAnimation()
        
        // Present video player
        VideoPlayerManager.shared.presentVideoPlayer(for: resource)
        
        currentMediaType = .video
        isTransitioning = false
        transitionProgress = 1.0
        
        PTLogger.general.info("Audio to video transition completed")
    }
    
    /// Create a smooth transition between media player views
    func createMediaPlayerTransition<Content: View>(
        from fromView: Content,
        to toView: Content,
        duration: TimeInterval = 0.8
    ) -> AnyView {
        
        return AnyView(
            ZStack {
                fromView
                    .opacity(isTransitioning ? 1.0 - transitionProgress : 1.0)
                    .scaleEffect(isTransitioning ? 0.95 : 1.0)
                    .blur(radius: isTransitioning ? transitionProgress * 5 : 0)
                
                toView
                    .opacity(isTransitioning ? transitionProgress : 0.0)
                    .scaleEffect(isTransitioning ? 0.95 + (transitionProgress * 0.05) : 0.95)
                    .blur(radius: isTransitioning ? (1.0 - transitionProgress) * 5 : 0)
            }
            .animation(.easeInOut(duration: duration), value: transitionProgress)
        )
    }
    
    /// Get transition indicator for UI
    func getTransitionIndicator() -> some View {
        Group {
            if isTransitioning {
                VStack(spacing: 12) {
                    // Animated transition icon
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 60, height: 60)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: currentMediaType == .audio ? "play.rectangle" : "waveform")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .rotationEffect(.degrees(transitionProgress * 180))
                            .scaleEffect(0.8 + (sin(transitionProgress * .pi * 4) * 0.1))
                    }
                    
                    Text("Switching to \(currentMediaType == .audio ? "Video" : "Audio")")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    // Progress indicator
                    ProgressView(value: transitionProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .frame(width: 80)
                        .scaleEffect(y: 2)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                )
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func performTransitionAnimation() async {
        return await withCheckedContinuation { continuation in
            transitionAnimator = UIViewPropertyAnimator(duration: 0.8, dampingRatio: 0.8) { [weak self] in
                self?.transitionProgress = 1.0
            }
            
            transitionAnimator?.addCompletion { _ in
                continuation.resume()
            }
            
            transitionAnimator?.startAnimation()
        }
    }
    
    /// Create beautiful transition effects for media switching
    private func createTransitionEffect() -> some View {
        ZStack {
            // Ripple effect
            ForEach(0..<3, id: \.self) { [self] index in
                Circle()
                    .stroke(lineWidth: 2)
                    .foregroundColor(.blue.opacity(0.3))
                    .frame(width: 100 + CGFloat(index * 40))
                    .scaleEffect(self.isTransitioning ? 1.5 : 0.8)
                    .opacity(self.isTransitioning ? 0.0 : 0.8)
                    .animation(
                        .easeInOut(duration: 1.2)
                        .delay(Double(index) * 0.2)
                        .repeatForever(autoreverses: false),
                        value: self.isTransitioning
                    )
            }
            
            // Center icon
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title)
                .foregroundColor(.blue)
                .rotationEffect(.degrees(transitionProgress * 360))
                .scaleEffect(1.0 + (sin(transitionProgress * .pi * 2) * 0.2))
        }
    }
}

// MARK: - Transition Animation Modifiers

struct MediaTransitionModifier: ViewModifier {
    let isActive: Bool
    let progress: Double
    let type: MediaTransitionType
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? 0.95 + (progress * 0.05) : 1.0)
            .opacity(isActive ? 0.3 + (progress * 0.7) : 1.0)
            .blur(radius: isActive ? (1.0 - progress) * 8 : 0)
            .rotation3DEffect(
                .degrees(isActive ? (1.0 - progress) * 90 : 0),
                axis: type == .videoToAudio ? (x: 1, y: 0, z: 0) : (x: 0, y: 1, z: 0)
            )
            .animation(.easeInOut(duration: 0.8), value: progress)
    }
}

enum MediaTransitionType {
    case videoToAudio
    case audioToVideo
}

extension View {
    func mediaTransition(
        isActive: Bool,
        progress: Double,
        type: MediaTransitionType
    ) -> some View {
        modifier(MediaTransitionModifier(
            isActive: isActive,
            progress: progress,
            type: type
        ))
    }
}

// MARK: - Transition Coordinator

@MainActor
class MediaTransitionCoordinator: ObservableObject {
    @Published var showVideoPlayer = false
    @Published var showAudioPlayer = false
    @Published var isTransitioning = false
    
    private let transitionService = MediaTransitionService.shared
    
    func transitionToVideo(resource: ResourceDetail, currentTime: TimeInterval) {
        isTransitioning = true
        
        Task {
            await transitionService.transitionFromAudioToVideo(
                resource: resource,
                currentTime: currentTime
            )
            
            showVideoPlayer = true
            showAudioPlayer = false
            isTransitioning = false
        }
    }
    
    func transitionToAudio(resource: ResourceDetail, currentTime: TimeInterval) {
        isTransitioning = true
        
        Task {
            await transitionService.transitionFromVideoToAudio(
                resource: resource,
                currentTime: currentTime
            )
            
            showAudioPlayer = true
            showVideoPlayer = false
            isTransitioning = false
        }
    }
}
