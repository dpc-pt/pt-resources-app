//
//  PTCardComponents.swift
//  PT Resources
//
//  Card-based UI components for talks, conferences, and other content
//

import SwiftUI

// MARK: - Base Card

struct PTBaseCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let backgroundColor: Color
    let shadowColor: Color
    let shadowRadius: CGFloat
    let shadowOffset: CGSize
    let borderColor: Color?
    let borderWidth: CGFloat
    
    init(
        cornerRadius: CGFloat = PTDesignTokens.BorderRadius.lg,
        backgroundColor: Color = PTDesignTokens.Colors.surface,
        shadowColor: Color = Color.black.opacity(0.08),
        shadowRadius: CGFloat = 8,
        shadowOffset: CGSize = CGSize(width: 0, height: 2),
        borderColor: Color? = nil,
        borderWidth: CGFloat = 1,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.backgroundColor = backgroundColor
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.shadowOffset = shadowOffset
        self.borderColor = borderColor
        self.borderWidth = borderWidth
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                    .shadow(
                        color: shadowColor,
                        radius: shadowRadius,
                        x: shadowOffset.width,
                        y: shadowOffset.height
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        borderColor ?? Color.clear,
                        lineWidth: borderColor != nil ? borderWidth : 0
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Talk Card

struct PTTalkCard: View {
    let talk: Talk
    let showSeries: Bool
    let showDuration: Bool
    let showDownloadStatus: Bool
    let onTap: () -> Void
    let onDownload: (() -> Void)?
    let onFavorite: (() -> Void)?
    
    init(
        talk: Talk,
        showSeries: Bool = true,
        showDuration: Bool = true,
        showDownloadStatus: Bool = true,
        onTap: @escaping () -> Void,
        onDownload: (() -> Void)? = nil,
        onFavorite: (() -> Void)? = nil
    ) {
        self.talk = talk
        self.showSeries = showSeries
        self.showDuration = showDuration
        self.showDownloadStatus = showDownloadStatus
        self.onTap = onTap
        self.onDownload = onDownload
        self.onFavorite = onFavorite
    }
    
    var body: some View {
        PTBaseCard {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: PTDesignTokens.Spacing.md) {
                    TalkArtwork(talk: talk)
                    
                    VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.sm) {
                        TalkHeader(talk: talk, showSeries: showSeries)
                        TalkMetadata(talk: talk, showDuration: showDuration)
                        
                        if showDownloadStatus || onDownload != nil || onFavorite != nil {
                            TalkActions(
                                talk: talk,
                                showDownloadStatus: showDownloadStatus,
                                onDownload: onDownload,
                                onFavorite: onFavorite
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(PTDesignTokens.Spacing.md)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Talk Artwork

private struct TalkArtwork: View {
    let talk: Talk
    
    var body: some View {
        AsyncImage(url: URL(string: talk.artworkURL ?? "")) { image in
            image
                .resizable()
                .aspectRatio(contentMode: ContentMode.fill)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm))
        } placeholder: {
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                .fill(PTDesignTokens.Colors.light.opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "waveform")
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .font(.title3)
                )
        }
    }
}

// MARK: - Talk Header

private struct TalkHeader: View {
    let talk: Talk
    let showSeries: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
            if showSeries, let series = talk.series, !series.isEmpty {
                Text(series)
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(PTDesignTokens.Colors.medium)
                    .lineLimit(1)
            }
            
            Text(talk.title ?? "Untitled")
                .font(PTFont.ptButtonText)
                .foregroundColor(PTDesignTokens.Colors.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
}

// MARK: - Talk Metadata

private struct TalkMetadata: View {
    let talk: Talk
    let showDuration: Bool
    
    var body: some View {
        HStack(spacing: PTDesignTokens.Spacing.sm) {
            if !talk.speaker.isEmpty {
                Text(talk.speaker)
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(PTDesignTokens.Colors.medium)
                    .lineLimit(1)
            }
            
            if showDuration && talk.duration > 0 {
                Text("•")
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(PTDesignTokens.Colors.light)
                
                Text(formatDuration(talk.duration))
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(PTDesignTokens.Colors.medium)
            }
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Talk Actions

private struct TalkActions: View {
    let talk: Talk
    let showDownloadStatus: Bool
    let onDownload: (() -> Void)?
    let onFavorite: (() -> Void)?
    
    var body: some View {
        HStack(spacing: PTDesignTokens.Spacing.sm) {
            if showDownloadStatus {
                // DownloadStatusIndicator removed - isDownloaded not available on Talk model
                Text("Online")
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(PTDesignTokens.Colors.medium)
            }
            
            Spacer()
            
            if let onFavorite = onFavorite {
                Button(action: onFavorite) {
                    Image(systemName: "heart")
                        .font(.caption)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if let onDownload = onDownload {
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.circle")
                        .font(.caption)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Download Status Indicator

private struct DownloadStatusIndicator: View {
    let isDownloaded: Bool
    
    var body: some View {
        HStack(spacing: PTDesignTokens.Spacing.xs) {
            Image(systemName: isDownloaded ? "arrow.down.circle.fill" : "arrow.down.circle")
                .font(.caption)
                .foregroundColor(isDownloaded ? PTDesignTokens.Colors.kleinBlue : PTDesignTokens.Colors.light)
            
            Text(isDownloaded ? "Downloaded" : "Online")
                .font(PTFont.ptCaptionText)
                .foregroundColor(PTDesignTokens.Colors.medium)
        }
    }
}

// MARK: - Favorite Button

private struct FavoriteButton: View {
    let isFavorite: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.caption)
                .foregroundColor(isFavorite ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Download Button

private struct DownloadButton: View {
    let isDownloaded: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Image(systemName: isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                .font(.caption)
                .foregroundColor(isDownloaded ? PTDesignTokens.Colors.kleinBlue : PTDesignTokens.Colors.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Conference Artwork

private struct ConferenceArtwork: View {
    let conference: ConferenceInfo

    var body: some View {
        AsyncImage(url: URL(string: conference.artworkURL ?? "")) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm))
        } placeholder: {
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                .fill(PTDesignTokens.Colors.light.opacity(0.3))
                .frame(width: 80, height: 60)
                .overlay(
                    Image(systemName: "building.columns")
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .font(.title3)
                )
        }
    }
}

// MARK: - Conference Card

struct PTConferenceCard: View {
    let conference: ConferenceInfo
    let isLatest: Bool
    let onTap: () -> Void

    var body: some View {
        PTBaseCard {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: PTDesignTokens.Spacing.md) {
                    // Conference image if available
                    if let artworkURL = conference.artworkURL, !artworkURL.isEmpty {
                        ConferenceArtwork(conference: conference)
                    }

                    VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.md) {
                        ConferenceHeader(conference: conference, isLatest: isLatest)
                        ConferenceDetails(conference: conference)
                        ConferenceMetadata(conference: conference)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(PTDesignTokens.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Conference Header

private struct ConferenceHeader: View {
    let conference: ConferenceInfo
    let isLatest: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
                if isLatest {
                    Text("Latest Conference")
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.tang)
                        .textCase(.uppercase)
                }
                
                Text(conference.title.isEmpty ? "Conference" : conference.title)
                    .font(PTFont.ptSubheading)
                    .foregroundColor(PTDesignTokens.Colors.ink)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if isLatest {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(PTDesignTokens.Colors.tang)
            }
        }
    }
}

// MARK: - Conference Details

private struct ConferenceDetails: View {
    let conference: ConferenceInfo
    
    var body: some View {
        if let description = conference.description, !description.isEmpty {
            Text(description)
                .font(PTFont.ptBodyText)
                .foregroundColor(PTDesignTokens.Colors.medium)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
    }
}

// MARK: - Conference Metadata

private struct ConferenceMetadata: View {
    let conference: ConferenceInfo
    
    var body: some View {
        HStack(spacing: PTDesignTokens.Spacing.sm) {
            // Location removed - property not available on ConferenceInfo model
            
            // Start date not available - use year instead
                HStack(spacing: PTDesignTokens.Spacing.xs) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                    
                    Text(conference.year)
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .lineLimit(1)
                }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Blog Card

struct PTBlogCard: View {
    let blogPost: BlogPost
    let onTap: () -> Void
    
    var body: some View {
        PTBaseCard {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.md) {
                    BlogHeader(blogPost: blogPost)
                    BlogExcerpt(blogPost: blogPost)
                    BlogMetadata(blogPost: blogPost)
                }
                .padding(PTDesignTokens.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Blog Header

private struct BlogHeader: View {
    let blogPost: BlogPost
    
    var body: some View {
        Text(blogPost.title)
            .font(PTFont.ptSubheading)
            .foregroundColor(PTDesignTokens.Colors.ink)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }
}

// MARK: - Blog Excerpt

private struct BlogExcerpt: View {
    let blogPost: BlogPost
    
    var body: some View {
        if let excerpt = blogPost.excerpt, !excerpt.isEmpty {
            Text(excerpt)
                .font(PTFont.ptBodyText)
                .foregroundColor(PTDesignTokens.Colors.medium)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
    }
}

// MARK: - Blog Metadata

private struct BlogMetadata: View {
    let blogPost: BlogPost
    
    var body: some View {
        HStack(spacing: PTDesignTokens.Spacing.sm) {
            if !blogPost.author.isEmpty {
                Text(blogPost.author)
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(PTDesignTokens.Colors.medium)
            }
            
            if let publishedDate = blogPost.publishedDate {
                Text("•")
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(PTDesignTokens.Colors.light)
                
                Text(formatDate(publishedDate))
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(PTDesignTokens.Colors.medium)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}