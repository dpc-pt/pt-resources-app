//
//  BlogRowView.swift
//  PT Resources
//
//  Beautiful blog post row with PT branding
//

import SwiftUI

struct BlogRowView: View {
    let blogPost: BlogPost
    let onBlogPostTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onBlogPostTap) {
            HStack(spacing: PTDesignTokens.Spacing.md) {
                // Featured Image or PT Logo placeholder
                if let imageURL = blogPost.image, !imageURL.isEmpty {
                    PTAsyncImage(url: URL(string: imageURL),
                               targetSize: CGSize(width: 80, height: 80)) {
                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.image)
                            .fill(LinearGradient(
                                colors: [PTDesignTokens.Colors.tang.opacity(0.1), PTDesignTokens.Colors.kleinBlue.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .overlay(
                                PTLogo(size: 24, showText: false)
                            )
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.image))
                    .overlay(
                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.image)
                            .stroke(PTDesignTokens.Colors.border, lineWidth: 0.5)
                    )
                } else {
                    // Fallback logo for posts without images
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.image)
                        .fill(LinearGradient(
                            colors: [PTDesignTokens.Colors.tang.opacity(0.1), PTDesignTokens.Colors.kleinBlue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)
                        .overlay(
                            PTLogo(size: 32, showText: false)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.image)
                                .stroke(PTDesignTokens.Colors.border, lineWidth: 0.5)
                        )
                }

                // Blog Post Information
                VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
                    // Category badge
                    if let category = blogPost.category, !category.isEmpty {
                        Text(blogPost.categoryDisplayName)
                            .font(PTFont.ptSmallText)
                            .foregroundColor(PTDesignTokens.Colors.tang)
                            .padding(.horizontal, PTDesignTokens.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                                    .fill(PTDesignTokens.Colors.tang.opacity(0.1))
                            )
                    }

                    // Title
                    Text(blogPost.title)
                        .font(PTFont.ptCardTitle)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Excerpt
                    Text(blogPost.displayExcerpt)
                        .font(PTFont.ptBodyText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Author and Date
                    HStack(spacing: PTDesignTokens.Spacing.xs) {
                        Text("By \(blogPost.author)")
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.tang)

                        Text("•")
                            .font(PTFont.ptSmallText)
                            .foregroundColor(PTDesignTokens.Colors.light)

                        Text(blogPost.formattedDate)
                            .font(PTFont.ptSmallText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                    }
                }

                Spacer()

                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(PTDesignTokens.Colors.medium)
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
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Preview

struct BlogRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: PTDesignTokens.Spacing.md) {
            BlogRowView(
                blogPost: BlogPost.mockBlogPosts[0],
                onBlogPostTap: {}
            )

            BlogRowView(
                blogPost: BlogPost.mockBlogPosts[1],
                onBlogPostTap: {}
            )

            BlogRowView(
                blogPost: BlogPost.mockBlogPosts[2],
                onBlogPostTap: {}
            )
        }
        .padding()
        .background(PTDesignTokens.Colors.background)
        .previewLayout(.sizeThatFits)
    }
}
