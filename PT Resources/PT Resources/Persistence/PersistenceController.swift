//
//  PersistenceController.swift
//  PT Resources
//
//  Core Data persistence controller for managing the data stack
//

import CoreData
import Foundation

final class PersistenceController: ObservableObject {
    
    static let shared = PersistenceController()
    
    /// Preview instance for SwiftUI previews with in-memory store
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        
        // Add sample data for previews
        let sampleTalk = TalkEntity(context: context)
        sampleTalk.id = "sample-1"
        sampleTalk.title = "The Gospel of John"
        sampleTalk.speaker = "John Smith"
        sampleTalk.series = "Gospel Studies"
        sampleTalk.dateRecorded = Date().addingTimeInterval(-86400 * 30) // 30 days ago
        sampleTalk.duration = 1800 // 30 minutes
        sampleTalk.biblePassage = "John 3:16-21"
        sampleTalk.audioURL = "https://example.com/audio/sample-1.mp3"
        sampleTalk.isDownloaded = true
        
        do {
            try context.save()
        } catch {
            print("Preview data creation failed: \(error)")
        }
        
        return controller
    }()
    
    let container: NSPersistentContainer
    
    /// Initialize with option for in-memory store (useful for testing/previews)
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "PTResources")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Enable history tracking for CloudKit sync (future enhancement)
        container.persistentStoreDescriptions.forEach { description in
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                // In production, handle this more gracefully
                #if DEBUG
                fatalError("Core Data failed to load: \(error.localizedDescription)")
                #else
                print("❌ Core Data failed to load: \(error.localizedDescription)")
                // Could show user-friendly error message or fallback to in-memory store
                #endif
            } else {
                print("✅ Core Data loaded successfully: \(description)")
            }
        }
        
        // Enable automatic merging from parent contexts
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Set up background context for imports/exports
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    /// Save the view context
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Save error: \(error)")
            }
        }
    }
    
    /// Create a background context for performing work off the main thread
    func backgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    /// Perform work in a background context
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            let context = backgroundContext()
            context.perform {
                do {
                    let result = try block(context)
                    try context.save()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}