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
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: PTDesignTokens.Spacing.md) {
                // Artwork/Thumbnail with PT styling and caching using priority order
                PTAsyncImage(url: downloadedTalk.artworkURL.flatMap(URL.init),
                           targetSize: CGSize(width: 72, height: 72)) {
                    ZStack {
                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.image)
                            .fill(LinearGradient(
                                colors: [PTDesignTokens.Colors.tang.opacity(0.1), PTDesignTokens.Colors.kleinBlue.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))

                        PTLogo(size: 24, showText: false)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.image))
                }
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

                        // Duration and simple download indicator
                        HStack(spacing: PTDesignTokens.Spacing.xs) {
                            Text(downloadedTalk.formattedDuration)
                                .font(PTFont.ptCaptionText)
                                .foregroundColor(PTDesignTokens.Colors.medium)

                            Spacer()

                            // Simple download indicator
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(PTDesignTokens.Colors.success)
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
                .buttonStyle(.plain)
                .accessibilityPlayButton(isPlaying: false)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
        .padding(.vertical, PTDesignTokens.Spacing.md)
        .background(PTDesignTokens.Colors.surface)
        .overlay(
            Rectangle()
                .fill(PTDesignTokens.Colors.light.opacity(0.1))
                .frame(height: 0.5)
                .offset(y: 0),
            alignment: .bottom
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
                createdAt: Date().addingTimeInterval(-86400), // 1 day ago
                imageURL: "/images/brand/logos/pt-resources.svg",
                conferenceImageURL: nil,
                defaultImageURL: nil
            ),
            onPlayTap: {},
            onDeleteTap: {},
            onTap: {}
        )
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
