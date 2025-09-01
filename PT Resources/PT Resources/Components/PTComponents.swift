//
//  PTComponents.swift
//  PT Resources
//
//  Beautiful PT-styled UI components
//

import SwiftUI

// MARK: - Search Bar

struct PTSearchBar: View {
    @Binding var text: String
    let onSearchButtonClicked: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: PTDesignTokens.Spacing.md) {
            HStack(spacing: PTDesignTokens.Spacing.md) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(isFocused ? PTDesignTokens.Colors.kleinBlue : PTDesignTokens.Colors.medium)
                    .font(PTFont.ptSectionTitle)
                    .frame(width: 20, height: 20)

                TextField("Search talks, speakers, series...", text: $text)
                    .font(PTFont.ptBodyText)
                    .foregroundColor(PTDesignTokens.Colors.ink)
                    .focused($isFocused)
                    .onSubmit {
                        onSearchButtonClicked()
                    }
                    .submitLabel(.search)

                if !text.isEmpty {
                    Button(action: {
                        text = ""
                        isFocused = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(PTDesignTokens.Colors.medium)
                            .font(PTFont.ptButtonText)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, PTDesignTokens.Spacing.lg)
            .padding(.vertical, PTDesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.input)
                    .fill(PTDesignTokens.Colors.surface)
                    .shadow(
                        color: isFocused ? PTDesignTokens.Colors.tang.opacity(0.2) : Color.black.opacity(0.05),
                        radius: isFocused ? 4 : 2,
                        x: 0,
                        y: isFocused ? 2 : 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.input)
                    .stroke(isFocused ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.light.opacity(0.3), lineWidth: isFocused ? 2 : 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
        .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
    }
}

// MARK: - Filter Bar

struct PTFilterBar: View {
    @Binding var showingFilters: Bool
    let activeFiltersCount: Int
    let activeFilters: [String]
    let onClearFilter: (String) -> Void

    var body: some View {
        VStack(spacing: PTDesignTokens.Spacing.md) {
            // Filter Button Row
            HStack(spacing: PTDesignTokens.Spacing.md) {
                // Filter Button
                Button(action: { showingFilters = true }) {
                    HStack(spacing: PTDesignTokens.Spacing.sm) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(PTFont.ptButtonText)
                        Text("Filter")
                            .font(PTFont.ptButtonText)
                        if activeFiltersCount > 0 {
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
                            .fill(activeFiltersCount > 0 ? PTDesignTokens.Colors.tang.opacity(0.1) : PTDesignTokens.Colors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                    .stroke(activeFiltersCount > 0 ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.medium.opacity(0.3), lineWidth: 1)
                            )
                    )
                }

                Spacer()

                // Clear All Button (only show if filters are active)
                if activeFiltersCount > 0 {
                    Button(action: { /* TODO: Implement clear all */ }) {
                        HStack(spacing: PTDesignTokens.Spacing.xs) {
                            Text("Clear All")
                                .font(PTFont.ptCaptionText)
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .padding(.horizontal, PTDesignTokens.Spacing.sm)
                        .padding(.vertical, PTDesignTokens.Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                                .fill(PTDesignTokens.Colors.veryLight)
                        )
                    }
                }
            }

            // Active Filters Row (only show if filters are active)
            if activeFiltersCount > 0 {
                HStack(spacing: PTDesignTokens.Spacing.sm) {
                    Text("Active filters:")
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.medium)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: PTDesignTokens.Spacing.sm) {
                            ForEach(activeFilters, id: \.self) { filter in
                                PTFilterChip(label: filter, onRemove: {
                                    onClearFilter(filter)
                                })
                            }
                        }
                    }
                }
                .padding(.vertical, PTDesignTokens.Spacing.xs)
            }
        }
    }
}

// MARK: - Filter Chip Component

struct PTFilterChip: View {
    let label: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: PTDesignTokens.Spacing.xs) {
            Text(label)
                .font(PTFont.ptCaptionText)
                .foregroundColor(PTDesignTokens.Colors.ink)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(PTDesignTokens.Colors.medium)
            }
        }
        .padding(.horizontal, PTDesignTokens.Spacing.sm)
        .padding(.vertical, PTDesignTokens.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                .fill(PTDesignTokens.Colors.tang.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                        .stroke(PTDesignTokens.Colors.tang.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Loading View

struct PTLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: PTDesignTokens.Spacing.lg) {
            PTLogo(size: 48, showText: false)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
                .onAppear {
                    isAnimating = true
                }
            
            Text("Loading resources...")
                .font(PTFont.ptSectionTitle)  // Using PT section title typography
                .foregroundColor(PTDesignTokens.Colors.ink)      // Using PT Ink for primary text
            
            Text("Fetching the latest sermons and talks")
                .font(PTFont.ptBodyText)      // Using PT body typography
                .foregroundColor(PTDesignTokens.Colors.medium)
                .multilineTextAlignment(.center)
        }
        .padding(PTDesignTokens.Spacing.xl)
    }
}

// MARK: - Empty State View

struct PTEmptyStateView: View {
    var body: some View {
        VStack(spacing: PTDesignTokens.Spacing.lg) {
            PTLogo(size: 64, showText: false)
            
            Text("No Resources Found")
                .font(PTFont.ptSectionTitle)  // Using PT section title typography
                .foregroundColor(PTDesignTokens.Colors.ink)      // Using PT Ink for primary text
            
            Text("Try adjusting your search terms or filters to find more content")
                .font(PTFont.ptBodyText)      // Using PT body typography
                .foregroundColor(PTDesignTokens.Colors.medium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PTDesignTokens.Spacing.lg)
        }
        .padding(PTDesignTokens.Spacing.xl)
    }
}

// MARK: - Previews

struct PTComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: PTDesignTokens.Spacing.xl) {
            VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.sm) {
                Text("Search Bar - Default")
                    .font(PTFont.ptSectionTitle)
                    .foregroundColor(PTDesignTokens.Colors.ink)
                PTSearchBar(text: .constant(""), onSearchButtonClicked: {})

                Text("Search Bar - With Text")
                    .font(PTFont.ptSectionTitle)
                    .foregroundColor(PTDesignTokens.Colors.ink)
                PTSearchBar(text: .constant("John Piper"), onSearchButtonClicked: {})
            }

            VStack(spacing: PTDesignTokens.Spacing.lg) {
                Text("Filter Bar - No Active Filters")
                    .font(PTFont.ptSectionTitle)
                    .foregroundColor(PTDesignTokens.Colors.ink)

                PTFilterBar(
                    showingFilters: .constant(false),
                    activeFiltersCount: 0,
                    activeFilters: [],
                    onClearFilter: { _ in }
                )

                Text("Filter Bar - With Active Filters")
                    .font(PTFont.ptSectionTitle)
                    .foregroundColor(PTDesignTokens.Colors.ink)

                PTFilterBar(
                    showingFilters: .constant(false),
                    activeFiltersCount: 3,
                    activeFilters: ["John Piper", "Romans Series", "2024"],
                    onClearFilter: { _ in }
                )
            }

            PTLoadingView()

            PTEmptyStateView()
        }
        .padding(PTDesignTokens.Spacing.xl)
        .background(PTDesignTokens.Colors.background)
        .previewLayout(.sizeThatFits)
    }
}
