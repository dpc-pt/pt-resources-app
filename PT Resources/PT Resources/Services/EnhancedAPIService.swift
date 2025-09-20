//
//  EnhancedAPIService.swift
//  PT Resources
//
//  Enhanced API service with Swift 6 features, async sequences, and modern patterns
//

import Foundation
import Combine

// MARK: - Modern API Service Protocol

protocol ModernAPIServiceProtocol: AnyObject {
    associatedtype ResponseType
    associatedtype ErrorType: Error

    func fetchData() async throws -> ResponseType
    func fetchStream() -> AsyncThrowingStream<ResponseType, ErrorType>
    func sendData(_ data: some Encodable) async throws -> ResponseType
}

// MARK: - API Request Configuration

struct APIRequestConfiguration {
    let baseURL: URL
    let endpoint: String
    let method: HTTPMethod
    let headers: [String: String]
    var body: Data?
    let timeout: TimeInterval
    let retryCount: Int
    let cachePolicy: URLRequest.CachePolicy

    static func get(_ endpoint: String, baseURL: URL = URL(string: Config.proclamationAPIBaseURL)! ) -> Self {
        Self(
            baseURL: baseURL,
            endpoint: endpoint,
            method: .get,
            headers: [:],
            body: nil,
            timeout: 30,
            retryCount: 3,
            cachePolicy: .useProtocolCachePolicy
        )
    }

    static func post(_ endpoint: String, body: Data? = nil, baseURL: URL = URL(string: Config.proclamationAPIBaseURL)! ) -> Self {
        Self(
            baseURL: baseURL,
            endpoint: endpoint,
            method: .post,
            headers: ["Content-Type": "application/json"],
            body: body,
            timeout: 30,
            retryCount: 3,
            cachePolicy: .useProtocolCachePolicy
        )
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"

    var allowsBody: Bool {
        switch self {
        case .get, .delete: return false
        case .post, .put, .patch: return true
        }
    }
}

// MARK: - Response Types

struct APIResponse<T: Decodable> {
    let data: T
    let statusCode: Int
    let headers: [String: String]
    let requestDuration: TimeInterval
    let isFromCache: Bool
}

// MARK: - Modern API Service Implementation

@MainActor
final class ModernAPIService {

    static let shared = ModernAPIService()

    // MARK: - Private Properties

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let requestQueue = DispatchQueue(label: "com.ptresources.api", qos: .userInitiated)

    // MARK: - Initialization

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.httpMaximumConnectionsPerHost = 6

        session = URLSession(configuration: configuration)

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - Public Methods

    func request<T: Decodable>(
        _ configuration: APIRequestConfiguration,
        responseType: T.Type,
        useCache: Bool = true
    ) async throws -> APIResponse<T> {
        let request = try buildURLRequest(from: configuration)

        return try await withTaskCancellationHandler {
            try await performRequest(request, responseType: responseType, useCache: useCache)
        } onCancel: { [endpoint = configuration.endpoint] in
            Task { @MainActor in
                self.cancelRequest(for: endpoint)
            }
        }
    }

    func requestStream<T: Decodable>(
        _ configuration: APIRequestConfiguration,
        responseType: T.Type
    ) -> AsyncThrowingStream<T, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = try await request(configuration, responseType: responseType)
                    continuation.yield(response.data)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func sendData<T: Decodable, U: Encodable>(
        _ data: U,
        to configuration: APIRequestConfiguration,
        responseType: T.Type
    ) async throws -> APIResponse<T> {
        var config = configuration
        config.body = try encoder.encode(data)

        return try await request(config, responseType: responseType)
    }

    func cancelAllRequests() {
        // No-op: use cooperative Task cancellation where appropriate
    }

    func cancelRequest(for endpoint: String) {
        // No-op: cancellation is handled by Task cancellation for async URLSession.data(for:)
    }

    // MARK: - Private Methods

    private func buildURLRequest(from configuration: APIRequestConfiguration) throws -> URLRequest {
        let url = configuration.baseURL.appendingPathComponent(configuration.endpoint)

        var request = URLRequest(url: url)
        request.httpMethod = configuration.method.rawValue
        request.timeoutInterval = configuration.timeout
        request.cachePolicy = configuration.cachePolicy

        // Add headers
        for (key, value) in configuration.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add default headers
        request.setValue("PT Resources/2.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")

        if let body = configuration.body {
            request.httpBody = body
        }

        return request
    }

