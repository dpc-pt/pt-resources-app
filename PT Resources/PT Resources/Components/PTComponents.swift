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
        HStack(spacing: PTSpacing.sm) {
            HStack(spacing: PTSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.ptDarkGray)
                    .font(.system(size: 16, weight: .medium))
                
                TextField("Search talks, speakers, series...", text: $text)
                    .font(PTFont.bodyText)
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
                            .foregroundColor(.ptMediumGray)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, PTSpacing.md)
            .padding(.vertical, PTSpacing.sm + 2)
            .background(Color.ptSurface)
            .cornerRadius(PTCornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: PTCornerRadius.medium)
                    .stroke(isFocused ? Color.ptCoral : Color.ptMediumGray.opacity(0.3), lineWidth: isFocused ? 2 : 1)
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
        HStack(spacing: PTSpacing.md) {
            // Filter Button
            Button(action: { showingFilters = true }) {
                HStack(spacing: PTSpacing.xs) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 16, weight: .medium))
                    Text("Filter")
                        .font(PTFont.cardSubtitle)
                    if activeFiltersCount > 0 {
                        Text("(\(activeFiltersCount))")
                            .font(PTFont.captionText)
                            .foregroundColor(.ptCoral)
                    }
                }
                .foregroundColor(.ptPrimary)
                .padding(.horizontal, PTSpacing.md)
                .padding(.vertical, PTSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: PTCornerRadius.button)
                        .fill(activeFiltersCount > 0 ? Color.ptCoral.opacity(0.1) : Color.ptSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: PTCornerRadius.button)
                                .stroke(activeFiltersCount > 0 ? Color.ptCoral : Color.ptMediumGray.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            Spacer()
            
            // Sort Button
            Button(action: { showingSortOptions = true }) {
                HStack(spacing: PTSpacing.xs) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 16, weight: .medium))
                    Text(currentSortOption.displayName)
                        .font(PTFont.cardSubtitle)
                }
                .foregroundColor(.ptPrimary)
                .padding(.horizontal, PTSpacing.md)
                .padding(.vertical, PTSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: PTCornerRadius.button)
                        .fill(Color.ptSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: PTCornerRadius.button)
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
        VStack(spacing: PTSpacing.lg) {
            PTLogo(size: 48, showText: false)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
                .onAppear {
                    isAnimating = true
                }
            
            Text("Loading resources...")
                .font(PTFont.sectionTitle)
                .foregroundColor(.ptPrimary)
            
            Text("Fetching the latest sermons and talks")
                .font(PTFont.bodyText)
                .foregroundColor(.ptDarkGray)
                .multilineTextAlignment(.center)
        }
        .padding(PTSpacing.xl)
    }
}

// MARK: - Empty State View

struct PTEmptyStateView: View {
    var body: some View {
        VStack(spacing: PTSpacing.lg) {
            PTLogo(size: 64, showText: false)
            
            Text("No Resources Found")
                .font(PTFont.sectionTitle)
                .foregroundColor(.ptPrimary)
            
            Text("Try adjusting your search terms or filters to find more content")
                .font(PTFont.bodyText)
                .foregroundColor(.ptDarkGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PTSpacing.lg)
        }
        .padding(PTSpacing.xl)
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
