//
//  FilterSortViews.swift
//  PT Resources
//
//  Filter and sort sheet views
//

import SwiftUI

// MARK: - Filter Sheet

struct FilterSheetView: View {
    @State private var localFilters: TalkSearchFilters
    let onFiltersChanged: (TalkSearchFilters) -> Void
    @Environment(\.dismiss) private var dismiss
    
    init(filters: TalkSearchFilters, onFiltersChanged: @escaping (TalkSearchFilters) -> Void) {
        self._localFilters = State(initialValue: filters)
        self.onFiltersChanged = onFiltersChanged
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Search") {
                    TextField("Search terms...", text: $localFilters.query)
                }
                
                Section("Speaker") {
                    TextField("Speaker name...", text: Binding(
                        get: { localFilters.speaker ?? "" },
                        set: { localFilters.speaker = $0.isEmpty ? nil : $0 }
                    ))
                }
                
                Section("Series") {
                    TextField("Series name...", text: Binding(
                        get: { localFilters.series ?? "" },
                        set: { localFilters.series = $0.isEmpty ? nil : $0 }
                    ))
                }
                
                Section("Date Range") {
                    DatePicker("From", selection: Binding(
                        get: { localFilters.dateFrom ?? Date() },
                        set: { localFilters.dateFrom = $0 }
                    ), displayedComponents: .date)
                    .disabled(localFilters.dateFrom == nil)
                    
                    Toggle("Use start date", isOn: Binding(
                        get: { localFilters.dateFrom != nil },
                        set: { localFilters.dateFrom = $0 ? Date() : nil }
                    ))
                    
                    DatePicker("To", selection: Binding(
                        get: { localFilters.dateTo ?? Date() },
                        set: { localFilters.dateTo = $0 }
                    ), displayedComponents: .date)
                    .disabled(localFilters.dateTo == nil)
                    
                    Toggle("Use end date", isOn: Binding(
                        get: { localFilters.dateTo != nil },
                        set: { localFilters.dateTo = $0 ? Date() : nil }
                    ))
                }
                
                Section("Content") {
                    if let hasTranscript = localFilters.hasTranscript {
                        Toggle("Has transcript", isOn: Binding(
                            get: { hasTranscript },
                            set: { localFilters.hasTranscript = $0 }
                        ))
                    } else {
                        Toggle("Filter by transcript", isOn: Binding(
                            get: { false },
                            set: { localFilters.hasTranscript = $0 ? true : nil }
                        ))
                    }
                    
                    if let isDownloaded = localFilters.isDownloaded {
                        Toggle("Downloaded only", isOn: Binding(
                            get: { isDownloaded },
                            set: { localFilters.isDownloaded = $0 }
                        ))
                    } else {
                        Toggle("Filter by downloads", isOn: Binding(
                            get: { false },
                            set: { localFilters.isDownloaded = $0 ? true : nil }
                        ))
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        localFilters = TalkSearchFilters()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onFiltersChanged(localFilters)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Sort Options Sheet

struct SortOptionsSheetView: View {
    let selectedOption: TalkSortOption
    let onOptionSelected: (TalkSortOption) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(TalkSortOption.allCases, id: \.self) { option in
                    Button(action: {
                        onOptionSelected(option)
                        dismiss()
                    }) {
                        HStack {
                            Text(option.displayName)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if option == selectedOption {
                                Image(systemName: "checkmark")
                                    .foregroundColor(PTDesignTokens.Colors.kleinBlue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sort By")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}


// MARK: - Previews

struct FilterSheetView_Previews: PreviewProvider {
    static var previews: some View {
        FilterSheetView(filters: TalkSearchFilters()) { _ in }
    }
}

struct SortOptionsSheetView_Previews: PreviewProvider {
    static var previews: some View {
        SortOptionsSheetView(selectedOption: .dateNewest) { _ in }
    }
}

