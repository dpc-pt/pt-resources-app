//
//  TalkRowView.swift
//  PT Resources
//
//  Beautiful talk row with PT branding using enhanced components
//

import SwiftUI

struct TalkRowView: View {
    let talk: Talk
    let isDownloaded: Bool
    let downloadProgress: Float?
    let onTalkTap: () -> Void
    let onPlayTap: () -> Void
    let onDownloadTap: () -> Void

    // Only show download option for talks with downloadable audio content
    private var hasDownloadableAudio: Bool {
        guard let audioURL = talk.audioURL, !audioURL.isEmpty else {
            return false
        }
        // Skip Vimeo URLs and other video-only content
        return !audioURL.contains("vimeo.com")
    }
    
    var body: some View {
        PTEnhancedCard(
            style: .standard,
            size: .medium,
            isInteractive: false,
            onTap: onTalkTap
        ) {
            HStack(spacing: PTDesignTokens.Spacing.md) {
                // Artwork/Thumbnail with enhanced styling
                PTAsyncImage(url: talk.artworkURL.flatMap(URL.init),
                           targetSize: CGSize(width: 72, height: 72)) {
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.image)
                        .fill(PTDesignTokens.Colors.kleinBlue)
                        .overlay(
                            Image("pt-resources")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                                .opacity(0.8)
                        )
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.image))
                .overlay(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.image)
                        .stroke(PTDesignTokens.Colors.border, lineWidth: 0.5)
                )
                .overlay(
                    // Video indicator overlay
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            PTVideoIndicatorBadge(
                                hasVideo: talk.videoURL != nil && !talk.videoURL!.isEmpty,
                                duration: talk.duration > 0 ? TimeInterval(talk.duration) : nil
                            )
                        }
                    }
                    .padding(4)
                )

                // Talk Information
                VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
                    Text(talk.title)
                        .font(PTFont.ptCardTitle)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(talk.speaker)
                        .font(PTFont.ptCardSubtitle)
                        .foregroundColor(PTDesignTokens.Colors.tang)

                    // Series and Scripture Reference
                    VStack(alignment: .leading, spacing: 2) {
                        if let series = talk.series, !series.isEmpty {
                            Text(series)
                                .font(PTFont.ptCaptionText)
                                .foregroundColor(PTDesignTokens.Colors.medium)
                        }

                        if let scripture = talk.scriptureReference, !scripture.isEmpty {
                            Text(scripture)
                                .font(PTFont.ptCaptionText)
                                .foregroundColor(PTDesignTokens.Colors.kleinBlue)
                        } else if let biblePassage = talk.biblePassage, !biblePassage.isEmpty {
                            Text(biblePassage)
                                .font(PTFont.ptCaptionText)
                                .foregroundColor(PTDesignTokens.Colors.kleinBlue)
                        }
                    }

                    // Date and metadata
                    HStack(spacing: PTDesignTokens.Spacing.xs) {
                        if talk.duration > 0 {
                            Text(talk.formattedDuration)
                                .font(PTFont.ptSmallText)
                                .foregroundColor(PTDesignTokens.Colors.medium)

                            Text("•")
                                .font(PTFont.ptSmallText)
                                .foregroundColor(PTDesignTokens.Colors.light)
                        }

                        Text(talk.formattedDate)
                            .font(PTFont.ptSmallText)
                            .foregroundColor(PTDesignTokens.Colors.medium)

                        Spacer()
                    }
                }

                Spacer()

                // Enhanced Action Buttons
                HStack(spacing: PTDesignTokens.Spacing.sm) {
                    // Enhanced Play Button
                    PTEnhancedButton(
                        "",
                        style: .ghost,
                        size: .small,
                        leftIcon: Image(systemName: "play.circle.fill"),
                        action: onPlayTap
                    )
                    .accessibilityPlayButton(isPlaying: false)

                    // Enhanced Download Button
                    if hasDownloadableAudio {
                        PTEnhancedButton(
                            "",
                            style: isDownloaded ? .success : .outline,
                            size: .small,
                            leftIcon: isDownloaded ? Image(systemName: "checkmark.circle.fill") :
                                     (downloadProgress != nil ? nil : Image(systemName: "arrow.down.circle")),
                            action: onDownloadTap
                        )
                        .overlay(
                            // Progress overlay for downloading state
                            Group {
                                if !isDownloaded, let progress = downloadProgress {
                                    ZStack {
                                        Circle()
                                            .stroke(PTDesignTokens.Colors.primary.opacity(0.3), lineWidth: 2)

                                        Circle()
                                            .trim(from: 0, to: CGFloat(progress))
                                            .stroke(PTDesignTokens.Colors.primary, lineWidth: 2)
                                            .rotationEffect(.degrees(-90))

                                        Text("\(Int(progress * 100))%")
                                            .font(PTFont.ptCaptionText)
                                            .foregroundColor(PTDesignTokens.Colors.primary)
                                    }
                                    .frame(width: 28, height: 28)
                                }
                            }
                        )
                        .accessibilityDownloadButton(isDownloaded: isDownloaded, downloadProgress: downloadProgress)
                    }
                }
            }
        }
        .accessibilityTalkRow(talk, isDownloaded: isDownloaded, downloadProgress: downloadProgress)
    }
}

// MARK: - Preview

struct TalkRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            TalkRowView(
                talk: Talk.mockTalks[0],
                isDownloaded: false,
                downloadProgress: nil,
                onTalkTap: {},
                onPlayTap: {},
                onDownloadTap: {}
            )
            
            TalkRowView(
                talk: Talk.mockTalks[1],
                isDownloaded: false,
                downloadProgress: 0.65,
                onTalkTap: {},
                onPlayTap: {},
                onDownloadTap: {}
            )
            
            TalkRowView(
                talk: Talk.mockTalks[2],
                isDownloaded: true,
                downloadProgress: nil,
                onTalkTap: {},
                onPlayTap: {},
                onDownloadTap: {}
            )
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
