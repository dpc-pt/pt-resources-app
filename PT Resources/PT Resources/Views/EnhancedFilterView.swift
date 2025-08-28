//
//  EnhancedFilterView.swift
//  PT Resources
//
//  Enhanced filtering interface with all filter options from the API
//

import SwiftUI

// MARK: - Enhanced Filter Sheet

struct EnhancedFilterView: View {
    @State private var localFilters: TalkSearchFilters
    @ObservedObject var filtersAPIService: FiltersAPIService
    let onFiltersChanged: (TalkSearchFilters) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = 0
    @State private var searchText = ""
    
    init(filters: TalkSearchFilters, filtersAPIService: FiltersAPIService, onFiltersChanged: @escaping (TalkSearchFilters) -> Void) {
        self._localFilters = State(initialValue: filters)
        self.filtersAPIService = filtersAPIService
        self.onFiltersChanged = onFiltersChanged
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter tabs
                FilterTabBar(selectedTab: $selectedTab)
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    SpeakersFilterTab(
                        filters: $localFilters,
                        filtersAPIService: filtersAPIService,
                        searchText: $searchText
                    )
                    .tag(0)
                    
                    ConferencesFilterTab(
                        filters: $localFilters,
                        filtersAPIService: filtersAPIService,
                        searchText: $searchText
                    )
                    .tag(1)
                    
                    BibleBooksFilterTab(
                        filters: $localFilters,
                        filtersAPIService: filtersAPIService,
                        searchText: $searchText
                    )
                    .tag(2)
                    
                    YearsFilterTab(
                        filters: $localFilters,
                        filtersAPIService: filtersAPIService
                    )
                    .tag(3)
                    
                    CollectionsFilterTab(
                        filters: $localFilters,
                        filtersAPIService: filtersAPIService,
                        searchText: $searchText
                    )
                    .tag(4)
                    
                    AdvancedFilterTab(
                        filters: $localFilters
                    )
                    .tag(5)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Filter Resources")
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
                    .fontWeight(.semibold)
                }
            }
        }
        .task {
            // Load filter options when view appears
            _ = try? await filtersAPIService.fetchFilterOptions()
        }
    }
}

// MARK: - Filter Tab Bar

struct FilterTabBar: View {
    @Binding var selectedTab: Int
    
    private let tabs = [
        ("Speakers", "person.circle"),
        ("Conferences", "building.columns"),
        ("Bible", "book.closed"),
        ("Years", "calendar"),
        ("Collections", "folder"),
        ("Advanced", "slider.horizontal.3")
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    VStack(spacing: 4) {
                        Image(systemName: tabs[index].1)
                            .font(.system(size: 20))
                        Text(tabs[index].0)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedTab == index ? PTDesignTokens.Colors.kleinBlue : .gray)
                    .onTapGesture {
                        selectedTab = index
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
}

// MARK: - Speakers Filter Tab

struct SpeakersFilterTab: View {
    @Binding var filters: TalkSearchFilters
    @ObservedObject var filtersAPIService: FiltersAPIService
    @Binding var searchText: String
    
    @State private var speakers: [FilterOption] = []
    @State private var isLoading = false
    
    var filteredSpeakers: [FilterOption] {
        if searchText.isEmpty {
            return speakers
        } else {
            return speakers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FilterSearchBar(text: $searchText, placeholder: "Search speakers...")
            
            if isLoading {
                ProgressView("Loading speakers...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredSpeakers) { speaker in
                            FilterCheckboxRow(
                                title: speaker.name,
                                subtitle: speaker.count.map { "\($0) talks" },
                                isSelected: filters.speakerIds.contains(speaker.id)
                            ) {
                                toggleSpeaker(speaker.id)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task {
            await loadSpeakers()
        }
    }
    
    private func loadSpeakers() async {
        isLoading = true
        do {
            speakers = try await filtersAPIService.getSpeakerFilterOptions()
        } catch {
            // Handle error silently - proper error handling should be implemented
            // based on app's error handling strategy
        }
        isLoading = false
    }
    
    private func toggleSpeaker(_ speakerId: String) {
        if filters.speakerIds.contains(speakerId) {
            filters.removeSpeaker(speakerId)
        } else {
            filters.addSpeaker(speakerId)
        }
    }
}

// MARK: - Conferences Filter Tab

struct ConferencesFilterTab: View {
    @Binding var filters: TalkSearchFilters
    @ObservedObject var filtersAPIService: FiltersAPIService
    @Binding var searchText: String
    
    @State private var conferences: [FilterOption] = []
    @State private var conferenceTypes: [FilterOption] = []
    @State private var isLoading = false
    
    var filteredConferences: [FilterOption] {
        if searchText.isEmpty {
            return conferences
        } else {
            return conferences.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FilterSearchBar(text: $searchText, placeholder: "Search conferences...")
            
            if isLoading {
                ProgressView("Loading conferences...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        // Conference Types Section
                        if !conferenceTypes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Conference Types")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(conferenceTypes) { type in
                                    FilterCheckboxRow(
                                        title: type.name,
                                        subtitle: nil,
                                        isSelected: filters.conferenceTypes.contains(type.id)
                                    ) {
                                        toggleConferenceType(type.id)
                                    }
                                }
                            }
                            
                            Divider()
                                .padding(.horizontal)
                        }
                        
                        // Specific Conferences Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Conferences")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(filteredConferences) { conference in
                                FilterCheckboxRow(
                                    title: conference.name,
                                    subtitle: conference.count.map { "\($0) talks" },
                                    isSelected: filters.conferenceIds.contains(conference.id)
                                ) {
                                    toggleConference(conference.id)
                                }
                            }
                        }
                    }
                }
            }
        }
        .task {
            await loadConferences()
        }
    }
    
