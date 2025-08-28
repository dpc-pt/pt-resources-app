//
//  TalksViewModel.swift
//  PT Resources
//
//  ViewModel for managing talks list and search functionality
//

import Foundation
import CoreData
import Combine

// Import for image prefetching
import SwiftUI

// MARK: - Supporting Types

enum FilterType {
    case speaker
    case conference
    case bibleBook
    case year
    case collection
    case conferenceType
}

@MainActor
final class TalksViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var talks: [Talk] = []
    @Published var filteredTalks: [Talk] = []
    @Published var searchText = ""
    @Published var selectedFilters = TalkSearchFilters()
    @Published var sortOption: TalkSortOption = .dateNewest
    @Published var isLoading = false
    @Published var error: APIError?
    @Published var hasMorePages = true
    @Published var currentPage = 1
    
    // MARK: - Filter Properties
    
    @Published var availableFilters: FilterOptions?
    @Published var isLoadingFilters = false
    
    // MARK: - Private Properties
    
    private let apiService: TalksAPIServiceProtocol
    private let filtersAPIService: FiltersAPIServiceProtocol
    private let persistenceController: PersistenceController
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(apiService: TalksAPIServiceProtocol, filtersAPIService: FiltersAPIServiceProtocol = FiltersAPIService(), persistenceController: PersistenceController = .shared, initialFilters: TalkSearchFilters? = nil) {
        self.apiService = apiService
        self.filtersAPIService = filtersAPIService
        self.persistenceController = persistenceController
        
        // Set initial filters if provided
        if let initialFilters = initialFilters {
            self.selectedFilters = initialFilters
        }
        
        setupBindings()
        loadTalks()
        loadFilterOptions()
    }
    
    // MARK: - Public Methods
    
    func loadTalks() {
        Task {
            await fetchTalks(page: 1, resetList: true)
        }
    }
    
    func loadMoreTalks() {
        guard !isLoading && hasMorePages else { return }
        
        Task {
            await fetchTalks(page: currentPage + 1, resetList: false)
        }
    }
    
    func refreshTalks() {
        Task {
            await fetchTalks(page: 1, resetList: true)
        }
    }
    
    func searchTalks() {
        selectedFilters.query = searchText
        
        // Apply client-side filtering immediately if we have talks
        if !talks.isEmpty {
            applyClientSideFiltering()
        }
        
        // Also fetch fresh data from API
        Task {
            await fetchTalks(page: 1, resetList: true)
        }
    }
    
    func clearSearch() {
        searchText = ""
        selectedFilters = TalkSearchFilters()
        loadTalks()
    }
    
    func applyFilters(_ filters: TalkSearchFilters) {
        selectedFilters = filters
        
        // Apply client-side filtering immediately if we have talks
        if !talks.isEmpty {
            applyClientSideFiltering()
        }
        
        // Also fetch fresh data from API (which may or may not support filtering)
        Task {
            await fetchTalks(page: 1, resetList: true)
        }
    }
    
    func changeSortOption(_ newSortOption: TalkSortOption) {
        sortOption = newSortOption
        Task {
            await fetchTalks(page: 1, resetList: true)
        }
    }
    
    func loadFilterOptions() {
        Task {
            await fetchFilterOptions()
        }
    }
    
    // MARK: - Filter Management Methods
    
    func applyQuickFilter(_ quickFilter: QuickFilterOption) {
        switch quickFilter.filterType {
        case .speaker:
            selectedFilters.addSpeaker(quickFilter.value)
        case .bibleBook:
            selectedFilters.addBibleBook(quickFilter.value)
        case .topic:
            // Handle topic-based filtering - could map to collections or other filters
            selectedFilters.query = quickFilter.value
        case .series:
            selectedFilters.series = quickFilter.value
        }
        
        Task {
            await fetchTalks(page: 1, resetList: true)
        }
    }
    
    func removeFilter(type: FilterType, value: String) {
        switch type {
        case .speaker:
            selectedFilters.removeSpeaker(value)
        case .conference:
            selectedFilters.removeConference(value)
        case .bibleBook:
            selectedFilters.removeBibleBook(value)
        case .year:
            selectedFilters.removeYear(value)
        case .collection:
            selectedFilters.removeCollection(value)
        case .conferenceType:
            selectedFilters.removeConferenceType(value)
        }
        
        Task {
            await fetchTalks(page: 1, resetList: true)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Auto-search when text changes (with debounce)
        $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.searchTalks()
            }
            .store(in: &cancellables)
    }
    
    private func fetchTalks(page: Int, resetList: Bool) async {
        isLoading = true
        error = nil
        
        do {
            let response = try await apiService.fetchTalks(
                filters: selectedFilters,
                page: page,
                sortBy: sortOption
            )
            
            if resetList {
                talks = response.talks
                currentPage = 1
            } else {
                talks.append(contentsOf: response.talks)
                currentPage = page
            }
            
            hasMorePages = response.hasMore
            applyClientSideFiltering()

            // Cache talks locally
            await cacheTalks(response.talks)

            // Prefetch images for better performance
            let imageURLs = response.talks.compactMap { URL(string: $0.imageURL ?? "") }
            ImageCacheService.shared.prefetchImages(urls: imageURLs)
            
        } catch let apiError as APIError {
            error = apiError
            
            // Try to load cached talks if network failed
            if resetList {
                await loadCachedTalks()
            }
            
        } catch {
            self.error = APIError.networkError(error)
            
            if resetList {
                await loadCachedTalks()
            }
        }
        
        isLoading = false
    }
    
    private func cacheTalks(_ talks: [Talk]) async {
        try? await persistenceController.performBackgroundTask { context in
            for talk in talks {
                // Check if talk already exists
                let request: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", talk.id)
                
                let entity = (try? context.fetch(request).first) ?? TalkEntity(context: context)
                
                // Update entity with talk data
                entity.id = talk.id
                entity.title = talk.title
                entity.desc = talk.description
                entity.speaker = talk.speaker
                entity.series = talk.series
                entity.biblePassage = talk.biblePassage
                entity.dateRecorded = talk.dateRecorded
                entity.duration = Int32(talk.duration)
                entity.audioURL = talk.audioURL
                entity.videoURL = talk.videoURL
                entity.imageURL = talk.imageURL
                entity.fileSize = talk.fileSize ?? 0
                entity.updatedAt = Date()
                
                if entity.createdAt == nil {
                    entity.createdAt = Date()
                }
            }
        }
    }
    
    private func loadCachedTalks() async {
        do {
            let cachedTalks = try await persistenceController.performBackgroundTask { context in
                let request: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
                
                // Apply sorting
                switch self.sortOption {
                case .dateNewest:
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \TalkEntity.dateRecorded, ascending: false)]
                case .dateOldest:
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \TalkEntity.dateRecorded, ascending: true)]
                case .titleAZ:
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \TalkEntity.title, ascending: true)]
                case .titleZA:
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \TalkEntity.title, ascending: false)]
                case .speaker:
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \TalkEntity.speaker, ascending: true)]
                case .series:
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \TalkEntity.series, ascending: true)]
                case .duration:
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \TalkEntity.duration, ascending: false)]
                }
                
                // Apply search filter if present
                if !self.selectedFilters.query.isEmpty {
                    let searchPredicate = NSPredicate(format: "title CONTAINS[cd] %@ OR desc CONTAINS[cd] %@ OR speaker CONTAINS[cd] %@", 
                                                    self.selectedFilters.query, 
                                                    self.selectedFilters.query, 
                                                    self.selectedFilters.query)
                    request.predicate = searchPredicate
                }
                
                request.fetchLimit = 50 // Limit cached results
                
                let entities = try context.fetch(request)
                return entities.compactMap { entity -> Talk? in
                    guard let id = entity.id,
                          let title = entity.title,
                          let speaker = entity.speaker,
                          let dateRecorded = entity.dateRecorded else {
                        return nil
                    }
                    
                    // At least one of audioURL or videoURL should exist
                    guard entity.audioURL != nil || entity.videoURL != nil else {
                        return nil
                    }
                    
                    return Talk(
                        id: id,
                        title: title,
                        description: entity.desc,
                        speaker: speaker,
                        series: entity.series,
                        biblePassage: entity.biblePassage,
                        dateRecorded: dateRecorded,
                        duration: Int(entity.duration),
                        audioURL: entity.audioURL,
                        videoURL: entity.videoURL,
                        imageURL: entity.imageURL,
                        fileSize: entity.fileSize > 0 ? entity.fileSize : nil
                    )
                }
            }
            
            if !cachedTalks.isEmpty {
                talks = cachedTalks
                applyClientSideFiltering()
            }
            
        } catch {
            print("Failed to load cached talks: \(error)")
        }
    }
    
    private func fetchFilterOptions() async {
        isLoadingFilters = true
        
        do {
            let filterOptions = try await filtersAPIService.fetchFilterOptions()
            availableFilters = filterOptions
        } catch {
            print("Failed to load filter options: \(error)")
        }
        
        isLoadingFilters = false
    }
    
    /// Apply client-side filtering to the talks array
    private func applyClientSideFiltering() {
        filteredTalks = talks.filter { talk in
            // Search text filter
            if !selectedFilters.query.isEmpty {
                let searchTerms = selectedFilters.query.lowercased()
                let matchesTitle = talk.title.lowercased().contains(searchTerms)
                let matchesSpeaker = talk.speaker.lowercased().contains(searchTerms)
                let matchesDescription = talk.description?.lowercased().contains(searchTerms) ?? false
                if !(matchesTitle || matchesSpeaker || matchesDescription) {
                    return false
                }
            }
            
            // Conference filter
            if !selectedFilters.conferenceIds.isEmpty {
                if let conferenceId = talk.conferenceId {
                    if !selectedFilters.conferenceIds.contains(conferenceId) {
                        return false
                    }
                } else {
                    return false
                }
            }
            
            // Speaker ID filter (multiple speakers)
            if !selectedFilters.speakerIds.isEmpty {
                if let speakerIds = talk.speakerIds, !speakerIds.isEmpty {
                    let hasMatchingSpeaker = selectedFilters.speakerIds.contains { selectedId in
                        speakerIds.contains(selectedId)
                    }
                    if !hasMatchingSpeaker {
                        return false
                    }
                } else {
                    // Fallback to name-based matching if no IDs available
                    let speakerMatches = selectedFilters.speakerIds.contains { speakerId in
                        talk.speaker.lowercased().contains(speakerId.lowercased())
                    }
                    if !speakerMatches {
                        return false
                    }
                }
            }
            
            // Speaker filter (legacy single speaker)
            if let speakerFilter = selectedFilters.speaker, !speakerFilter.isEmpty {
                if !talk.speaker.lowercased().contains(speakerFilter.lowercased()) {
                    return false
                }
            }
            
            // Series filter (legacy)
            if let seriesFilter = selectedFilters.series, !seriesFilter.isEmpty {
                if let series = talk.series {
                    if !series.lowercased().contains(seriesFilter.lowercased()) {
                        return false
                    }
                } else {
                    return false
                }
            }
            
            // Bible book filter
            if !selectedFilters.bibleBookIds.isEmpty {
                if let bookIds = talk.bookIds, !bookIds.isEmpty {
                    let hasMatchingBook = selectedFilters.bibleBookIds.contains { selectedBookId in
                        bookIds.contains(selectedBookId)
                    }
                    if !hasMatchingBook {
                        return false
                    }
                } else if let biblePassage = talk.biblePassage {
                    // Fallback to passage text matching
                    let passageMatches = selectedFilters.bibleBookIds.contains { bookId in
                        biblePassage.lowercased().contains(bookId.lowercased())
                    }
                    if !passageMatches {
                        return false
                    }
                } else {
                    return false
                }
            }
            
            // Collections filter
            if !selectedFilters.collections.isEmpty {
                // Map collections to series or category - for now use series
                if let series = talk.series {
                    let seriesMatches = selectedFilters.collections.contains { collection in
                        series.lowercased().contains(collection.lowercased())
                    }
                    if !seriesMatches {
                        return false
                    }
                } else {
                    return false
                }
            }
            
            // Year filter
            if !selectedFilters.years.isEmpty {
                let calendar = Calendar.current
                let year = calendar.component(.year, from: talk.dateRecorded)
                let yearString = String(year)
                if !selectedFilters.years.contains(yearString) {
                    return false
                }
            }
            
            // Date range filters
            if let dateFrom = selectedFilters.dateFrom {
                if talk.dateRecorded < dateFrom {
                    return false
                }
            }
            
            if let dateTo = selectedFilters.dateTo {
                if talk.dateRecorded > dateTo {
                    return false
                }
            }
            
            return true
        }
    }
}