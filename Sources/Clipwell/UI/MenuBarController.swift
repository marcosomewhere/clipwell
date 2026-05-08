// UI/MenuBarController.swift
// Clipwell — Manages the menu bar status item and its attached popover.

import AppKit
import SwiftUI

@MainActor
final class MenuBarController {

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var pasteTargetApp: NSRunningApplication?

    private let repository: ClipboardRepository
    private let pasteService: PasteService
    private let monitor: ClipboardMonitor

    init(repository: ClipboardRepository, pasteService: PasteService, monitor: ClipboardMonitor) {
        self.repository = repository
        self.pasteService = pasteService
        self.monitor = monitor
    }

    // MARK: - Setup

    func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = menuBarImage()
            button.image?.isTemplate = true // Respects light/dark menu bar
            button.action = #selector(togglePopover)
            button.target = self
        }
        statusItem = item
    }

    private func menuBarImage() -> NSImage? {
        // Use the bundled template image (must be a 18×18pt PDF/PNG marked as Template).
        // Falls back to the SF Symbol if the asset isn't found (e.g., during SPM builds
        // that haven't yet integrated the asset catalog into a full .app bundle).
        if let asset = NSImage(named: "MenuBarIcon") {
            asset.isTemplate = true
            return asset
        }
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        return NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Clipwell")?
            .withSymbolConfiguration(config)
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        if popover?.isShown == true {
            closePopover()
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        pasteTargetApp = frontmostPasteTarget()
        let p = makePopover()
        popover = p

        guard let button = statusItem?.button else { return }
        p.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Close when clicking outside the popover
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        popover?.performClose(nil)
        popover = nil

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func makePopover() -> NSPopover {
        let popoverView = ClipboardPickerViewFactory.make(
            repository: repository,
            pasteService: pasteService,
            monitor: monitor,
            pasteTargetApp: { [weak self] in self?.pasteTargetApp },
            showsBottomToolbar: true,
            close: { [weak self] in self?.closePopover() }
        )

        let hostingController = NSHostingController(rootView: popoverView)

        let p = NSPopover()
        p.contentViewController = hostingController
        p.behavior = .transient
        p.animates = true
        return p
    }

    private func frontmostPasteTarget() -> NSRunningApplication? {
        let ownBundleID = Bundle.main.bundleIdentifier
        let frontmost = NSWorkspace.shared.frontmostApplication
        guard frontmost?.bundleIdentifier != ownBundleID else { return nil }
        return frontmost
    }
}
