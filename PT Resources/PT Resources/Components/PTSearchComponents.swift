//
//  PTSearchComponents.swift
//  PT Resources
//
//  Focused search-related UI components
//

import SwiftUI

// MARK: - Search Bar

struct PTSearchBar: View {
    @Binding var text: String
    let placeholder: String
    let onSearchButtonClicked: () -> Void
    let onClear: (() -> Void)?
    
    @FocusState private var isFocused: Bool
    
    init(
        text: Binding<String>, 
        placeholder: String = "Search talks, speakers, series...",
        onSearchButtonClicked: @escaping () -> Void,
        onClear: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSearchButtonClicked = onSearchButtonClicked
        self.onClear = onClear
    }

    var body: some View {
        HStack(spacing: PTDesignTokens.Spacing.md) {
            SearchInputField(
                text: $text,
                placeholder: placeholder,
                isFocused: $isFocused,
                onSubmit: onSearchButtonClicked
            )
            
            if !text.isEmpty {
                ClearButton {
                    text = ""
                    isFocused = false
                    onClear?()
                }
            }
        }
        .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
    }
}

// MARK: - Search Input Field

private struct SearchInputField: View {
    @Binding var text: String
    let placeholder: String
    var isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void
    
    var body: some View {
        HStack(spacing: PTDesignTokens.Spacing.md) {
            SearchIcon(isActive: isFocused.wrappedValue)
            
            TextField(placeholder, text: $text)
                .font(PTFont.ptBodyText)
                .foregroundColor(PTDesignTokens.Colors.ink)
                .focused(isFocused)
                .onSubmit(onSubmit)
                .submitLabel(.search)
        }
        .padding(.horizontal, PTDesignTokens.Spacing.lg)
        .padding(.vertical, PTDesignTokens.Spacing.md)
        .background(
            SearchFieldBackground(isFocused: isFocused.wrappedValue)
        )
        .overlay(
            SearchFieldBorder(isFocused: isFocused.wrappedValue)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused.wrappedValue)
    }
}

// MARK: - Search Icon

private struct SearchIcon: View {
    let isActive: Bool
    
    var body: some View {
        Image(systemName: "magnifyingglass")
            .foregroundColor(isActive ? PTDesignTokens.Colors.kleinBlue : PTDesignTokens.Colors.medium)
            .font(PTFont.ptSectionTitle)
            .frame(width: 20, height: 20)
    }
}

// MARK: - Clear Button

private struct ClearButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(PTDesignTokens.Colors.medium)
                .font(PTFont.ptButtonText)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Search Field Background

private struct SearchFieldBackground: View {
    let isFocused: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.input)
            .fill(PTDesignTokens.Colors.surface)
            .shadow(
                color: isFocused ? PTDesignTokens.Colors.tang.opacity(0.2) : Color.black.opacity(0.05),
                radius: isFocused ? 4 : 2,
                x: 0,
                y: isFocused ? 2 : 1
            )
    }
}

// MARK: - Search Field Border

private struct SearchFieldBorder: View {
    let isFocused: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.input)
            .stroke(
                isFocused ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.light.opacity(0.3), 
                lineWidth: isFocused ? 2 : 1
            )
    }
}

// MARK: - Search Suggestions

struct PTSearchSuggestions: View {
    let suggestions: [String]
    let onSuggestionTapped: (String) -> Void
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
            ForEach(suggestions, id: \.self) { suggestion in
                SearchSuggestionRow(
                    suggestion: suggestion,
                    onTap: { onSuggestionTapped(suggestion) }
                )
            }
        }
        .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
        .background(PTDesignTokens.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.md))
        .shadow(
            color: .black.opacity(0.1),
            radius: 4,
            x: 0,
            y: 2
        )
    }
}

// MARK: - Search Suggestion Row

private struct SearchSuggestionRow: View {
    let suggestion: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: PTDesignTokens.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundColor(PTDesignTokens.Colors.medium)
                
                Text(suggestion)
                    .font(PTFont.ptBodyText)
                    .foregroundColor(PTDesignTokens.Colors.ink)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding(.horizontal, PTDesignTokens.Spacing.md)
            .padding(.vertical, PTDesignTokens.Spacing.sm)
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Recent Searches

struct PTRecentSearches: View {
    let searches: [String]
    let onSearchTapped: (String) -> Void
    let onClearAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.md) {
            HStack {
                Text("Recent Searches")
                    .font(PTFont.ptSubheading)
                    .foregroundColor(PTDesignTokens.Colors.ink)
                
                Spacer()
                
                Button("Clear All", action: onClearAll)
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(PTDesignTokens.Colors.medium)
            }
            
            LazyVStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
                ForEach(searches, id: \.self) { search in
                    RecentSearchRow(
                        search: search,
                        onTap: { onSearchTapped(search) }
                    )
                }
            }
        }
        .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
    }
}

// MARK: - Recent Search Row

private struct RecentSearchRow: View {
    let search: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: PTDesignTokens.Spacing.sm) {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(PTDesignTokens.Colors.medium)
                
                Text(search)
                    .font(PTFont.ptBodyText)
                    .foregroundColor(PTDesignTokens.Colors.ink)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "arrow.up.left")
                    .font(.caption2)
                    .foregroundColor(PTDesignTokens.Colors.light)
            }
            .padding(.horizontal, PTDesignTokens.Spacing.md)
            .padding(.vertical, PTDesignTokens.Spacing.sm)
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}