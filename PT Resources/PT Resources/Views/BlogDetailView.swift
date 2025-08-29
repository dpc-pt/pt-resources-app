//
//  BlogDetailView.swift
//  PT Resources
//
//  Blog post detail view with clean HTML rendering
//

import SwiftUI

struct BlogDetailView: View {
    let blogPost: BlogPost
    @StateObject private var viewModel: BlogDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(blogPost: BlogPost, apiService: BlogAPIServiceProtocol = BlogAPIService()) {
        self.blogPost = blogPost
        self._viewModel = StateObject(wrappedValue: BlogDetailViewModel(apiService: apiService))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PTDesignTokens.Colors.background.ignoresSafeArea()
                    .ptCornerPattern(position: .topRight, size: .small, hasLogo: false)
                    .ptCornerPattern(position: .bottomLeft, size: .medium, hasLogo: false)

                VStack(spacing: 0) {
                    // Header with featured image
                    if let imageURL = blogPost.image, !imageURL.isEmpty {
                        PTAsyncImage(url: URL(string: imageURL),
                                   targetSize: CGSize(width: UIScreen.main.bounds.width, height: 200)) {
                            PTBrandingService.shared.createBrandedBackground(
                                for: .general,
                                hasLogo: false
                            )
                        }
                        .frame(height: 200)
                        .clipped()
                        .overlay(
                            Rectangle()
                                .fill(Color.black.opacity(0.3))
                        )
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.lg) {
                            // Article header
                            VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.md) {
                                // Category
                                if let category = blogPost.category, !category.isEmpty {
                                    Text(blogPost.categoryDisplayName)
                                        .font(PTFont.ptSmallText)
                                        .foregroundColor(PTDesignTokens.Colors.tang)
                                        .padding(.horizontal, PTDesignTokens.Spacing.sm)
                                        .padding(.vertical, PTDesignTokens.Spacing.xs)
                                        .background(
                                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                                                .fill(PTDesignTokens.Colors.tang.opacity(0.1))
                                        )
                                }

                                // Title
                                Text(blogPost.title)
                                    .font(PTFont.ptSectionTitle)
                                    .foregroundColor(PTDesignTokens.Colors.ink)
                                    .lineSpacing(4)

                                // Author and Date
                                HStack(spacing: PTDesignTokens.Spacing.xs) {
                                    Text("By \(blogPost.author)")
                                        .font(PTFont.ptBodyText)
                                        .foregroundColor(PTDesignTokens.Colors.tang)

                                    Text("•")
                                        .font(PTFont.ptBodyText)
                                        .foregroundColor(PTDesignTokens.Colors.light)

                                    Text(blogPost.formattedDate)
                                        .font(PTFont.ptBodyText)
                                        .foregroundColor(PTDesignTokens.Colors.medium)
                                }
                            }
                            .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
                            .padding(.top, PTDesignTokens.Spacing.lg)

                            // Content
                            if viewModel.isLoading {
                                VStack(spacing: PTDesignTokens.Spacing.lg) {
                                    PTLoadingView()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
                            } else if let content = viewModel.fullBlogPost?.content {
                                BlogContentView(content: content)
                                    .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
                            } else if let error = viewModel.error {
                                VStack(spacing: PTDesignTokens.Spacing.md) {
                                    Text("Unable to load content")
                                        .font(PTFont.ptSectionTitle)
                                        .foregroundColor(PTDesignTokens.Colors.ink)

                                    Text(error.localizedDescription)
                                        .font(PTFont.ptBodyText)
                                        .foregroundColor(PTDesignTokens.Colors.medium)
                                        .multilineTextAlignment(.center)

                                    Button("Try Again") {
                                        Task {
                                            await viewModel.loadFullBlogPost(id: blogPost.id)
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, PTDesignTokens.Spacing.lg)
                                    .padding(.vertical, PTDesignTokens.Spacing.sm)
                                    .background(PTDesignTokens.Colors.tang)
                                    .clipShape(RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
                            } else {
                                // Show excerpt if full content not available
                                VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.md) {
                                    if let excerpt = blogPost.excerpt, !excerpt.isEmpty {
                                        Text(excerpt)
                                            .font(PTFont.ptBodyText)
                                            .foregroundColor(PTDesignTokens.Colors.medium)
                                            .lineSpacing(6)

                                        Button(action: {
                                            if let url = URL(string: blogPost.url) {
                                                UIApplication.shared.open(url)
                                            }
                                        }) {
                                            HStack {
                                                Text("Read Full Article")
                                                Image(systemName: "arrow.up.right")
                                                    .font(.caption)
                                            }
                                            .font(PTFont.ptButtonText)
                                            .foregroundColor(PTDesignTokens.Colors.tang)
                                        }
                                    }
                                }
                                .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
                            }

                            // Share button
                            VStack(spacing: PTDesignTokens.Spacing.md) {
                                Divider()
                                    .background(PTDesignTokens.Colors.light)

                                if let url = URL(string: blogPost.url) {
                                    ShareLink(item: url) {
                                        HStack {
                                            Image(systemName: "square.and.arrow.up")
                                            Text("Share Article")
                                        }
                                        .font(PTFont.ptButtonText)
                                        .foregroundColor(PTDesignTokens.Colors.tang)
                                        .padding(.vertical, PTDesignTokens.Spacing.sm)
                                    }
                                }
                            }
                            .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
                            .padding(.top, PTDesignTokens.Spacing.xl)
                        }
                        .padding(.bottom, PTDesignTokens.Spacing.xl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(PTDesignTokens.Colors.medium)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if let url = URL(string: blogPost.url) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Image(systemName: "safari")
                            .foregroundColor(PTDesignTokens.Colors.tang)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadFullBlogPost(id: blogPost.id)
            }
        }
    }


}

// MARK: - Blog Content View

struct BlogContentView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.md) {
            // Simple HTML content renderer
            // This is a basic implementation - could be enhanced with a proper HTML parser
            let paragraphs = parseHTMLContent(content)

