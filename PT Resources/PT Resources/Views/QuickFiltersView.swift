//
//  QuickFiltersView.swift
//  PT Resources
//
//  Quick filter chips for common searches
//

import SwiftUI

struct QuickFiltersView: View {
    let quickFilters: [QuickFilterOption]
    let onFilterTap: (QuickFilterOption) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.sm) {
            HStack {
                Text("Popular")
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(PTDesignTokens.Colors.medium)
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PTDesignTokens.Spacing.sm) {
                    ForEach(quickFilters) { filter in
                        QuickFilterChip(
                            filter: filter,
                            onTap: { onFilterTap(filter) }
                        )
                    }
                }
                .padding(.horizontal, 1) // Small padding to prevent shadow clipping
            }
        }
    }
}

struct QuickFilterChip: View {
    let filter: QuickFilterOption
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: PTDesignTokens.Spacing.xs) {
            Image(systemName: filter.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(chipForegroundColor)
            
            Text(filter.title)
                .font(PTFont.ptCaptionText)
                .fontWeight(.medium)
                .foregroundColor(chipForegroundColor)
        }
        .padding(.horizontal, PTDesignTokens.Spacing.sm)
        .padding(.vertical, PTDesignTokens.Spacing.xs)
        .background(chipBackgroundColor)
        .cornerRadius(PTDesignTokens.BorderRadius.full)
        .overlay(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.full)
                .stroke(chipBorderColor, lineWidth: 1)
        )
        .onTapGesture {
            onTap()
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
    
    @State private var isPressed = false
    
    private var chipBackgroundColor: Color {
        colorForFilter(filter.color).opacity(0.1)
    }
    
    private var chipForegroundColor: Color {
        colorForFilter(filter.color)
    }
    
    private var chipBorderColor: Color {
        colorForFilter(filter.color).opacity(0.3)
    }
    
    private func colorForFilter(_ colorName: String) -> Color {
        switch colorName {
        case "kleinBlue":
            return PTDesignTokens.Colors.kleinBlue
        case "tang":
            return PTDesignTokens.Colors.tang
        case "lawn":
            return PTDesignTokens.Colors.lawn
        case "turmeric":
            return PTDesignTokens.Colors.turmeric
        default:
            return PTDesignTokens.Colors.kleinBlue
        }
    }
}

// MARK: - Previews

#if DEBUG
struct QuickFiltersView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            QuickFiltersView(
                quickFilters: FiltersAPIService().getQuickFilters(),
                onFilterTap: { _ in }
            )
            .padding()
            
            Spacer()
        }
        .background(PTDesignTokens.Colors.background)
    }
}
#endif