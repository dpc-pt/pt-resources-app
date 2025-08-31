//
//  TalkRowView.swift
//  PT Resources
//
//  Beautiful talk row with PT branding
//

import SwiftUI

struct TalkRowView: View {
    let talk: Talk
    let isDownloaded: Bool
    let downloadProgress: Float?
    let onTalkTap: () -> Void
    let onPlayTap: () -> Void
    let onDownloadTap: () -> Void
    
    @State private var isPressed = false
    
    // Only show download option for talks with downloadable audio content
    private var hasDownloadableAudio: Bool {
        guard let audioURL = talk.audioURL, !audioURL.isEmpty else {
            return false
        }
        // Skip Vimeo URLs and other video-only content
        return !audioURL.contains("vimeo.com")
    }
    
    var body: some View {
        Button(action: onTalkTap) {
            HStack(spacing: PTDesignTokens.Spacing.md) {
                // Artwork/Thumbnail with PT styling and caching using priority order
                PTAsyncImage(url: talk.artworkURL.flatMap(URL.init),
                           targetSize: CGSize(width: 72, height: 72)) {
                    ZStack {
                        PTBrandingService.shared.createBrandedBackground(
                            for: talk.videoURL != nil && !talk.videoURL!.isEmpty ? .video : .audio,
                            hasLogo: true
                        )
                        
                        PTLogo(size: 24, showText: false)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.image))
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
                        .font(PTFont.ptCardTitle)  // Using PT typography
                        .foregroundColor(PTDesignTokens.Colors.ink)  // Using PT Ink for primary text
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(talk.speaker)
                        .font(PTFont.ptCardSubtitle)  // Using PT typography
                        .foregroundColor(PTDesignTokens.Colors.tang)  // Using PT Tang for speaker names
                    
                    // Series and Scripture Reference
                    VStack(alignment: .leading, spacing: 2) {
                        if let series = talk.series, !series.isEmpty {
                            Text(series)
                                .font(PTFont.ptCaptionText)  // Using PT typography
                                .foregroundColor(PTDesignTokens.Colors.medium)  // Using consistent gray
                        }
                        
                        if let scripture = talk.scriptureReference, !scripture.isEmpty {
                            Text(scripture)
                                .font(PTFont.ptCaptionText)  // Using PT typography
                                .foregroundColor(PTDesignTokens.Colors.kleinBlue)  // Using Klein Blue for scripture
                        } else if let biblePassage = talk.biblePassage, !biblePassage.isEmpty {
                            Text(biblePassage)
                                .font(PTFont.ptCaptionText)  // Using PT typography
                                .foregroundColor(PTDesignTokens.Colors.kleinBlue)  // Using Klein Blue for scripture
                        }
                    }
                    
                    // Date and metadata
                    HStack(spacing: PTDesignTokens.Spacing.xs) {
                        if talk.duration > 0 {
                            Text(talk.formattedDuration)
                                .font(PTFont.ptSmallText)  // Using PT typography
                                .foregroundColor(PTDesignTokens.Colors.medium)
                            
                            Text("•")
                                .font(PTFont.ptSmallText)
                                .foregroundColor(PTDesignTokens.Colors.light)
                        }
                        
                        Text(talk.formattedDate)
                            .font(PTFont.ptSmallText)  // Using PT typography
                            .foregroundColor(PTDesignTokens.Colors.medium)
                        
                        Spacer()
                        
                        // Download status indicator
                        if isDownloaded {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(PTFont.ptCaptionText)
                                .foregroundColor(PTDesignTokens.Colors.success)  // Using PT success color
                        }
                    }
                }
                
                Spacer()
                
                // Action Buttons with PT styling
                HStack(spacing: PTDesignTokens.Spacing.sm) {
                    // Play Button
                    Button(action: onPlayTap) {
                        Image(systemName: "play.circle.fill")
                            .font(PTFont.ptSectionTitle)
                            .foregroundColor(PTDesignTokens.Colors.tang)  // Using PT Tang
                    }
                    .accessibilityPlayButton(isPlaying: false) // TODO: Pass actual playing state
                    
                    // Download Button - only show for talks with audio content
                    if hasDownloadableAudio {
                        Button(action: onDownloadTap) {
                            if isDownloaded {
                                // Prioritize showing checkmark when downloaded
                                Image(systemName: "checkmark.circle.fill")
                                    .font(PTFont.ptCardTitle)
                                    .foregroundColor(PTDesignTokens.Colors.success)  // Using PT success color
                            } else if let progress = downloadProgress {
                                // Show progress only if not downloaded
                                ZStack {
                                    Circle()
                                        .stroke(PTDesignTokens.Colors.tang.opacity(0.3), lineWidth: 2)
                                    
                                    Circle()
                                        .trim(from: 0, to: CGFloat(progress))
                                        .stroke(PTDesignTokens.Colors.tang, lineWidth: 2)
                                        .rotationEffect(.degrees(-90))
                                    
                                    Text("\(Int(progress * 100))%")
                                        .font(PTFont.ptCaptionText)
                                        .fontWeight(.medium)
                                        .foregroundColor(PTDesignTokens.Colors.tang)
                                }
                                .frame(width: 28, height: 28)
                            } else {
                                // Default download button
                                Image(systemName: "arrow.down.circle")
                                    .font(PTFont.ptCardTitle)
                                    .foregroundColor(PTDesignTokens.Colors.medium)  // Using consistent gray
                            }
                        }
                        .accessibilityDownloadButton(isDownloaded: isDownloaded, downloadProgress: downloadProgress)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, PTDesignTokens.Spacing.md)
        .padding(.vertical, PTDesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                .fill(PTDesignTokens.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                        .stroke(PTDesignTokens.Colors.light.opacity(0.2), lineWidth: 0.5)
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .accessibilityTalkRow(talk, isDownloaded: isDownloaded, downloadProgress: downloadProgress)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
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
