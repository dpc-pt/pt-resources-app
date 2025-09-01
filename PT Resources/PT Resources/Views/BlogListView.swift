//
//  BlogListView.swift
//  PT Resources
//
//  Main blog list view with search and filtering
//

import SwiftUI

struct BlogListView: View {
    @StateObject private var viewModel: BlogViewModel
    @State private var selectedBlogPost: BlogPost?
    @State private var showingCategoryFilter = false

    init(apiService: BlogAPIServiceProtocol = BlogAPIService()) {
        self._viewModel = StateObject(wrappedValue: BlogViewModel(apiService: apiService))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PTDesignTokens.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header with PT Logo
                    blogHeader

                    VStack(spacing: PTDesignTokens.Spacing.md) {
                        // Search Bar with PT styling
                        PTSearchBar(text: $viewModel.searchText, onSearchButtonClicked: {
                            viewModel.searchBlogPosts()
                        })

                        // Filter Bar with PT styling
                        PTBlogFilterBar(
                            showingCategoryFilter: $showingCategoryFilter,
                            selectedCategory: viewModel.selectedCategory,
                            activeFiltersCount: viewModel.activeFiltersCount,
                            onCategorySelected: { category in
                                viewModel.setCategory(category)
                            },
                            onClearFilters: {
                                viewModel.clearFilters()
                            }
                        )
                    }
                    .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
                    .padding(.bottom, PTDesignTokens.Spacing.sm)

                    // Blog Posts List
                    if viewModel.isLoading && viewModel.blogPosts.isEmpty {
                        PTLoadingView()
                            .frame(maxHeight: .infinity)
                    } else if viewModel.filteredBlogPosts.isEmpty {
                        PTEmptyStateView()
                            .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: PTDesignTokens.Spacing.md) {
                                ForEach(viewModel.filteredBlogPosts) { blogPost in
                                    BlogRowView(blogPost: blogPost, onBlogPostTap: {
                                        selectedBlogPost = blogPost
                                    })
                                    .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)

                                    // Load more when near the end
                                    if blogPost == viewModel.filteredBlogPosts.last && viewModel.hasMorePages {
                                        HStack {
                                            PTLogo(size: 16, showText: false)
                                                .rotationEffect(.degrees(360))
                                                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: true)
                                            Text("Loading more...")
                                                .font(PTFont.ptCaptionText)
                                                .foregroundColor(PTDesignTokens.Colors.medium)
                                        }
                                        .padding()
                                        .onAppear {
                                            viewModel.loadMoreBlogPosts()
                                        }
                                    }
                                }
                            }
                            .padding(.top, PTDesignTokens.Spacing.sm)
                            .padding(.bottom, PTDesignTokens.Spacing.xl)
                        }
                        .refreshable {
                            viewModel.refreshBlogPosts()
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingCategoryFilter) {
            CategoryFilterSheetView(
                categories: viewModel.availableCategories,
                selectedCategory: viewModel.selectedCategory,
                onCategorySelected: { category in
                    viewModel.setCategory(category)
                    showingCategoryFilter = false
                }
            )
        }
        .sheet(item: $selectedBlogPost) { blogPost in
            BlogDetailView(blogPost: blogPost)
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
            Button("Retry") {
                viewModel.refreshBlogPosts()
                viewModel.error = nil
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An error occurred")
        }
    }

    private var blogHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
                Text("Blog")
                    .font(PTFont.ptDisplaySmall)
                    .foregroundColor(PTDesignTokens.Colors.ink)

                Text("Latest updates from Proclamation Trust")
                    .font(PTFont.ptBodyText)
                    .foregroundColor(PTDesignTokens.Colors.medium)
            }

            Spacer()

            PTLogo(size: 32, showText: false)
        }
        .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
        .padding(.vertical, PTDesignTokens.Spacing.md)
    }
}

// MARK: - Blog Filter Bar

struct PTBlogFilterBar: View {
    @Binding var showingCategoryFilter: Bool
    let selectedCategory: String?
    let activeFiltersCount: Int
    let onCategorySelected: (String?) -> Void
    let onClearFilters: () -> Void

