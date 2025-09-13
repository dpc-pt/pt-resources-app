//
//  PTFilterComponents.swift
//  PT Resources
//
//  Filter-related UI components
//

import SwiftUI

// MARK: - Type Conversions

extension QuickFilterType {
    var asFilterType: FilterType {
        switch self {
        case .bibleBook:
            return .bibleBook
        case .topic:
            return .topic
        case .speaker:
            return .speaker
        case .series:
            return .series
        }
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
            HStack(spacing: PTDesignTokens.Spacing.md) {
                FilterButton(
                    isActive: activeFiltersCount > 0,
                    activeCount: activeFiltersCount,
                    action: { showingFilters = true }
                )
                
                Spacer()
            }
            
            if !activeFilters.isEmpty {
                ActiveFiltersView(
                    filters: activeFilters,
                    onClearFilter: onClearFilter
                )
            }
        }
        .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
    }
}

// MARK: - Filter Button

private struct FilterButton: View {
    let isActive: Bool
    let activeCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: PTDesignTokens.Spacing.sm) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(PTFont.ptButtonText)
                
                Text("Filter")
                    .font(PTFont.ptButtonText)
                
                if activeCount > 0 {
                    Text("(\(activeCount))")
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.tang)
                }
            }
            .foregroundColor(PTDesignTokens.Colors.ink)
            .padding(.horizontal, PTDesignTokens.Spacing.md)
            .padding(.vertical, PTDesignTokens.Spacing.sm)
            .background(
                FilterButtonBackground(isActive: isActive)
            )
            .overlay(
                FilterButtonBorder(isActive: isActive)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Filter Button Background

private struct FilterButtonBackground: View {
    let isActive: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
            .fill(isActive ? PTDesignTokens.Colors.tang.opacity(0.1) : PTDesignTokens.Colors.surface)
    }
}

// MARK: - Filter Button Border

private struct FilterButtonBorder: View {
    let isActive: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
            .stroke(
                isActive ? PTDesignTokens.Colors.tang.opacity(0.3) : PTDesignTokens.Colors.light.opacity(0.3),
                lineWidth: 1
            )
    }
}

// MARK: - Active Filters View

private struct ActiveFiltersView: View {
    let filters: [String]
    let onClearFilter: (String) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PTDesignTokens.Spacing.sm) {
                ForEach(filters, id: \.self) { filter in
                    ActiveFilterChip(
                        filter: filter,
                        onClear: { onClearFilter(filter) }
                    )
                }
            }
            .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
        }
    }
}

// MARK: - Active Filter Chip

private struct ActiveFilterChip: View {
    let filter: String
    let onClear: () -> Void
    
    var body: some View {
        HStack(spacing: PTDesignTokens.Spacing.xs) {
            Text(filter)
                .font(PTFont.ptCaptionText)
                .foregroundColor(PTDesignTokens.Colors.tang)
                .lineLimit(1)
            
            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(PTDesignTokens.Colors.tang)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, PTDesignTokens.Spacing.sm)
        .padding(.vertical, PTDesignTokens.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                .fill(PTDesignTokens.Colors.tang.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                .stroke(PTDesignTokens.Colors.tang.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Quick Filters

struct PTQuickFilters: View {
    let filters: [QuickFilterOption]
    let onFilterTapped: (QuickFilterOption) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.md) {
            Text("Quick Filters")
                .font(PTFont.ptSubheading)
                .foregroundColor(PTDesignTokens.Colors.ink)
                .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PTDesignTokens.Spacing.md) {
                    ForEach(filters) { filter in
                        QuickFilterCard(
                            filter: filter,
                            onTap: { onFilterTapped(filter) }
                        )
                    }
                }
                .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
            }
        }
    }
}

// MARK: - Quick Filter Card

private struct QuickFilterCard: View {
    let filter: QuickFilterOption
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
                HStack {
                    Text(filter.title)
                        .font(PTFont.ptButtonText)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    FilterTypeIcon(type: filter.filterType.asFilterType)
                }
                
            }
            .padding(PTDesignTokens.Spacing.md)
            .frame(width: 120, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.md)
                    .fill(PTDesignTokens.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.md)
                    .stroke(PTDesignTokens.Colors.light.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Filter Type Icon

private struct FilterTypeIcon: View {
    let type: FilterType
    
    private var iconName: String {
        switch type {
        case .speaker:
            return "person.circle"
        case .conference:
            return "calendar"
        case .bibleBook:
            return "book.closed"
        case .year:
            return "calendar.badge.clock"
        case .collection:
            return "folder"
        case .conferenceType:
            return "tag"
        case .topic:
            return "bubble.left"
        case .series:
            return "list.bullet"
        }
    }
    
    var body: some View {
        Image(systemName: iconName)
            .font(.caption)
            .foregroundColor(PTDesignTokens.Colors.medium)
            .frame(width: 16, height: 16)
    }
}

// MARK: - Sort Options

struct PTSortOptions: View {
    let options: [String]
    let selectedOption: String
    let onSelectionChanged: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.md) {
            Text("Sort By")
                .font(PTFont.ptSubheading)
                .foregroundColor(PTDesignTokens.Colors.ink)
            
            LazyVStack(spacing: PTDesignTokens.Spacing.xs) {
                ForEach(options, id: \.self) { option in
                    SortOptionRow(
                        option: option,
                        isSelected: option == selectedOption,
                        onTap: { onSelectionChanged(option) }
                    )
                }
            }
        }
        .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
    }
}

// MARK: - Sort Option Row

private struct SortOptionRow: View {
    let option: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(option)
                    .font(PTFont.ptBodyText)
                    .foregroundColor(isSelected ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.ink)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(PTDesignTokens.Colors.tang)
                }
            }
            .padding(.horizontal, PTDesignTokens.Spacing.md)
            .padding(.vertical, PTDesignTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                    .fill(isSelected ? PTDesignTokens.Colors.tang.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