    private func loadConferences() async {
        isLoading = true
        do {
            async let conferencesTask = filtersAPIService.getConferenceFilterOptions()
            async let typesTask = filtersAPIService.getConferenceTypeFilterOptions()
            
            conferences = try await conferencesTask
            conferenceTypes = try await typesTask
        } catch {
            // Handle error silently
        }
        isLoading = false
    }
    
    private func toggleConference(_ conferenceId: String) {
        if filters.conferenceIds.contains(conferenceId) {
            filters.removeConference(conferenceId)
        } else {
            filters.addConference(conferenceId)
        }
    }
    
    private func toggleConferenceType(_ type: String) {
        if filters.conferenceTypes.contains(type) {
            filters.removeConferenceType(type)
        } else {
            filters.addConferenceType(type)
        }
    }
}

// MARK: - Bible Books Filter Tab

struct BibleBooksFilterTab: View {
    @Binding var filters: TalkSearchFilters
    @ObservedObject var filtersAPIService: FiltersAPIService
    @Binding var searchText: String
    
    @State private var bibleBooks: [FilterOption] = []
    @State private var isLoading = false
    
    var filteredBooks: [FilterOption] {
        if searchText.isEmpty {
            return bibleBooks
        } else {
            return bibleBooks.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FilterSearchBar(text: $searchText, placeholder: "Search Bible books...")
            
            if isLoading {
                ProgressView("Loading Bible books...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredBooks) { book in
                            FilterCheckboxRow(
                                title: book.name,
                                subtitle: book.count.map { "\($0) talks" },
                                isSelected: filters.bibleBookIds.contains(book.id)
                            ) {
                                toggleBibleBook(book.id)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task {
            await loadBibleBooks()
        }
    }
    
    private func loadBibleBooks() async {
        isLoading = true
        do {
            bibleBooks = try await filtersAPIService.getBibleBookFilterOptions()
        } catch {
            // Handle error silently
        }
        isLoading = false
    }
    
    private func toggleBibleBook(_ bookId: String) {
        if filters.bibleBookIds.contains(bookId) {
            filters.removeBibleBook(bookId)
        } else {
            filters.addBibleBook(bookId)
        }
    }
}

// MARK: - Years Filter Tab

struct YearsFilterTab: View {
    @Binding var filters: TalkSearchFilters
    @ObservedObject var filtersAPIService: FiltersAPIService
    
    @State private var years: [FilterOption] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoading {
                ProgressView("Loading years...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(years) { year in
                            YearFilterCard(
                                year: year.name,
                                count: year.count,
                                isSelected: filters.years.contains(year.id)
                            ) {
                                toggleYear(year.id)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task {
            await loadYears()
        }
    }
    
    private func loadYears() async {
        isLoading = true
        do {
            years = try await filtersAPIService.getYearFilterOptions()
        } catch {
            // Handle error silently
        }
        isLoading = false
    }
    
    private func toggleYear(_ year: String) {
        if filters.years.contains(year) {
            filters.removeYear(year)
        } else {
            filters.addYear(year)
        }
    }
}

// MARK: - Collections Filter Tab

struct CollectionsFilterTab: View {
    @Binding var filters: TalkSearchFilters
    @ObservedObject var filtersAPIService: FiltersAPIService
    @Binding var searchText: String
    
    @State private var collections: [FilterOption] = []
    @State private var isLoading = false
    
    var filteredCollections: [FilterOption] {
        if searchText.isEmpty {
            return collections
        } else {
            return collections.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FilterSearchBar(text: $searchText, placeholder: "Search collections...")
            
            if isLoading {
                ProgressView("Loading collections...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredCollections) { collection in
                            FilterCheckboxRow(
                                title: collection.name,
                                subtitle: collection.count.map { "\($0) talks" },
                                isSelected: filters.collections.contains(collection.id)
                            ) {
                                toggleCollection(collection.id)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task {
            await loadCollections()
        }
    }
    
    private func loadCollections() async {
        isLoading = true
        do {
            collections = try await filtersAPIService.getCollectionFilterOptions()
        } catch {
            // Handle error silently
        }
        isLoading = false
    }
    
    private func toggleCollection(_ collectionId: String) {
        if filters.collections.contains(collectionId) {
            filters.removeCollection(collectionId)
        } else {
            filters.addCollection(collectionId)
        }
    }
}

// MARK: - Advanced Filter Tab

struct AdvancedFilterTab: View {
    @Binding var filters: TalkSearchFilters
    
    var body: some View {
        Form {
            Section("Search") {
                TextField("Search terms...", text: $filters.query)
            }
            
            Section("Legacy Filters") {
                TextField("Speaker name...", text: Binding(
                    get: { filters.speaker ?? "" },
                    set: { filters.speaker = $0.isEmpty ? nil : $0 }
                ))
                
                TextField("Series name...", text: Binding(
                    get: { filters.series ?? "" },
                    set: { filters.series = $0.isEmpty ? nil : $0 }
                ))
            }
            
            Section("Date Range") {
                DatePicker("From", selection: Binding(
                    get: { filters.dateFrom ?? Date() },
                    set: { filters.dateFrom = $0 }
                ), displayedComponents: .date)
                .disabled(filters.dateFrom == nil)
                
                Toggle("Use start date", isOn: Binding(
                    get: { filters.dateFrom != nil },
                    set: { filters.dateFrom = $0 ? Date() : nil }
                ))
                
                DatePicker("To", selection: Binding(
                    get: { filters.dateTo ?? Date() },
                    set: { filters.dateTo = $0 }
                ), displayedComponents: .date)
                .disabled(filters.dateTo == nil)
                
                Toggle("Use end date", isOn: Binding(
                    get: { filters.dateTo != nil },
                    set: { filters.dateTo = $0 ? Date() : nil }
                ))
            }
            
            Section("Content") {
                if let hasTranscript = filters.hasTranscript {
                    Toggle("Has transcript", isOn: Binding(
                        get: { hasTranscript },
                        set: { filters.hasTranscript = $0 }
                    ))
                } else {
                    Toggle("Filter by transcript", isOn: Binding(
                        get: { false },
                        set: { filters.hasTranscript = $0 ? true : nil }
                    ))
                }
                
                if let isDownloaded = filters.isDownloaded {
                    Toggle("Downloaded only", isOn: Binding(
                        get: { isDownloaded },
                        set: { filters.isDownloaded = $0 }
                    ))
                } else {
                    Toggle("Filter by downloads", isOn: Binding(
                        get: { false },
                        set: { filters.isDownloaded = $0 ? true : nil }
                    ))
                }
            }
        }
    }
}

// MARK: - Supporting UI Components

struct FilterSearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.horizontal)
    }
}

struct FilterCheckboxRow: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? PTDesignTokens.Colors.kleinBlue : .gray)
                .font(.title2)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct YearFilterCard: View {
    let year: String
    let count: Int?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            Text(year)
                .font(.title2)
                .fontWeight(.semibold)
            
            if let count = count {
                Text("\(count) talks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? PTDesignTokens.Colors.kleinBlue.opacity(0.1) : Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? PTDesignTokens.Colors.kleinBlue : Color.clear, lineWidth: 2)
                )
        )
        .onTapGesture {
            action()
        }
    }
}

// MARK: - Previews

#if DEBUG
struct EnhancedFilterView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedFilterView(
            filters: TalkSearchFilters(),
            filtersAPIService: FiltersAPIService()
        ) { _ in }
    }
}
#endif