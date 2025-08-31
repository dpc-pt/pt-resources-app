//
//  ConferencesViewModel.swift
//  PT Resources
//
//  ViewModel for managing conferences list and search functionality
//

import Foundation
import Combine

@MainActor
final class ConferencesViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var conferences: [ConferenceInfo] = []
    @Published var filteredConferences: [ConferenceInfo] = []
    @Published var searchText = ""
    @Published var selectedFilters = ConferenceSearchFilters()
    @Published var isLoading = false
    @Published var error: APIError?
    @Published var hasMorePages = true
    @Published var currentPage = 1
    
    // MARK: - Private Properties
    
    private let apiService: ConferencesAPIServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(apiService: ConferencesAPIServiceProtocol = ConferencesAPIService()) {
        self.apiService = apiService
        
        setupBindings()
        loadConferences()
    }
    
    // MARK: - Public Methods
    
    func loadConferences() {
        Task {
            await fetchConferences(page: 1, resetList: true)
        }
    }
    
    func loadMoreConferences() {
        guard !isLoading && hasMorePages else { return }
        
        Task {
            await fetchConferences(page: currentPage + 1, resetList: false)
        }
    }
    
    func refreshConferences() {
        Task {
            await fetchConferences(page: 1, resetList: true)
        }
    }
    
    func searchConferences() {
        selectedFilters.query = searchText
        
        // For search queries under 3 characters, only apply client-side filtering
        if !searchText.isEmpty && searchText.count < 3 {
            applyClientSideFiltering()
            return
        }
        
        // For valid search queries, fetch from API (server-side filtering is more efficient)
        Task {
            await fetchConferences(page: 1, resetList: true)
        }
    }
    
    func clearSearch() {
        searchText = ""
        selectedFilters = ConferenceSearchFilters()
        loadConferences()
    }
    
    func applyFilters(_ filters: ConferenceSearchFilters) {
        selectedFilters = filters
        
        // Fetch fresh data from API (more efficient than double-filtering)
        Task {
            await fetchConferences(page: 1, resetList: true)
        }
    }
    
    func filterByYear(_ year: String) {
        selectedFilters.addYear(year)
        applyFilters(selectedFilters)
    }
    
    func removeYearFilter(_ year: String) {
        selectedFilters.removeYear(year)
        applyFilters(selectedFilters)
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Auto-search when text changes (with debounce)
        $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.searchConferences()
            }
            .store(in: &cancellables)
    }
    
    private func fetchConferences(page: Int, resetList: Bool) async {
        isLoading = true
        error = nil
        
        do {
            let response = try await apiService.fetchConferences(
                filters: selectedFilters,
                page: page
            )
            
            if resetList {
                conferences = response.conferences
                currentPage = 1
            } else {
                conferences.append(contentsOf: response.conferences)
                currentPage = page
            }
            
            hasMorePages = response.hasMore
            applyClientSideFiltering()

            // Prefetch images for better performance
            let imageURLs = response.conferences.compactMap { 
                if let artworkURL = $0.artworkURL {
                    return URL(string: artworkURL)
                }
                return nil
            }
            ImageCacheService.shared.prefetchImages(urls: imageURLs)
            
        } catch let apiError as APIError {
            error = apiError
            PTLogger.general.error("Failed to fetch conferences: \(apiError.localizedDescription)")
            
        } catch {
            self.error = APIError.networkError(error)
            PTLogger.general.error("Unexpected error fetching conferences: \(error)")
        }
        
        isLoading = false
    }
    
    /// Apply client-side filtering to the conferences array
    private func applyClientSideFiltering() {
        let filtered = conferences.filter { conference in
            // Search text filter
            if !selectedFilters.query.isEmpty {
                let searchTerms = selectedFilters.query.lowercased()
                let matchesTitle = conference.title.lowercased().contains(searchTerms)
                let matchesYear = conference.year.lowercased().contains(searchTerms)
                let matchesDescription = conference.description?.lowercased().contains(searchTerms) ?? false
                if !(matchesTitle || matchesYear || matchesDescription) {
                    return false
                }
            }
            
            // Year filter
            if !selectedFilters.years.isEmpty {
                if !selectedFilters.years.contains(conference.year) {
                    return false
                }
            }
            
            // Single year filter (legacy)
            if let yearFilter = selectedFilters.year, !yearFilter.isEmpty {
                if conference.year != yearFilter {
                    return false
                }
            }
            
            return true
        }
        
        // Sort conferences: most recent first
        filteredConferences = filtered.sorted { $0.year > $1.year }
    }
    
    // MARK: - Conference Detail Methods
    
    func fetchConferenceDetail(id: String) async -> ConferenceInfo? {
        do {
            let conference = try await apiService.fetchConferenceDetail(id: id)
            return conference
        } catch {
            self.error = error as? APIError ?? APIError.networkError(error)
            return nil
        }
    }
    
    func fetchConferenceResources(conferenceId: String, page: Int = 1) async -> TalksResponse? {
        do {
            let response = try await apiService.fetchConferenceResources(conferenceId: conferenceId, page: page)
            return response
        } catch {
            self.error = error as? APIError ?? APIError.networkError(error)
            return nil
        }
    }
    
    // MARK: - Utility Methods
    
    /// Get unique years from the conferences for filtering
    var availableYears: [String] {
        let years = conferences.map { $0.year }
        return Array(Set(years)).sorted(by: >)
    }
    
    /// Get conferences grouped by year
    var conferencesGroupedByYear: [(year: String, conferences: [ConferenceInfo])] {
        let grouped = Dictionary(grouping: filteredConferences) { $0.year }
        return grouped.map { (year: $0.key, conferences: $0.value) }
                     .sorted { $0.year > $1.year }
    }
}