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
    
    // MARK: - Private Properties
    
    private let apiService: TalksAPIServiceProtocol
    private let persistenceController: PersistenceController
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(apiService: TalksAPIServiceProtocol, persistenceController: PersistenceController = .shared) {
        self.apiService = apiService
        self.persistenceController = persistenceController
        
        setupBindings()
        loadTalks()
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
        Task {
            selectedFilters.query = searchText
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
            filteredTalks = talks

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
                          let audioURL = entity.audioURL,
                          let dateRecorded = entity.dateRecorded else {
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
                        audioURL: audioURL,
                        imageURL: entity.imageURL,
                        fileSize: entity.fileSize > 0 ? entity.fileSize : nil
                    )
                }
            }
            
            if !cachedTalks.isEmpty {
                talks = cachedTalks
                filteredTalks = cachedTalks
            }
            
        } catch {
            print("Failed to load cached talks: \(error)")
        }
    }
}