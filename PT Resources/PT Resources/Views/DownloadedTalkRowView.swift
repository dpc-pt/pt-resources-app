//
//  DownloadedTalkRowView.swift
//  PT Resources
//
//  Row view for downloaded talks in offline mode
//

import SwiftUI

struct DownloadedTalkRowView: View {
    let downloadedTalk: DownloadedTalk
    let onPlayTap: () -> Void
    let onDeleteTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: PTDesignTokens.Spacing.md) {
            // Artwork/Thumbnail with PT styling
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.image)
                .fill(LinearGradient(
                    colors: [PTDesignTokens.Colors.tang.opacity(0.1), PTDesignTokens.Colors.kleinBlue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay(
                    PTLogo(size: 24, showText: false)
                )
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.image))
                .overlay(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.image)
                        .stroke(PTDesignTokens.Colors.light.opacity(0.2), lineWidth: 0.5)
                )
            
            // Talk Information
            VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
                Text(downloadedTalk.title)
                    .font(PTFont.ptCardTitle)
                    .foregroundColor(PTDesignTokens.Colors.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(downloadedTalk.speaker)
                    .font(PTFont.ptCardSubtitle)
                    .foregroundColor(PTDesignTokens.Colors.tang)
                
                // Series and metadata
                VStack(alignment: .leading, spacing: 2) {
                    if let series = downloadedTalk.series, !series.isEmpty {
                        Text(series)
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                    }
                    
                    // File size and duration
                    HStack(spacing: PTDesignTokens.Spacing.xs) {
                        Text(downloadedTalk.formattedDuration)
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                        
                        Text("•")
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.light)
                        
                        Text(downloadedTalk.formattedFileSize)
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                        
                        Spacer()
                        
                        // Enhanced Downloaded badge with quality indicator
                        HStack(spacing: 4) {
                            // Audio quality badge
                            HStack(spacing: 2) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(PTDesignTokens.Colors.tang)
                                
                                Text("MP3")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundColor(PTDesignTokens.Colors.tang)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(PTDesignTokens.Colors.tang.opacity(0.15))
                            )
                            
                            // Offline ready indicator
                            ZStack {
                                Circle()
                                    .fill(PTDesignTokens.Colors.success.opacity(0.2))
                                    .frame(width: 16, height: 16)
                                
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(PTDesignTokens.Colors.success)
                            }
                            
                            Text("Ready")
                                .font(PTFont.ptCaptionText)
                                .foregroundColor(PTDesignTokens.Colors.success)
                        }
                    }
                    
                    // Additional metadata row
                    HStack(spacing: PTDesignTokens.Spacing.xs) {
                        Text("Downloaded \(formatRelativeTime(downloadedTalk.createdAt))")
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                        
                        Text("•")
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.light)
                        
                        Text("Last played \(downloadedTalk.formattedLastAccessed)")
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                    }
                }
            }
            
            Spacer()
            
            // Play Button
            Button(action: onPlayTap) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(PTDesignTokens.Colors.tang)
            }
            .accessibilityPlayButton(isPlaying: false)
        }
        .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
        .padding(.vertical, PTDesignTokens.Spacing.md)
        .background(PTDesignTokens.Colors.surface)
        .overlay(
            Rectangle()
                .fill(PTDesignTokens.Colors.light.opacity(0.1))
                .frame(height: 0.5)
                .offset(y: 0)
            , alignment: .bottom
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .accessibilityDownloadedTalkRow(downloadedTalk)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    // MARK: - Helper Methods
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

struct DownloadedTalkRowView_Previews: PreviewProvider {
    static var previews: some View {
        DownloadedTalkRowView(
            downloadedTalk: DownloadedTalk(
                id: "1",
                title: "The Grace of God in Salvation",
                speaker: "John Piper",
                series: "Romans Series",
                duration: 3240, // 54 minutes
                fileSize: 25_000_000, // 25 MB
                localAudioURL: "/path/to/audio.mp3",
                lastAccessedAt: Date().addingTimeInterval(-3600), // 1 hour ago
                createdAt: Date().addingTimeInterval(-86400) // 1 day ago
            ),
            onPlayTap: {},
            onDeleteTap: {}
        )
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
