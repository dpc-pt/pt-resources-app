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
    
    var body: some View {
        Button(action: onTalkTap) {
            HStack(spacing: PTSpacing.md) {
                // Artwork/Thumbnail with PT styling and caching
                PTAsyncImage(url: URL(string: talk.imageURL ?? ""),
                           targetSize: CGSize(width: 72, height: 72)) {
                    RoundedRectangle(cornerRadius: PTCornerRadius.small)
                        .fill(LinearGradient(
                            colors: [Color.ptCoral.opacity(0.1), Color.ptTurquoise.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .overlay(
                            PTLogo(size: 24, showText: false)
                        )
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: PTCornerRadius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: PTCornerRadius.small)
                        .stroke(Color.ptMediumGray.opacity(0.3), lineWidth: 0.5)
                )
                
                // Talk Information
                VStack(alignment: .leading, spacing: PTSpacing.xs) {
                    Text(talk.title)
                        .font(PTFont.cardTitle)
                        .foregroundColor(.ptPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(talk.speaker)
                        .font(PTFont.cardSubtitle)
                        .foregroundColor(.ptCoral)
                    
                    // Series and Scripture Reference
                    VStack(alignment: .leading, spacing: 2) {
                        if let series = talk.series, !series.isEmpty {
                            Text(series)
                                .font(PTFont.captionText)
                                .foregroundColor(.ptDarkGray)
                        }
                        
                        if let scripture = talk.scriptureReference, !scripture.isEmpty {
                            Text(scripture)
                                .font(PTFont.captionText)
                                .foregroundColor(.ptTurquoise)
                        } else if let biblePassage = talk.biblePassage, !biblePassage.isEmpty {
                            Text(biblePassage)
                                .font(PTFont.captionText)
                                .foregroundColor(.ptTurquoise)
                        }
                    }
                    
                    // Date and metadata
                    HStack(spacing: PTSpacing.xs) {
                        if talk.duration > 0 {
                            Text(talk.formattedDuration)
                                .font(PTFont.captionText)
                                .foregroundColor(.ptDarkGray)
                            
                            Text("•")
                                .font(PTFont.captionText)
                                .foregroundColor(.ptMediumGray)
                        }
                        
                        Text(talk.formattedDate)
                            .font(PTFont.captionText)
                            .foregroundColor(.ptDarkGray)
                        
                        Spacer()
                        
                        // Download status indicator
                        if isDownloaded {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption)
                                .foregroundColor(.ptSuccess)
                        }
                    }
                }
                
                Spacer()
                
                // Action Buttons with PT styling
                HStack(spacing: PTSpacing.sm) {
                    // Play Button
                    Button(action: onPlayTap) {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(.ptCoral)
                    }
                    .accessibilityPlayButton(isPlaying: false) // TODO: Pass actual playing state
                    
                    // Download Button
                    Button(action: onDownloadTap) {
                        if let progress = downloadProgress {
                            ZStack {
                                Circle()
                                    .stroke(Color.ptCoral.opacity(0.3), lineWidth: 2)
                                
                                Circle()
                                    .trim(from: 0, to: CGFloat(progress))
                                    .stroke(Color.ptCoral, lineWidth: 2)
                                    .rotationEffect(.degrees(-90))
                                
                                Text("\(Int(progress * 100))%")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.ptCoral)
                            }
                            .frame(width: 28, height: 28)
                        } else if isDownloaded {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.ptSuccess)
                        } else {
                            Image(systemName: "arrow.down.circle")
                                .font(.title3)
                                .foregroundColor(.ptDarkGray)
                        }
                    }
                    .accessibilityDownloadButton(isDownloaded: isDownloaded, downloadProgress: downloadProgress)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .ptCardStyle(isPressed: isPressed)
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
