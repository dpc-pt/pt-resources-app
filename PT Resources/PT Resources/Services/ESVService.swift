//
//  ESVService.swift
//  PT Resources
//
//  Service for fetching Bible passages from the ESV API
//

import Foundation
import CoreData

@MainActor
class ESVService: ObservableObject {
    
    // MARK: - Private Properties
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let persistenceController: PersistenceController
    private let cache: NSCache<NSString, CachedESVPassage>
    
    // MARK: - Initialization
    
    init(session: URLSession = .shared, persistenceController: PersistenceController = .shared) {
        self.session = session
        self.persistenceController = persistenceController
        self.decoder = JSONDecoder()
        self.cache = NSCache<NSString, CachedESVPassage>()
        
        // Configure cache
        cache.countLimit = 100 // Cache up to 100 passages
    }
    
    // MARK: - Public Methods
    
    @MainActor
    func fetchPassage(reference: String) async throws -> ESVPassage {
        
        let normalizedRef = reference.normalizedBibleReference
        
        // Check memory cache first
        if let cachedPassage = cache.object(forKey: normalizedRef as NSString),
           !cachedPassage.isExpired {
            return cachedPassage.passage
        }
        
        // Check Core Data cache
        if let cachedPassage = try await getCachedPassage(reference: normalizedRef),
           !cachedPassage.isExpired {
            // Update memory cache
            cache.setObject(cachedPassage, forKey: normalizedRef as NSString)
            return cachedPassage.passage
        }
        
        // Use mock data if configured
        if Config.useMockESVService {
            return await mockFetchPassage(reference: normalizedRef)
        }
        
        // Fetch from ESV API
        let passage = try await fetchFromESVAPI(reference: normalizedRef)
        
        // Cache the result
        let cachedPassage = CachedESVPassage(passage: passage)
        cache.setObject(cachedPassage, forKey: normalizedRef as NSString)
        
        try await cachePassage(cachedPassage)
        
        return passage
    }
    
    func getCachedPassages() async throws -> [ESVPassage] {
        return try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<ESVPassageEntity> = ESVPassageEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ESVPassageEntity.cachedAt, ascending: false)]
            
            let entities = try context.fetch(request)
            return entities.compactMap { entity -> ESVPassage? in
                guard let reference = entity.reference,
                      let text = entity.text else {
                    return nil
                }
                
                return ESVPassage(reference: reference, passages: [text])
            }
        }
    }
    
    func clearExpiredCache() async throws {
        let expiredDate = Date().addingTimeInterval(-Config.esvCacheExpiration)
        
        try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<ESVPassageEntity> = ESVPassageEntity.fetchRequest()
            request.predicate = NSPredicate(format: "cachedAt < %@", expiredDate as NSDate)
            
            let expiredEntities = try context.fetch(request)
            for entity in expiredEntities {
                context.delete(entity)
            }
        }
    }
    
    func clearAllCache() async throws {
        cache.removeAllObjects()
        
        try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<ESVPassageEntity> = ESVPassageEntity.fetchRequest()
            let entities = try context.fetch(request)
            
            for entity in entities {
                context.delete(entity)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchFromESVAPI(reference: String) async throws -> ESVPassage {
        
        let request = ESVPassageRequest(reference: reference)
        
        guard var urlComponents = URLComponents(string: "https://api.esv.org/v3/passage/html/") else {
            throw ESVError.invalidURL
        }
        
        urlComponents.queryItems = request.queryItems
        
        guard let url = urlComponents.url else {
            throw ESVError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue(Config.esvAPIKey, forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ESVError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    let esvResponse = try decoder.decode(ESVHTMLResponse.self, from: data)
                    return esvResponse.toESVPassage()
                } catch {
                    throw ESVError.decodingError(error)
                }
                
            case 400:
                throw ESVError.invalidReference
                
            case 401:
                throw ESVError.unauthorized
                
            case 403:
                throw ESVError.rateLimited
                
            case 404:
                throw ESVError.referenceNotFound
                
            default:
                throw ESVError.httpError(httpResponse.statusCode)
            }
            
        } catch {
            if error is ESVError {
                throw error
            } else if error is DecodingError {
                throw ESVError.decodingError(error)
            } else {
                throw ESVError.networkError(error)
            }
        }
    }
    
    private func getCachedPassage(reference: String) async throws -> CachedESVPassage? {
        return try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<ESVPassageEntity> = ESVPassageEntity.fetchRequest()
            request.predicate = NSPredicate(format: "reference == %@", reference)
            request.fetchLimit = 1
            
            guard let entity = try context.fetch(request).first,
                  let cachedAt = entity.cachedAt,
                  let text = entity.text else {
                return nil
            }
            
            let passage = ESVPassage(reference: reference, passages: [text])
            _ = cachedAt.addingTimeInterval(Config.esvCacheExpiration)
            
            return CachedESVPassage(
                passage: passage,
                cacheExpiration: Config.esvCacheExpiration
            )
        }
    }
    
    private func cachePassage(_ cachedPassage: CachedESVPassage) async throws {
        try await persistenceController.performBackgroundTask { context in
            // Check if already cached
            let request: NSFetchRequest<ESVPassageEntity> = ESVPassageEntity.fetchRequest()
            request.predicate = NSPredicate(format: "reference == %@", cachedPassage.passage.reference)
            
            let entity = try context.fetch(request).first ?? ESVPassageEntity(context: context)
            
            entity.reference = cachedPassage.passage.reference
            entity.text = cachedPassage.passage.text
            entity.cachedAt = cachedPassage.cachedAt
        }
    }
    
    func mockFetchPassage(reference: String) async -> ESVPassage {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Return mock passage based on reference
        if let mockPassage = ESVPassage.mockPassages.first(where: { $0.reference.contains(reference) || reference.contains($0.reference) }) {
            return mockPassage
        }
        
        // Return generic mock passage
        return ESVPassage(
            reference: reference,
            passages: [
                "This is a mock Bible passage for \(reference). In the actual implementation, this would contain the real ESV text for the requested reference. The passage would be properly formatted with verse numbers and appropriate line breaks."
            ],
            copyright: "ESV"
        )
    }
}

// MARK: - Error Types

enum ESVError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidReference
    case referenceNotFound
    case unauthorized
    case rateLimited
    case quotaExceeded
    case httpError(Int)
    case networkError(Error)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid ESV API URL"
        case .invalidResponse:
            return "Invalid response from ESV API"
        case .invalidReference:
            return "Invalid Bible reference format"
        case .referenceNotFound:
            return "Bible reference not found"
        case .unauthorized:
            return "Invalid ESV API key"
        case .rateLimited:
            return "ESV API rate limit exceeded - please try again later"
        case .quotaExceeded:
            return "ESV API quota exceeded"
        case .httpError(let code):
            return "ESV API error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        }
    }
    
    var isRateLimited: Bool {
        switch self {
        case .rateLimited, .quotaExceeded:
            return true
        case .httpError(let code):
            return code == 429
        default:
            return false
        }
    }
}

// MARK: - Mock Service for Testing

final class MockESVService: ESVService {
    
    var shouldFail = false
    var mockError: ESVError?
    
    override func fetchPassage(reference: String) async throws -> ESVPassage {
        if shouldFail {
            throw mockError ?? ESVError.networkError(NSError(domain: "MockError", code: -1))
        }
        
        return await mockFetchPassage(reference: reference)
    }
}
