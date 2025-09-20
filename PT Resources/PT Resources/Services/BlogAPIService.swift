//
//  BlogAPIService.swift
//  PT Resources
//
//  Service for fetching blog posts from the Proclamation Trust API
//

import Foundation
import Combine

protocol BlogAPIServiceProtocol {
    func fetchBlogPosts(limit: Int, offset: Int) async throws -> BlogPostsResponse
    func fetchBlogPostDetail(id: String) async throws -> BlogPost
}

final class BlogAPIService: BlogAPIServiceProtocol, ObservableObject {

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()

        // Configure date decoding
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM yyyy"
        decoder.dateDecodingStrategy = .formatted(formatter)
    }

    // MARK: - API Methods

    func fetchBlogPosts(limit: Int = 100, offset: Int = 0) async throws -> BlogPostsResponse {

        // Use mock data if configured
        if Config.useMockServices {
            return await mockFetchBlogPosts(limit: limit, offset: offset)
        }

        let endpoint = Config.APIEndpoint.blogPosts(limit: limit, offset: offset)

        guard let url = URL(string: endpoint.url) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                switch httpResponse.statusCode {
                case 400:
                    throw APIError.badRequest(data)
                case 401:
                    throw APIError.unauthorized
                case 403:
                    throw APIError.forbidden
                case 404:
                    throw APIError.notFound
                case 429:
                    throw APIError.rateLimited
                case 500...:
                    throw APIError.serverError
                default:
                    throw APIError.unknown(statusCode: httpResponse.statusCode, data: data)
                }
            }

            let blogResponse = try decoder.decode(BlogPostsResponse.self, from: data)
            return blogResponse

        } catch {
            if error is APIError {
                throw error
            } else {
                throw APIError.networkError(error)
            }
        }
    }

    func fetchBlogPostDetail(id: String) async throws -> BlogPost {

        // Use mock data if configured
        if Config.useMockServices {
            return await mockFetchBlogPostDetail(id: id)
        }

        let endpoint = Config.APIEndpoint.blogPostDetail(id: id)

        guard let url = URL(string: endpoint.url) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                switch httpResponse.statusCode {
                case 400:
                    throw APIError.badRequest(data)
                case 401:
                    throw APIError.unauthorized
                case 403:
                    throw APIError.forbidden
                case 404:
                    throw APIError.notFound
                case 429:
                    throw APIError.rateLimited
                case 500...:
                    throw APIError.serverError
                default:
                    throw APIError.unknown(statusCode: httpResponse.statusCode, data: data)
                }
            }

            let blogPost = try decoder.decode(BlogPost.self, from: data)
            return blogPost

        } catch {
            if error is APIError {
                throw error
            } else {
                throw APIError.networkError(error)
            }
        }
    }
}

// MARK: - Mock Implementation

extension BlogAPIService {

    private func mockFetchBlogPosts(limit: Int, offset: Int) async -> BlogPostsResponse {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        let mockPosts = BlogPost.mockBlogPosts
        let totalPosts = mockPosts.count
        let hasMore = offset + limit < totalPosts

        return BlogPostsResponse(
            posts: Array(mockPosts.prefix(limit)),
            total: totalPosts,
            limit: limit,
            offset: offset,
            hasMore: hasMore
        )
    }

    private func mockFetchBlogPostDetail(id: String) async -> BlogPost {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        return BlogPost.mockBlogPosts.first { $0.id == id } ?? BlogPost.mockBlogPosts.first!
    }
}

// MARK: - Mock Service for Testing

final class MockBlogAPIService: BlogAPIServiceProtocol {

    var shouldFail = false
    var mockBlogPosts = BlogPost.mockBlogPosts

    func fetchBlogPosts(limit: Int, offset: Int) async throws -> BlogPostsResponse {
        if shouldFail {
            throw APIError.serverError
        }

        return BlogPostsResponse(
            posts: mockBlogPosts,
            total: mockBlogPosts.count,
            limit: limit,
            offset: offset,
            hasMore: false
        )
    }

    func fetchBlogPostDetail(id: String) async throws -> BlogPost {
        if shouldFail {
            throw APIError.notFound
        }

        return mockBlogPosts.first { $0.id == id } ?? mockBlogPosts.first!
    }
}
