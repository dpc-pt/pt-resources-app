//
//  PT_ResourcesApp.swift
//  PT Resources
//
//  Main app entry point for PT Resources
//

import SwiftUI
import AVFoundation
import UIKit

@main
struct PT_ResourcesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    let persistenceController = PersistenceController.shared
    @State private var isShowingSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isShowingSplash {
                    PTSplashScreen()
                        .transition(.opacity)
                } else {
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: isShowingSplash)
            .task {
                // Register PT fonts immediately
                do {
                    try await FontManager.shared.registerFontsAsync()
                } catch {
                    print("⚠️ Font registration failed: \(error)")
                }
                
                // Debug font availability
                #if DEBUG
                PTFontDebugger.shared.debugFonts()
                #endif

                // Show splash screen for 2-3 seconds (configurable)
                try? await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 seconds

                await MainActor.run {
                    withAnimation {
                        isShowingSplash = false
                    }
                }
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func applicationDidEnterBackground(_ application: UIApplication) {
        // When app goes to background, ensure background task and audio session are active
        Task { @MainActor in
            let playerService = PlayerService.shared
            if playerService.playbackState == .playing || playerService.playbackState == .paused {
                // Ensure background task is active for background playback
                playerService.startBackgroundTask()
                
                // Keep audio session active for continued playback and lock screen controls
                do {
                    try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                    print("App entered background - maintained active audio session and background task")
                } catch {
                    print("Failed to maintain audio session in background: \(error)")
                }
            }
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // When app comes back to foreground, ensure audio session is still active
        Task { @MainActor in
            let playerService = PlayerService.shared
            if playerService.playbackState == .playing || playerService.playbackState == .paused {
                // Ensure audio session is still active
                do {
                    try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                    print("App entered foreground - verified audio session is active")
                } catch {
                    print("Failed to reactivate audio session on foreground: \(error)")
                }
            }
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Clean up when app terminates
        Task { @MainActor in
            PlayerService.shared.stop()
        }
        print("App terminating - cleaned up audio resources")
    }
}
