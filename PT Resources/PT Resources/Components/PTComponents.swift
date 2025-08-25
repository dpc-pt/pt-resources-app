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
        HStack(spacing: PTDesignTokens.Spacing.sm) {
            HStack(spacing: PTDesignTokens.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(PTDesignTokens.Colors.medium)
                    .font(.system(size: 16, weight: .medium))
                
                TextField("Search talks, speakers, series...", text: $text)
                    .font(PTFont.ptBodyText)  // Using PT brand typography
                    .focused($isFocused)
                    .onSubmit {
                        onSearchButtonClicked()
                    }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                        isFocused = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(PTDesignTokens.Colors.light)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, PTDesignTokens.Spacing.md)
            .padding(.vertical, PTDesignTokens.Spacing.sm + 2)
            .background(PTDesignTokens.Colors.surface)
            .cornerRadius(PTDesignTokens.BorderRadius.input)  // Using input-specific corner radius
            .overlay(
                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.input)
                    .stroke(isFocused ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.light.opacity(0.3), lineWidth: isFocused ? 2 : 1)  // Using PT Tang for focus
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

// MARK: - Filter Sort Bar

struct PTFilterSortBar: View {
    @Binding var showingFilters: Bool
    @Binding var showingSortOptions: Bool
    let activeFiltersCount: Int
    let currentSortOption: TalkSortOption
    
    var body: some View {
        HStack(spacing: PTDesignTokens.Spacing.md) {
            // Filter Button
            Button(action: { showingFilters = true }) {
                HStack(spacing: PTDesignTokens.Spacing.xs) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 16, weight: .medium))
                    Text("Filter")
                        .font(PTFont.ptButtonText)  // Using PT button typography
                    if activeFiltersCount > 0 {
                        Text("(\(activeFiltersCount))")
                            .font(PTFont.ptCaptionText)  // Using PT caption typography
                            .foregroundColor(.ptTang)  // Using PT Tang instead of coral
                    }
                }
                .foregroundColor(.ptInk)  // Using PT Ink for primary text color
                .padding(.horizontal, PTDesignTokens.Spacing.md)
                .padding(.vertical, PTDesignTokens.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                        .fill(activeFiltersCount > 0 ? Color.ptTang.opacity(0.1) : Color.ptSurface)  // Tang accent background
                        .overlay(
                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                .stroke(activeFiltersCount > 0 ? Color.ptTang : Color.ptMediumGray.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            Spacer()
            
            // Sort Button
            Button(action: { showingSortOptions = true }) {
                HStack(spacing: PTDesignTokens.Spacing.xs) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 16, weight: .medium))
                    Text(currentSortOption.displayName)
                        .font(PTFont.ptButtonText)  // Using PT button typography
                }
                .foregroundColor(.ptInk)  // Using PT Ink for primary text color
                .padding(.horizontal, PTDesignTokens.Spacing.md)
                .padding(.vertical, PTDesignTokens.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                        .fill(Color.ptSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                .stroke(Color.ptMediumGray.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
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
                .foregroundColor(.ptInk)      // Using PT Ink for primary text
            
            Text("Fetching the latest sermons and talks")
                .font(PTFont.ptBodyText)      // Using PT body typography
                .foregroundColor(.ptDarkGray)
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
                .foregroundColor(.ptInk)      // Using PT Ink for primary text
            
            Text("Try adjusting your search terms or filters to find more content")
                .font(PTFont.ptBodyText)      // Using PT body typography
                .foregroundColor(.ptDarkGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PTDesignTokens.Spacing.lg)
        }
        .padding(PTDesignTokens.Spacing.xl)
    }
}

// MARK: - Previews

struct PTComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 32) {
            PTSearchBar(text: .constant("Search text"), onSearchButtonClicked: {})
            
            PTFilterSortBar(
                showingFilters: .constant(false),
                showingSortOptions: .constant(false),
                activeFiltersCount: 2,
                currentSortOption: .dateNewest
            )
            
            PTLoadingView()
            
            PTEmptyStateView()
        }
        .padding()
        .background(Color.ptBackground)
        .previewLayout(.sizeThatFits)
    }
}