            ForEach(paragraphs.indices, id: \.self) { index in
                if let paragraph = paragraphs[index] {
                    if paragraph.type == .heading {
                        Text(paragraph.text)
                            .font(PTFont.ptSectionTitle)
                            .foregroundColor(PTDesignTokens.Colors.ink)
                    } else if paragraph.type == .quote {
                        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.sm) {
                            Rectangle()
                                .fill(PTDesignTokens.Colors.tang)
                                .frame(width: 4, height: 20)
                            Text(paragraph.text)
                                .font(PTFont.ptBodyText)
                                .foregroundColor(PTDesignTokens.Colors.medium)
                                .italic()
                        }
                        .padding(.leading, PTDesignTokens.Spacing.md)
                    } else {
                        Text(paragraph.text)
                            .font(PTFont.ptBodyText)
                            .foregroundColor(PTDesignTokens.Colors.ink)
                            .lineSpacing(6)
                    }
                }
            }
        }
    }

    private func parseHTMLContent(_ html: String) -> [ContentParagraph?] {
        // Simple HTML parsing - splits content by paragraphs and basic elements
        let cleanHTML = html
            .replacingOccurrences(of: "<p>", with: "\n<p>")
            .replacingOccurrences(of: "</p>", with: "</p>\n")
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")

        let paragraphs = cleanHTML.components(separatedBy: "\n")
            .filter { !$0.isEmpty && !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return paragraphs.map { paragraph in
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.hasPrefix("<h") && trimmed.hasSuffix("</h>") {
                let text = stripHTMLTags(trimmed)
                return ContentParagraph(text: text, type: .heading)
            } else if trimmed.contains("<blockquote>") || trimmed.contains("<em>") || trimmed.contains("<i>") {
                let text = stripHTMLTags(trimmed)
                return ContentParagraph(text: text, type: .quote)
            } else {
                let text = stripHTMLTags(trimmed)
                return ContentParagraph(text: text, type: .paragraph)
            }
        }
    }

    private func stripHTMLTags(_ html: String) -> String {
        let pattern = "<[^>]+>"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: html.count)
        let cleanString = regex?.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: "") ?? html

        // Decode common HTML entities
        return cleanString
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Supporting Types

struct ContentParagraph {
    let text: String
    let type: ContentType
}

enum ContentType {
    case paragraph
    case heading
    case quote
}

// MARK: - View Model

@MainActor
final class BlogDetailViewModel: ObservableObject {
    @Published var fullBlogPost: BlogPost?
    @Published var isLoading = false
    @Published var error: APIError?

    private let apiService: BlogAPIServiceProtocol

    init(apiService: BlogAPIServiceProtocol = BlogAPIService()) {
        self.apiService = apiService
    }

    // MARK: - Private Error Handling

    private func setError(_ error: APIError) {
        self.error = error
    }

    func loadFullBlogPost(id: String) async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            let blogPost = try await apiService.fetchBlogPostDetail(id: id)
            fullBlogPost = blogPost
        } catch let apiError as APIError {
            setError(apiError)
        } catch {
            setError(APIError.networkError(error))
        }

        isLoading = false
    }
}

// MARK: - Preview

struct BlogDetailView_Previews: PreviewProvider {
    static var previews: some View {
        BlogDetailView(blogPost: BlogPost.mockBlogPosts[0])
    }
}
