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
    @Environment(\.colorScheme) private var colorScheme
    
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
                    .font(PTFont.ptButtonText)
                    .foregroundColor(PTDesignTokens.Colors.medium)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onFiltersChanged(localFilters)
                        dismiss()
                    }
                    .font(PTFont.ptButtonText)
                    .fontWeight(.semibold)
                    .foregroundColor(PTDesignTokens.Colors.kleinBlue)
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
    @Environment(\.colorScheme) private var colorScheme

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
            HStack(spacing: PTDesignTokens.Spacing.lg) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    VStack(spacing: PTDesignTokens.Spacing.xs) {
                        Image(systemName: tabs[index].1)
                            .font(PTFont.ptSectionTitle)
                        Text(tabs[index].0)
                            .font(PTFont.ptCaptionText)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedTab == index ? PTDesignTokens.Colors.kleinBlue : adaptiveTextColor)
                    .onTapGesture {
                        selectedTab = index
                    }
                }
            }
            .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
        }
        .background(adaptiveBackgroundColor)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(adaptiveBorderColor),
            alignment: .bottom
        )
    }
    
    // MARK: - Adaptive Colors
    private var adaptiveTextColor: Color {
        colorScheme == .dark ? PTDesignTokens.Colors.light : PTDesignTokens.Colors.medium
    }
    
    private var adaptiveBackgroundColor: Color {
        colorScheme == .dark ? PTDesignTokens.Colors.dark : PTDesignTokens.Colors.surface
    }
    
    private var adaptiveBorderColor: Color {
        colorScheme == .dark ? PTDesignTokens.Colors.medium.opacity(0.3) : PTDesignTokens.Colors.light.opacity(0.3)
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
        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.lg) {
            FilterSearchBar(text: $searchText, placeholder: "Search speakers...")

            if isLoading {
                VStack(spacing: PTDesignTokens.Spacing.lg) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading speakers...")
                        .font(PTFont.ptBodyText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: PTDesignTokens.Spacing.sm) {
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
                    .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
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

    var filteredConferenceTypes: [FilterOption] {
        if searchText.isEmpty {
            return conferenceTypes
        } else {
            return conferenceTypes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.lg) {
            FilterSearchBar(text: $searchText, placeholder: "Search conferences...")

            if isLoading {
                VStack(spacing: PTDesignTokens.Spacing.lg) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading conferences...")
                        .font(PTFont.ptBodyText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: PTDesignTokens.Spacing.lg) {
                        // Conference Types (if available)
                        if !filteredConferenceTypes.isEmpty {
                            ForEach(filteredConferenceTypes) { type in
                                FilterCheckboxRow(
                                    title: type.name,
                                    subtitle: nil,
                                    isSelected: filters.conferenceTypes.contains(type.id)
                                ) {
                                    toggleConferenceType(type.id)
                                }
                            }
                        }

                        // Specific Conferences
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
        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.lg) {
            FilterSearchBar(text: $searchText, placeholder: "Search Bible books...")

            if isLoading {
                VStack(spacing: PTDesignTokens.Spacing.lg) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading Bible books...")
                        .font(PTFont.ptBodyText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: PTDesignTokens.Spacing.sm) {
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
                    .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
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
        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.lg) {
            if isLoading {
                VStack(spacing: PTDesignTokens.Spacing.lg) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading years...")
                        .font(PTFont.ptBodyText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: PTDesignTokens.Spacing.md) {
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
                    .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
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
        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.lg) {
            FilterSearchBar(text: $searchText, placeholder: "Search collections...")

            if isLoading {
                VStack(spacing: PTDesignTokens.Spacing.lg) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading collections...")
                        .font(PTFont.ptBodyText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: PTDesignTokens.Spacing.sm) {
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
                    .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
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
                    .font(PTFont.ptBodyText)
                    .foregroundColor(PTDesignTokens.Colors.ink)
            }

            Section("Legacy Filters") {
                TextField("Speaker name...", text: Binding(
                    get: { filters.speaker ?? "" },
                    set: { filters.speaker = $0.isEmpty ? nil : $0 }
                ))
                .font(PTFont.ptBodyText)
                .foregroundColor(PTDesignTokens.Colors.ink)

                TextField("Series name...", text: Binding(
                    get: { filters.series ?? "" },
                    set: { filters.series = $0.isEmpty ? nil : $0 }
                ))
                .font(PTFont.ptBodyText)
                .foregroundColor(PTDesignTokens.Colors.ink)
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
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: PTDesignTokens.Spacing.md) {
            HStack(spacing: PTDesignTokens.Spacing.md) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(isFocused ? PTDesignTokens.Colors.kleinBlue : adaptiveIconColor)
                    .font(PTFont.ptSectionTitle)
                    .frame(width: 20, height: 20)

                TextField(placeholder, text: $text)
                    .font(PTFont.ptBodyText)
                    .foregroundColor(adaptiveTextColor)
                    .focused($isFocused)
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
                    .fill(adaptiveSearchBackgroundColor)
                    .shadow(
                        color: isFocused ? PTDesignTokens.Colors.tang.opacity(0.2) : adaptiveShadowColor,
                        radius: isFocused ? 4 : 2,
                        x: 0,
                        y: isFocused ? 2 : 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.input)
                    .stroke(isFocused ? PTDesignTokens.Colors.tang : adaptiveBorderColor, lineWidth: isFocused ? 2 : 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
    
    // MARK: - Adaptive Colors
    private var adaptiveTextColor: Color {
        colorScheme == .dark ? PTDesignTokens.Colors.light : PTDesignTokens.Colors.ink
    }
    
    private var adaptiveIconColor: Color {
        colorScheme == .dark ? PTDesignTokens.Colors.light : PTDesignTokens.Colors.medium
    }
    
    private var adaptiveSearchBackgroundColor: Color {
        colorScheme == .dark ? PTDesignTokens.Colors.dark : PTDesignTokens.Colors.surface
    }
    
    private var adaptiveShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.05)
    }
    
    private var adaptiveBorderColor: Color {
        colorScheme == .dark ? PTDesignTokens.Colors.medium.opacity(0.3) : PTDesignTokens.Colors.light.opacity(0.3)
    }
}

struct FilterCheckboxRow: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: PTDesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
                Text(title)
                    .font(PTFont.ptBodyText)
                    .foregroundColor(adaptiveTitleColor)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(adaptiveSubtitleColor)
                }
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? PTDesignTokens.Colors.kleinBlue : adaptiveIconColor)
                .font(PTFont.ptSectionTitle)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
        .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
        .padding(.vertical, PTDesignTokens.Spacing.sm)
    }
    
    // MARK: - Adaptive Colors
    private var adaptiveTitleColor: Color {
        colorScheme == .dark ? PTDesignTokens.Colors.light : PTDesignTokens.Colors.ink
    }
    
    private var adaptiveSubtitleColor: Color {
        colorScheme == .dark ? PTDesignTokens.Colors.medium : PTDesignTokens.Colors.medium
    }
    
    private var adaptiveIconColor: Color {
        colorScheme == .dark ? PTDesignTokens.Colors.light : PTDesignTokens.Colors.medium
    }
}

struct YearFilterCard: View {
    let year: String
    let count: Int?
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: PTDesignTokens.Spacing.xs) {
            Text(year)
                .font(PTFont.ptCardTitle)
                .fontWeight(.semibold)
                .foregroundColor(adaptiveTitleColor)

            if let count = count {
                Text("\(count) talks")
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(adaptiveSubtitleColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PTDesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                .fill(adaptiveCardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                        .stroke(adaptiveCardBorderColor, lineWidth: 1)
                )
        )
        .onTapGesture {
            action()
        }
    }
    
    // MARK: - Adaptive Colors
    private var adaptiveTitleColor: Color {
        colorScheme == .dark ? PTDesignTokens.Colors.light : PTDesignTokens.Colors.ink
    }
    
    private var adaptiveSubtitleColor: Color {
        colorScheme == .dark ? PTDesignTokens.Colors.medium : PTDesignTokens.Colors.medium
    }
    
    private var adaptiveCardBackgroundColor: Color {
        if isSelected {
            return colorScheme == .dark ? PTDesignTokens.Colors.tang.opacity(0.2) : PTDesignTokens.Colors.tang.opacity(0.1)
        } else {
            return colorScheme == .dark ? PTDesignTokens.Colors.dark : PTDesignTokens.Colors.surface
        }
    }
    
    private var adaptiveCardBorderColor: Color {
        if isSelected {
            return PTDesignTokens.Colors.tang
        } else {
            return colorScheme == .dark ? PTDesignTokens.Colors.medium.opacity(0.3) : PTDesignTokens.Colors.light.opacity(0.3)
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