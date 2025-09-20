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
// FilterType enum is now in FilteringService.swift

@MainActor
final class TalksViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var talks: [Talk] = []
    @Published var filteredTalks: [Talk] = []
    @Published var searchText = ""
    @Published var selectedFilters = TalkSearchFilters()
    @Published var isLoading = false
    @Published var error: APIError?
    @Published var hasMorePages = true
    @Published var currentPage = 1
    @Published var selectedSortOption: TalkSortOption = .dateNewest
    
    // MARK: - Filter Properties
    
    @Published var availableFilters: FilterOptions?
    @Published var isLoadingFilters = false
    
    // MARK: - Private Properties
    
    private let apiService: TalksAPIServiceProtocol
    private let filtersAPIService: FiltersAPIServiceProtocol
    private let persistenceController: PersistenceController
    private let filteringService: FilteringService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(apiService: TalksAPIServiceProtocol, filtersAPIService: FiltersAPIServiceProtocol = FiltersAPIService(), persistenceController: PersistenceController = .shared, filteringService: FilteringService? = nil, initialFilters: TalkSearchFilters? = nil) {
        self.apiService = apiService
        self.filtersAPIService = filtersAPIService
        self.persistenceController = persistenceController
        self.filteringService = filteringService ?? FilteringService()
        
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
        
        // Fetch fresh data from API with search query
        // Server-side search will be applied automatically
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
        
        // Fetch fresh data from API with new filters
        // Server-side filtering will be applied automatically
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
        case .topic:
            // Handle topic removal - could clear query or specific topic field
            selectedFilters.query = ""
        case .series:
            selectedFilters.series = nil
        }
        
        Task {
            await fetchTalks(page: 1, resetList: true)
        }
    }
    
    // MARK: - Sort Management Methods
    
    func applySortOption(_ sortOption: TalkSortOption) {
        print("🔄 [TalksViewModel] applySortOption called: \(sortOption)")
        selectedSortOption = sortOption
        
        // Fetch fresh data from API with new sort order
        // Server-side sorting will be applied automatically
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
                sortOption: selectedSortOption
            )
            
            
            if resetList {
                talks = response.talks
                currentPage = 1
            } else {
                let previousCount = talks.count
                talks.append(contentsOf: response.talks)
                currentPage = page
            }
            
            hasMorePages = response.hasMore
            
            // Apply client-side filtering for unsupported filters
            // Server-side sorting is now handled by the API
            applyClientSideFiltering()

            // Cache talks locally
            await cacheTalks(response.talks)

            // Prefetch images for better performance using artworkURL priority
            let imageURLs = response.talks.compactMap { URL(string: $0.artworkURL ?? "") }
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
                entity.conferenceImageURL = talk.conferenceImageURL
                entity.defaultImageURL = talk.defaultImageURL
                entity.fileSize = talk.fileSize ?? 0
                entity.updatedAt = Date()
                
                // Set createdAt if it's nil or the default value (epoch time)
                if entity.createdAt == nil || entity.createdAt?.timeIntervalSince1970 == 0 {
                    entity.createdAt = Date()
                }
            }
        }
    }
    
    private func loadCachedTalks() async {
        do {
            let cachedTalks = try await persistenceController.performBackgroundTask { context in
                let request: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
                
                // Default sorting: newest first
                request.sortDescriptors = [NSSortDescriptor(keyPath: \TalkEntity.dateRecorded, ascending: false)]
                
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
                    guard !entity.id.isEmpty,
                          !entity.title.isEmpty,
                          let speaker = entity.speaker,
                          let dateRecorded = entity.dateRecorded else {
                        return nil
                    }
                    
                    // At least one of audioURL or videoURL should exist
                    guard entity.audioURL != nil || entity.videoURL != nil else {
                        return nil
                    }
                    
                    return Talk(
                        id: entity.id,
                        title: entity.title,
                        description: entity.desc,
                        speaker: speaker,
                        series: entity.series,
                        biblePassage: entity.biblePassage,
                        dateRecorded: dateRecorded,
                        duration: Int(entity.duration),
                        audioURL: entity.audioURL,
                        videoURL: entity.videoURL,
                        imageURL: entity.imageURL,
                        conferenceImageURL: entity.conferenceImageURL,
                        defaultImageURL: entity.defaultImageURL,
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
    
    /// Apply client-side filtering for filters not supported by the API
    /// Server-side filtering and sorting are now handled by the API
    private func applyClientSideFiltering() {
        // Check if we have any client-side only filters that need to be applied
        let hasClientSideFilters = (selectedFilters.series != nil && !selectedFilters.series!.isEmpty) ||
                                   selectedFilters.dateFrom != nil ||
                                   selectedFilters.dateTo != nil
        
        // If no client-side filters are needed, use server results directly (already sorted)
        guard hasClientSideFilters else {
            filteredTalks = talks
            return
        }
        
        // Apply client-side filtering for unsupported filters
        let filtered = talks.filter { talk in
            // Series filter (client-side only - not supported by API)
            if let seriesFilter = selectedFilters.series, !seriesFilter.isEmpty {
                if let series = talk.series {
                    if !series.lowercased().contains(seriesFilter.lowercased()) {
                        return false
                    }
                } else {
                    return false
                }
            }
            
            // Date range filters (not supported by API)
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
        
        // Server-side sorting is already applied, so filtered results maintain sort order
        filteredTalks = filtered
    }
    
}