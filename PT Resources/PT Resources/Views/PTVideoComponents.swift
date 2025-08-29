//
//  PTVideoComponents.swift
//  PT Resources
//
//  SwiftUI components for video playback states and UI elements
//

import SwiftUI

// MARK: - Video Loading View

struct PTVideoLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: PTSpacing.md) {
            // Animated loading indicator
            ZStack {
                Circle()
                    .stroke(PTDesignTokens.Colors.light, lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.6)
                    .stroke(PTDesignTokens.Colors.kleinBlue, lineWidth: 4)
                    .frame(width: 60, height: 60)
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 1)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
            
            VStack(spacing: PTSpacing.xs) {
                Text("Loading Video")
                    .font(PTFont.ptCardTitle)
                    .foregroundColor(PTDesignTokens.Colors.ink)
                
                Text("Preparing video for playback...")
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(PTDesignTokens.Colors.medium)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(PTSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.lg)
                .fill(PTDesignTokens.Colors.surface)
                .shadow(color: PTDesignTokens.Colors.ink.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

// MARK: - Video Error Banner

struct PTVideoErrorBanner: View {
    let error: VideoError
    let retryAction: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: PTSpacing.sm) {
            // Main error row
            HStack(spacing: PTSpacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(PTDesignTokens.Colors.warning)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Video Error")
                        .font(PTFont.ptCardTitle)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                    
                    Text(errorSummary)
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .lineLimit(isExpanded ? nil : 2)
                }
                
                Spacer()
                
                Button(action: { 
                    withAnimation(.easeInOut) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                }
            }
            
            // Expanded details and actions
            if isExpanded {
                VStack(alignment: .leading, spacing: PTSpacing.sm) {
                    if let recoverySuggestion = error.recoverySuggestion {
                        Text(recoverySuggestion)
                            .font(PTFont.ptBodyText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    HStack(spacing: PTSpacing.sm) {
                        Button(action: retryAction) {
                            HStack(spacing: PTSpacing.xs) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                                Text("Retry")
                                    .font(PTFont.ptCaptionText)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, PTSpacing.md)
                            .padding(.vertical, PTSpacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                    .fill(PTDesignTokens.Colors.kleinBlue)
                            )
                        }
                        
                        Button(action: {
                            // Dismiss error
                            VideoPlayerManager.shared.videoError = nil
                        }) {
                            Text("Dismiss")
                                .font(PTFont.ptCaptionText)
                                .foregroundColor(PTDesignTokens.Colors.medium)
                                .padding(.horizontal, PTSpacing.md)
                                .padding(.vertical, PTSpacing.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                        .stroke(PTDesignTokens.Colors.medium, lineWidth: 1)
                                )
                        }
                        
                        Spacer()
                    }
                }
                .padding(.top, PTSpacing.xs)
            }
        }
        .padding(PTSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.lg)
                .fill(PTDesignTokens.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.lg)
                        .stroke(PTDesignTokens.Colors.warning.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var errorSummary: String {
        switch error {
        case .networkError:
            return "Network connection issue"
        case .invalidURL:
            return "Invalid video source"
        case .playbackError:
            return "Playback failed"
        case .presentationError:
            return "Display error"
        case .unsupportedFormat:
            return "Unsupported video format"
        }
    }
}

// MARK: - Video Indicator Badge

struct PTVideoIndicatorBadge: View {
    let hasVideo: Bool
    let duration: TimeInterval?
    
    var body: some View {
        if hasVideo {
            HStack(spacing: 4) {
                Image(systemName: "play.rectangle.fill")
                    .font(.caption2)
                
                if let duration = duration, duration > 0 {
                    Text(formatDuration(duration))
                        .font(.caption2)
                        .monospacedDigit()
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.7))
            )
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Video Thumbnail Overlay

struct PTVideoThumbnailOverlay: View {
    let isVideoContent: Bool
    
    var body: some View {
        if isVideoContent {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "play.fill")
                    .font(.title3)
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Preview Provider

struct PTVideoComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            PTVideoLoadingView()
            
            PTVideoErrorBanner(
                error: .networkError("Unable to connect to video server")
            ) {
                print("Retry tapped")
            }
            
            PTVideoIndicatorBadge(hasVideo: true, duration: 1845)
            
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 200, height: 150)
                
                PTVideoThumbnailOverlay(isVideoContent: true)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}