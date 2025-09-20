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
    
    @StateObject private var serviceContainer = ServiceContainer()
    @State private var isShowingSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isShowingSplash {
                    PTSplashScreen()
                        .transition(.opacity)
                } else {
                    ContentView()
                        .withServices(serviceContainer)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: isShowingSplash)
            .task {
                // Setup service container in app delegate
                appDelegate.setServiceContainer(serviceContainer)
                
                // Register PT fonts immediately
                do {
                    try await FontManager.shared.registerFontsAsync()
                } catch {
                    PTLogger.general.error("Font registration failed: \(error)")
                }
                
                // Debug font availability
                #if DEBUG
                PTFontDebugger.shared.debugFonts()
                #endif

                // Start preloading critical data during splash screen
                async let fontRegistration: Void = {
                    // Fonts are already registered above, this is just for timing
                }()
                
                async let downloadPreloading: Void = {
                    // Preload downloaded talks for immediate UI response
                    await serviceContainer.downloadService.preloadDownloadedTalks()
                }()
                
                // Wait for critical preloading to complete
                await fontRegistration
                await downloadPreloading

                // Show splash screen for minimum time (configurable)
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds minimum

                await MainActor.run {
                    withAnimation {
                        isShowingSplash = false
                    }
                }

                // Restore last playback (if any) so mini player is available on launch
                await PlayerService.shared.restoreLastPlaybackIfAvailable()

                // Enable performance monitoring in debug builds
                #if DEBUG
                PerformanceMonitor.shared.enableMonitoring()
                #endif
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    private var serviceContainer: ServiceContainer?
    
    func setServiceContainer(_ container: ServiceContainer) {
        self.serviceContainer = container
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        PTLogger.general.info("App delegate: Application did enter background")
        
        // Notify service container
        serviceContainer?.enterBackground()
        
        // The PlayerService will handle its own background task management via notification observers
        // We just need to ensure the audio session is properly configured
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            PTLogger.general.info("App delegate: Maintained active audio session for background")
        } catch {
            PTLogger.general.error("App delegate: Failed to maintain audio session in background: \(error)")
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        PTLogger.general.info("App delegate: Application will enter foreground")
        
        // Notify service container
        serviceContainer?.becomeActive()
        
        // Reactivate audio session if needed
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            PTLogger.general.info("App delegate: Verified audio session is active for foreground")
        } catch {
            PTLogger.general.error("App delegate: Failed to reactivate audio session on foreground: \(error)")
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        PTLogger.general.info("App delegate: Application will terminate")
        
        // Cleanup all services
        serviceContainer?.cleanup()
        
        PTLogger.general.info("App delegate: Completed cleanup")
    }
}
