//
//  BlogViewModel.swift
//  PT Resources
//
//  ViewModel for managing blog posts list and functionality
//

import Foundation
import Combine

@MainActor
final class BlogViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var blogPosts: [BlogPost] = []
    @Published var filteredBlogPosts: [BlogPost] = []
    @Published var searchText = ""
    @Published var selectedCategory: String? = nil
    @Published var isLoading = false
    @Published var error: APIError?
    @Published var hasMorePages = true
    @Published var currentOffset = 0

    // MARK: - Private Properties

    private let apiService: BlogAPIServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private let pageSize = 20

    // MARK: - Private Error Handling

    private func setError(_ error: APIError) {
        self.error = error
    }

    // MARK: - Initialization

    init(apiService: BlogAPIServiceProtocol = BlogAPIService()) {
        self.apiService = apiService

        setupBindings()
        loadBlogPosts()
    }

    // MARK: - Public Methods

    func loadBlogPosts() {
        Task {
            await fetchBlogPosts(offset: 0, resetList: true)
        }
    }

    func loadMoreBlogPosts() {
        guard hasMorePages && !isLoading else { return }

        Task {
            await fetchBlogPosts(offset: currentOffset + pageSize, resetList: false)
        }
    }

    func refreshBlogPosts() {
        Task {
            await fetchBlogPosts(offset: 0, resetList: true)
        }
    }

    func searchBlogPosts() {
        applyFilters()
    }

    func setCategory(_ category: String?) {
        selectedCategory = category
        applyFilters()
    }

    func clearFilters() {
        searchText = ""
        selectedCategory = nil
        applyFilters()
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Combine publishers for search and filters
        Publishers.CombineLatest($searchText, $selectedCategory)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)
    }

    private func fetchBlogPosts(offset: Int, resetList: Bool) async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            let response = try await apiService.fetchBlogPosts(limit: pageSize, offset: offset)

            if resetList {
                blogPosts = response.posts
                currentOffset = 0
            } else {
                blogPosts.append(contentsOf: response.posts)
                currentOffset = offset
            }

            hasMorePages = response.hasMore
            applyFilters()

        } catch let apiError as APIError {
            setError(apiError)
        } catch {
            setError(APIError.networkError(error))
        }

        isLoading = false
    }

    private func applyFilters() {
        var filtered = blogPosts

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { post in
                post.title.localizedCaseInsensitiveContains(searchText) ||
                post.excerpt?.localizedCaseInsensitiveContains(searchText) == true ||
                post.author.localizedCaseInsensitiveContains(searchText) ||
                post.category?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        // Apply category filter
        if let category = selectedCategory, !category.isEmpty {
            filtered = filtered.filter { $0.category == category }
        }

        filteredBlogPosts = filtered
    }

    // MARK: - Computed Properties

    var availableCategories: [String] {
        let categories = blogPosts.compactMap { $0.category }.filter { !$0.isEmpty }
        return Array(Set(categories)).sorted()
    }

    var hasActiveFilters: Bool {
        return !searchText.isEmpty || selectedCategory != nil
    }

    var activeFiltersCount: Int {
        var count = 0
        if !searchText.isEmpty { count += 1 }
        if selectedCategory != nil { count += 1 }
        return count
    }
}