    var body: some View {
        HStack(spacing: PTDesignTokens.Spacing.md) {
            // Category Filter Button
            Button(action: { showingCategoryFilter = true }) {
                HStack(spacing: PTDesignTokens.Spacing.xs) {
                    Image(systemName: "tag")
                        .font(PTFont.ptButtonText)
                    Text(selectedCategory ?? "All Categories")
                        .font(PTFont.ptButtonText)
                    if selectedCategory != nil {
                        Text("(\(activeFiltersCount))")
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.tang)
                    }
                }
                .foregroundColor(PTDesignTokens.Colors.ink)
                .padding(.horizontal, PTDesignTokens.Spacing.md)
                .padding(.vertical, PTDesignTokens.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                        .fill(selectedCategory != nil ? PTDesignTokens.Colors.tang.opacity(0.1) : PTDesignTokens.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                .stroke(selectedCategory != nil ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.medium.opacity(0.3), lineWidth: 1)
                        )
                )
            }

            Spacer()

            // Clear Filters Button (only show if filters are active)
            if activeFiltersCount > 0 {
                Button(action: onClearFilters) {
                    HStack(spacing: PTDesignTokens.Spacing.xs) {
                        Image(systemName: "xmark.circle")
                            .font(PTFont.ptButtonText)
                        Text("Clear")
                            .font(PTFont.ptButtonText)
                    }
                    .foregroundColor(PTDesignTokens.Colors.medium)
                    .padding(.horizontal, PTDesignTokens.Spacing.md)
                    .padding(.vertical, PTDesignTokens.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                            .fill(PTDesignTokens.Colors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                    .stroke(PTDesignTokens.Colors.medium.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }
}

// MARK: - Category Filter Sheet

struct CategoryFilterSheetView: View {
    let categories: [String]
    let selectedCategory: String?
    let onCategorySelected: (String?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PTDesignTokens.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: PTDesignTokens.Spacing.sm) {
                        Text("Filter by Category")
                            .font(PTFont.ptSectionTitle)
                            .foregroundColor(PTDesignTokens.Colors.ink)

                        Text("Select a category to filter blog posts")
                            .font(PTFont.ptBodyText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
                    .padding(.top, PTDesignTokens.Spacing.lg)

                    ScrollView {
                        VStack(spacing: PTDesignTokens.Spacing.sm) {
                            // All Categories option
                            Button(action: {
                                onCategorySelected(nil)
                                dismiss()
                            }) {
                                HStack {
                                    Text("All Categories")
                                        .font(PTFont.ptBodyText)
                                        .foregroundColor(selectedCategory == nil ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.ink)

                                    Spacer()

                                    if selectedCategory == nil {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(PTDesignTokens.Colors.tang)
                                    }
                                }
                                .padding(.horizontal, PTDesignTokens.Spacing.md)
                                .padding(.vertical, PTDesignTokens.Spacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                                        .fill(selectedCategory == nil ? PTDesignTokens.Colors.tang.opacity(0.1) : PTDesignTokens.Colors.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                                                .stroke(selectedCategory == nil ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.light.opacity(0.2), lineWidth: 0.5)
                                        )
                                )
                            }
                            .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)

                            ForEach(categories, id: \.self) { category in
                                Button(action: {
                                    onCategorySelected(category)
                                    dismiss()
                                }) {
                                    HStack {
                                        Text(category)
                                            .font(PTFont.ptBodyText)
                                            .foregroundColor(selectedCategory == category ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.ink)

                                        Spacer()

                                        if selectedCategory == category {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(PTDesignTokens.Colors.tang)
                                        }
                                    }
                                    .padding(.horizontal, PTDesignTokens.Spacing.md)
                                    .padding(.vertical, PTDesignTokens.Spacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                                            .fill(selectedCategory == category ? PTDesignTokens.Colors.tang.opacity(0.1) : PTDesignTokens.Colors.surface)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                                                    .stroke(selectedCategory == category ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.light.opacity(0.2), lineWidth: 0.5)
                                            )
                                    )
                                }
                                .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
                            }
                        }
                        .padding(.top, PTDesignTokens.Spacing.lg)
                        .padding(.bottom, PTDesignTokens.Spacing.xl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(PTDesignTokens.Colors.tang)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

struct BlogListView_Previews: PreviewProvider {
    static var previews: some View {
        BlogListView(apiService: MockBlogAPIService())
    }
}
