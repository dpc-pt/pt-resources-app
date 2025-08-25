//
//  APITester.swift
//  PT Resources
//
//  Utility for testing the actual Proclamation Trust API endpoints
//

import Foundation

#if DEBUG
/// Development utility for testing the actual Proclamation Trust API
/// This helps developers understand the API structure and response format
final class APITester {
    
    private let session = URLSession.shared
    
    /// Test the main resources endpoint to understand response structure
    func testResourcesEndpoint() async {
        print("🔍 Testing Proclamation Trust API...")
        print("Base URL: \(Config.proclamationAPIBaseURL)")
        
        // Test main resources endpoint
        await testEndpoint(Config.APIEndpoint.resources(), description: "Main Resources")
        
        // Test latest endpoint  
        await testEndpoint(Config.APIEndpoint.latest, description: "Latest Resources")
        
        // Test filters endpoint
        await testEndpoint(Config.APIEndpoint.filters, description: "Available Filters")
        
        // Test stats endpoint
        await testEndpoint(Config.APIEndpoint.stats, description: "API Statistics")
        
        // Test blog posts endpoint
        await testEndpoint(Config.APIEndpoint.blogPosts, description: "Blog Posts")
        
        print("✅ API testing complete")
    }
    
    /// Test a specific resource by ID (you'll need to provide a valid ID)
    func testResourceDetail(id: String) async {
        await testEndpoint(Config.APIEndpoint.resourceDetail(id: id), description: "Resource Detail (\(id))")
    }
    
    private func testEndpoint(_ endpoint: Config.APIEndpoint, description: String) async {
        print("\n📡 Testing: \(description)")
        print("URL: \(endpoint.url)")
        
        guard let url = URL(string: endpoint.url) else {
            print("❌ Invalid URL")
            return
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Status: \(httpResponse.statusCode)")
                
                // Print response headers that might be useful
                if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") {
                    print("Content-Type: \(contentType)")
                }
            }
            
            // Try to parse as JSON to understand structure
            if let jsonObject = try? JSONSerialization.jsonObject(with: data),
               let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                
                print("Response Sample:")
                // Print first 500 characters to avoid overwhelming output
                let preview = String(jsonString.prefix(500))
                print(preview)
                if jsonString.count > 500 {
                    print("... (truncated)")
                }
            } else {
                print("Response Size: \(data.count) bytes")
                print("Raw Preview: \(String(data: data.prefix(200), encoding: .utf8) ?? "Non-UTF8 data")")
            }
            
        } catch {
            print("❌ Error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Usage Example

extension APITester {
    
    /// Example usage for developers
    static func runAPITests() {
        guard Config.isDebugMode else {
            print("API testing only available in debug mode")
            return
        }
        
        let tester = APITester()
        
        Task {
            await tester.testResourcesEndpoint()
            
            // Uncomment and add a real resource ID to test detail endpoint
            // await tester.testResourceDetail(id: "your-resource-id-here")
        }
    }
}
#endif