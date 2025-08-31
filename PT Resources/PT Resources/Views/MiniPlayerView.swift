//
//  MiniPlayerView.swift
//  PT Resources
//
//  Beautiful mini player with PT branding
//

import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var playerService = PlayerService.shared
    @State private var showingFullPlayer = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geometry in
                Rectangle()
                    .fill(PTDesignTokens.Colors.light.opacity(0.3))
                    .frame(height: 2)
                    .overlay(
                        HStack {
                            Rectangle()
                                .fill(PTDesignTokens.Colors.tang)
                                .frame(width: geometry.size.width * CGFloat(playerService.duration > 0 ? playerService.currentTime / playerService.duration : 0))
                            Spacer(minLength: 0)
                        }
                    )
            }
            .frame(height: 2)
            
            Button(action: { showingFullPlayer = true }) {
                HStack(spacing: PTDesignTokens.Spacing.md) {
                    // Artwork with PT styling and caching
                    PTAsyncImage(url: URL(string: playerService.currentTalk?.artworkURL ?? ""),
                               targetSize: CGSize(width: 44, height: 44)) {
                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                            .fill(LinearGradient(
                                colors: [PTDesignTokens.Colors.tang.opacity(0.2), PTDesignTokens.Colors.kleinBlue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .overlay(
                                PTStarSymbol(size: 20)
                                    .opacity(0.8)
                            )
                    }
                }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm))
                    
                    // Track Info with PT styling
                    VStack(alignment: .leading, spacing: 2) {
                        Text(playerService.currentTalk?.title ?? "")
                            .font(PTFont.ptCardSubtitle)
                            .foregroundColor(PTDesignTokens.Colors.ink)
                            .lineLimit(1)
                        
                        Text(playerService.currentTalk?.speaker ?? "")
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Controls with PT styling
                    HStack(spacing: PTDesignTokens.Spacing.sm) {
                        // Play/Pause Button
                        Button(action: {
                            if playerService.playbackState.isPlaying {
                                playerService.pause()
                            } else {
                                playerService.play()
                            }
                        }) {
                            Image(systemName: playerService.playbackState.isPlaying ? "pause.fill" : "play.fill")
                                .font(PTFont.ptSectionTitle)
                                .foregroundColor(PTDesignTokens.Colors.tang)
                        }
                        
                        // Close Button
                        Button(action: {
                            playerService.stop()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(PTFont.ptCardTitle)
                                .foregroundColor(PTDesignTokens.Colors.medium)
                        }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityMiniPlayer(
                talkTitle: playerService.currentTalk?.title,
                speaker: playerService.currentTalk?.speaker,
                isPlaying: playerService.playbackState.isPlaying
            )
            .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
            .padding(.vertical, PTDesignTokens.Spacing.md)
            .background(PTDesignTokens.Colors.surface)
        }
        .sheet(isPresented: $showingFullPlayer) {
            FullPlayerView(playerService: playerService)
        }
    }
}

struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(PTDesignTokens.Colors.light.opacity(0.3), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(PTDesignTokens.Colors.kleinBlue, lineWidth: lineWidth)
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Full Player View (Stub)

struct FullPlayerView: View {
    @ObservedObject var playerService = PlayerService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                // TODO: Implement full player interface
                Text("Full Player Coming Soon")
                    .font(PTFont.ptDisplayMedium)
                    .padding()
                
                if let talk = playerService.currentTalk {
                    VStack(spacing: 16) {
                        Text(talk.title)
                            .font(PTFont.ptSectionTitle)
                        Text(talk.speaker)
                            .font(PTFont.ptCardSubtitle)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Button("Previous") {
                                playerService.skipBackward()
                            }
                            
                            Spacer()
                            
                            Button(playerService.playbackState.isPlaying ? "Pause" : "Play") {
                                if playerService.playbackState.isPlaying {
                                    playerService.pause()
                                } else {
                                    playerService.play()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Spacer()
                            
                            Button("Next") {
                                playerService.skipForward()
                            }
                        }
                        .padding()
                        
                        Text("Speed: \(String(format: "%.1fx", playerService.playbackSpeed))")
                        
                        Slider(value: Binding(
                            get: { playerService.playbackSpeed },
                            set: { playerService.setPlaybackSpeed($0) }
                        ), in: 0.5...3.0, step: 0.25)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Now Playing")
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

// MARK: - Preview

struct MiniPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            MiniPlayerView(playerService: {
                let service = PlayerService.shared
                service.loadTalk(Talk.mockTalks[0])
                return service
            }())
        }
    }
}