//
//  ResourceDetailService.swift
//  PT Resources
//
//  Service for fetching individual resource details from PT API
//

import Foundation

// MARK: - Resource Detail Service Protocol

protocol ResourceDetailServiceProtocol {
    func fetchResourceDetail(id: String) async throws -> ResourceDetailResponse
}

// MARK: - Resource Detail Service

@MainActor
final class ResourceDetailService: ObservableObject, ResourceDetailServiceProtocol {
    
    private let session: URLSession
    private let decoder: JSONDecoder
    
    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }
    
    func fetchResourceDetail(id: String) async throws -> ResourceDetailResponse {
        // Use mock data if configured
        if Config.useMockServices {
            return await mockFetchResourceDetail(id: id)
        }
        
        guard let url = URL(string: "https://www.proctrust.org.uk/api/resources/\(id)") else {
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
            
            let resourceDetail = try decoder.decode(ResourceDetailResponse.self, from: data)
            return resourceDetail
            
        } catch let error as APIError {
            throw error
        } catch {
            print("Resource detail fetch error: \(error)")
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Mock Implementation
    
    private func mockFetchResourceDetail(id: String) async -> ResourceDetailResponse {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        return ResourceDetailResponse.mockData
    }
}

// MARK: - Mock Service

final class MockResourceDetailService: ResourceDetailServiceProtocol {
    var shouldFail = false
    var mockError: APIError?
    
    func fetchResourceDetail(id: String) async throws -> ResourceDetailResponse {
        if shouldFail {
            throw mockError ?? APIError.networkError(NSError(domain: "MockError", code: -1))
        }
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        return ResourceDetailResponse.mockData
    }
}