    private func performRequest<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type,
        useCache: Bool
    ) async throws -> APIResponse<T> {
        let startTime = Date()

        // Check cache first if enabled
        if useCache, let cachedResponse: APIResponse<T> = try? await checkCache(for: request) {
            return cachedResponse
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        let duration = Date().timeIntervalSince(startTime)

        // Handle different status codes
        try validateResponse(httpResponse, data: data)

        let decodedData = try decoder.decode(T.self, from: data)

        let apiResponse: APIResponse<T> = APIResponse(
            data: decodedData,
            statusCode: httpResponse.statusCode,
            headers: httpResponse.allHeaderFields as? [String: String] ?? [:],
            requestDuration: duration,
            isFromCache: false
        )

        // Cache successful responses
        if useCache && httpResponse.statusCode == 200 {
            try? await cacheResponse(data, response: httpResponse, for: request)
        }

        return apiResponse
    }

    private func checkCache<T: Decodable>(for request: URLRequest) async throws -> APIResponse<T>? {
        // Implementation for cache checking
        // This would integrate with your existing cache system
        return nil
    }

    private func cacheResponse(_ data: Data, response: HTTPURLResponse, for request: URLRequest) async throws {
        // Implementation for caching responses
        // This would integrate with your existing cache system
    }

    private func validateResponse(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200...299:
            return
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
            throw APIError.unknown(statusCode: response.statusCode, data: data)
        }
    }
}

// MARK: - Enhanced Error Handling

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case badRequest(Data)
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError
    case unknown(statusCode: Int, data: Data)
    case networkError(Error)
    case decodingError(Error)
    case encodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .badRequest:
            return "Bad request"
        case .unauthorized:
            return "Unauthorized"
        case .forbidden:
            return "Forbidden"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Rate limited"
        case .serverError:
            return "Server error"
        case .unknown(let statusCode, _):
            return "Unknown error (HTTP \(statusCode))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unauthorized:
            return "Please check your authentication"
        case .rateLimited:
            return "Please wait before making another request"
        case .networkError:
            return "Please check your internet connection"
        default:
            return "Please try again later"
        }
    }
}

// MARK: - Retry Mechanism

struct RetryConfiguration {
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let delayMultiplier: Double

    static let `default` = RetryConfiguration(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        delayMultiplier: 2.0
    )
}

extension ModernAPIService {
    func requestWithRetry<T: Decodable>(
        _ configuration: APIRequestConfiguration,
        responseType: T.Type,
        retryConfig: RetryConfiguration = .default
    ) async throws -> APIResponse<T> {
        var lastError: Error?

        for attempt in 1...retryConfig.maxAttempts {
            do {
                return try await request(configuration, responseType: responseType)
            } catch {
                lastError = error

                // Don't retry on certain errors
                if let apiError = error as? APIError {
                    switch apiError {
                    case .unauthorized, .forbidden, .badRequest, .notFound:
                        throw apiError
                    default:
                        break
                    }
                }

                // Wait before retrying
                if attempt < retryConfig.maxAttempts {
                    let delay = min(
                        retryConfig.baseDelay * pow(retryConfig.delayMultiplier, Double(attempt - 1)),
                        retryConfig.maxDelay
                    )

                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? APIError.unknown(statusCode: 0, data: Data())
    }
}

// MARK: - Background Task Support

extension ModernAPIService {
    func performBackgroundRequest<T: Decodable>(
        _ configuration: APIRequestConfiguration,
        responseType: T.Type
    ) async throws -> APIResponse<T> {
        return try await Task.detached(priority: .background) {
            try await self.requestWithRetry(configuration, responseType: responseType)
        }.value
    }
}

// MARK: - Request Deduplication

extension ModernAPIService {
    func deduplicateRequest<T: Decodable>(
        _ configuration: APIRequestConfiguration,
        responseType: T.Type,
        cacheKey: String
    ) async throws -> APIResponse<T> {
        return try await requestWithRetry(configuration, responseType: responseType)
    }
}

// MARK: - Logging and Monitoring

extension ModernAPIService {
    func enableRequestLogging() {
        // This would integrate with your performance monitoring service
        PTLogger.general.info("API request logging enabled")
    }

    func logRequest(_ request: URLRequest, duration: TimeInterval, statusCode: Int) {
        PTLogger.general.info("""
        API Request:
        - URL: \(request.url?.absoluteString ?? "unknown")
        - Method: \(request.httpMethod ?? "unknown")
        - Duration: \(String(format: "%.2f", duration))s
        - Status: \(statusCode)
        """)
    }
}

