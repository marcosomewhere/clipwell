// App/AppDelegate.swift
// Clipwell — Application delegate. Wires all services together.
// Zero external package imports.

import AppKit
import OSLog
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    private let repository   = ClipboardRepository.shared
    private let settings     = AppSettings.shared
    private let pasteService = PasteService.shared

    private lazy var monitor = ClipboardMonitor(repository: repository, settings: settings)
    private lazy var hotkeyController = HotkeyController()
    private lazy var menuBarController = MenuBarController(
        repository: repository, pasteService: pasteService, monitor: monitor
    )
    private lazy var overlayPanelController = OverlayPanelController(
        repository: repository, pasteService: pasteService, monitor: monitor
    )

    private var settingsWindow: NSWindow?
    private let logger = Logger(subsystem: "com.clipwell.app", category: "AppDelegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Clipwell launching…")
        NSApp.setActivationPolicy(.accessory)

        menuBarController.setup()

        FeatureCoordinator.shared.configure(repository: repository, monitor: monitor) { [weak self] in
            self?.overlayPanelController.close()
            self?.menuBarController.closePopover()
        }
        hotkeyController.onAction = { [weak self] action in
            if action == .picker { self?.overlayPanelController.toggle() }
            else { FeatureCoordinator.shared.perform(action) }
        }
        hotkeyController.register()

        monitor.start()
        NotificationCenter.default.addObserver(self, selector: #selector(showPicker), name: .clipwellOpenPicker, object: nil)

        NotificationCenter.default.addObserver(
            self, selector: #selector(openSettings),
            name: .clipwellOpenSettings, object: nil
        )

        // Backfill OCR for image items from previous sessions
        Task {
            for item in repository.items {
                if case .image = item.content {
                    OCRService.shared.enqueue(item: item)
                }
                // v1.2: Backfill URL metadata for items that haven't been enriched yet
                if item.effectiveAnalysis?.detectedURL != nil, item.effectiveAnalysis?.urlTitle == nil {
                    URLMetadataService.shared.enrich(item: item, in: repository)
                }
            }
        }

        logger.info("Clipwell ready.")
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        hotkeyController.unregister()
        PersistenceStore.shared.flush()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { overlayPanelController.show() }
        return true
    }

    @objc private func showPicker() { overlayPanelController.show() }

    @objc private func openSettings() {
        if let sceneWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" }) {
            bringSettingsWindowToFront(sceneWindow)
            return
        }
        if let window = settingsWindow {
            bringSettingsWindowToFront(window)
            return
        }

        let settingsView = SettingsView()
            .environmentObject(settings)
            .environmentObject(repository)

        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Clipwell Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 660, height: 420))
        window.level = .normal
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        settingsWindow = window
        bringSettingsWindowToFront(window)
    }

    private func bringSettingsWindowToFront(_ window: NSWindow) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        window.level = .normal
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window.contentView)
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === settingsWindow {
            settingsWindow = nil
        }
    }
}
