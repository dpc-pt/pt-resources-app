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
    private var serviceContainer: ServiceContainer?
    
    func setServiceContainer(_ container: ServiceContainer) {
        self.serviceContainer = container
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        serviceContainer?.enterBackground()
        
        // Handle background audio session
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            PTLogger.general.info("App entered background - maintained active audio session")
        } catch {
            PTLogger.general.error("Failed to maintain audio session in background: \(error)")
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        serviceContainer?.becomeActive()
        
        // Handle foreground audio session
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            PTLogger.general.info("App entered foreground - verified audio session is active")
        } catch {
            PTLogger.general.error("Failed to reactivate audio session on foreground: \(error)")
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        serviceContainer?.cleanup()
        PTLogger.general.info("App terminating - cleaned up resources")
    }
}
