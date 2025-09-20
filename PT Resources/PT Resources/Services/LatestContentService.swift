//
//  LatestContentService.swift
//  PT Resources
//
//  Service for fetching latest content from PT API
//

import Foundation

// MARK: - Latest Content Service Protocol

protocol LatestContentServiceProtocol {
    func fetchLatestContent() async throws -> LatestContentResponse
}

// MARK: - Latest Content Service

@MainActor
final class LatestContentService: ObservableObject, LatestContentServiceProtocol {
    
    private let session: URLSession
    private let decoder: JSONDecoder
    
    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }
    
    func fetchLatestContent() async throws -> LatestContentResponse {
        // Use mock data if configured
        if Config.useMockServices {
            return await mockFetchLatestContent()
        }
        
        guard let url = URL(string: "https://www.proctrust.org.uk/api/resources/latest") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("PT-Resources-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                break
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
            case 500...599:
                throw APIError.serverError
            default:
                throw APIError.unknown(statusCode: httpResponse.statusCode, data: data)
            }
            
            let latestContent = try decoder.decode(LatestContentResponse.self, from: data)
            return latestContent
            
        } catch let error as APIError {
            throw error
        } catch {
            print("Latest content fetch error: \(error)")
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Mock Implementation
    
    private func mockFetchLatestContent() async -> LatestContentResponse {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        return LatestContentResponse.mockData
    }
}

// MARK: - Mock Service

final class MockLatestContentService: LatestContentServiceProtocol {
    var shouldFail = false
    var mockError: APIError?
    
    func fetchLatestContent() async throws -> LatestContentResponse {
        if shouldFail {
            throw mockError ?? APIError.networkError(NSError(domain: "MockError", code: -1))
        }
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        return LatestContentResponse.mockData
    }
}
