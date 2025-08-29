import Foundation
import Combine

/// Service for handling Vimeo API interactions
class VimeoSDKService: ObservableObject {
    static let shared = VimeoSDKService()
    
    private let baseURL = "https://api.vimeo.com"
    private let oembedURL = "https://vimeo.com/api/oembed.json"
    
    private init() {}
    
    /// Check if a Vimeo video is accessible using the oEmbed API
    /// This is more reliable than direct video URL validation for domain-restricted videos
    func isVideoAccessible(videoID: String) async -> Bool {
        let oembedURLString = "\(oembedURL)?url=https://vimeo.com/\(videoID)"
        
        guard let url = URL(string: oembedURLString) else {
            PTLogger.general.error("Invalid Vimeo oEmbed URL")
            return false
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                PTLogger.general.error("Invalid HTTP response from Vimeo API")
                return false
            }
            
            // Check if the video is accessible
            if httpResponse.statusCode == 200 {
                // Try to parse the response to confirm it's a valid video
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let _ = json["title"] as? String {
                    PTLogger.general.info("Vimeo video \(videoID) is accessible")
                    return true
                }
            } else if httpResponse.statusCode == 404 {
                PTLogger.general.warning("Vimeo video \(videoID) not found")
                return false
            } else if httpResponse.statusCode == 403 {
                PTLogger.general.warning("Vimeo video \(videoID) has domain restrictions")
                return false
            }
            
            PTLogger.general.error("Vimeo API returned status code: \(httpResponse.statusCode)")
            return false
            
        } catch {
            PTLogger.general.error("Error checking Vimeo video accessibility: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Get video metadata using the oEmbed API
    func getVideoMetadata(videoID: String) async -> VimeoVideoMetadata? {
        let oembedURLString = "\(oembedURL)?url=https://vimeo.com/\(videoID)"
        
        guard let url = URL(string: oembedURLString) else {
            PTLogger.general.error("Invalid Vimeo oEmbed URL")
            return nil
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                PTLogger.general.error("Failed to get Vimeo video metadata")
                return nil
            }
            
            let decoder = JSONDecoder()
            let metadata = try decoder.decode(VimeoVideoMetadata.self, from: data)
            return metadata
            
        } catch {
            PTLogger.general.error("Error getting Vimeo video metadata: \(error.localizedDescription)")
            return nil
        }
    }
}

/// Metadata structure for Vimeo videos from oEmbed API
struct VimeoVideoMetadata: Codable {
    let type: String
    let version: String
    let providerName: String
    let providerURL: String
    let title: String
    let authorName: String?
    let authorURL: String?
    let isPlus: String?
    let html: String
    let width: Int
    let height: Int
    let duration: Int?
    let description: String?
    let thumbnailURL: String?
    let thumbnailWidth: Int?
    let thumbnailHeight: Int?
    let thumbnailURLWithPlayButton: String?
    let uploadDate: String?
    let videoID: Int
    let uri: String
    
    enum CodingKeys: String, CodingKey {
        case type, version, title, html, width, height, duration, description, uri
        case providerName = "provider_name"
        case providerURL = "provider_url"
        case authorName = "author_name"
        case authorURL = "author_url"
        case isPlus = "is_plus"
        case thumbnailURL = "thumbnail_url"
        case thumbnailWidth = "thumbnail_width"
        case thumbnailHeight = "thumbnail_height"
        case thumbnailURLWithPlayButton = "thumbnail_url_with_play_button"
        case uploadDate = "upload_date"
        case videoID = "video_id"
    }
}
