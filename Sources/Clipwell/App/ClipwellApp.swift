// App/ClipwellApp.swift
// Clipwell — App entry point. Zero external package imports.

import SwiftUI

@main
struct ClipwellApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(AppSettings.shared)
                .environmentObject(ClipboardRepository.shared)
        }
        .commands {
            CommandMenu("Werkzeuge") {
                ForEach(ShortcutAction.allCases) { action in
                    Button(action.title) { FeatureCoordinator.shared.perform(action) }
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    NotificationCenter.default.post(name: .clipwellOpenSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
