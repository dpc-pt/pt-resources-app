//
//  PT_ResourcesApp.swift
//  PT Resources
//
//  Main app entry point for PT Resources
//

import SwiftUI

@main
struct PT_ResourcesApp: App {
    
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
