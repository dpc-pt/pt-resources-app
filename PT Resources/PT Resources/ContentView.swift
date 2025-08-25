//
//  ContentView.swift
//  PT Resources
//
//  Main content view with beautiful tab navigation
//

import SwiftUI

struct ContentView: View {
    
    var body: some View {
        MainTabView()
    }
}

// MARK: - Placeholder Views

struct DownloadsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Downloads")
                    .font(.largeTitle)
                    .padding()

                Text("Downloaded talks will appear here")
                    .foregroundColor(.secondary)

                Spacer()
            }
            .navigationTitle("Downloads")
        }
    }
}

struct SettingsView: View {
    @State private var showingPrivacySettings = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Playback") {
                    HStack {
                        Text("Default Speed")
                        Spacer()
                        Text("1.0x")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Skip Interval")
                        Spacer()
                        Text("30 seconds")
                            .foregroundColor(.secondary)
                    }
                }

                Section("Storage") {
                    HStack {
                        Text("Auto-delete after")
                        Spacer()
                        Text("90 days")
                            .foregroundColor(.secondary)
                    }
                }

                Section("Privacy & Data") {
                    Button(action: { showingPrivacySettings = true }) {
                        HStack {
                            Text("Privacy Settings")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.ptMediumGray)
                        }
                    }
                    .accessibilityHint("Manage your privacy, export or delete data")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPrivacySettings) {
                PrivacySettingsView()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
