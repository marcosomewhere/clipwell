// UI/OverlayPanelController.swift
// Clipwell — A floating NSPanel that shows the clipboard picker when the hotkey fires.
//
// Design rationale: We use a raw NSPanel (not SwiftUI WindowGroup) because:
//  - It can appear above all other apps without the app becoming frontmost
//  - We can control its level, style, and dismiss behavior precisely
//  - NSPanel with .nonactivatingPanel behaves like Spotlight / Alfred

import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class OverlayPanelController {

    private var panel: NSPanel?
    private var keyMonitor: Any?
    private var outsideClickMonitor: Any?
    private var pasteTargetApp: NSRunningApplication?
    private let repository: ClipboardRepository
    private let pasteService: PasteService
    private let monitor: ClipboardMonitor

    init(repository: ClipboardRepository, pasteService: PasteService, monitor: ClipboardMonitor) {
        self.repository = repository
        self.pasteService = pasteService
        self.monitor = monitor
    }

    // MARK: - Show / Hide

    func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    func show() {
        pasteTargetApp = frontmostPasteTarget()
        if panel == nil {
            buildPanel()
        }
        positionPanelNearCursor()
        installKeyMonitor()
        installOutsideClickMonitor()
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
        panel?.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            NotificationCenter.default.post(name: .clipwellFocusSearch, object: nil)
        }
    }

    func close() {
        panel?.orderOut(nil)
        removeKeyMonitor()
        removeOutsideClickMonitor()
        // Nil out the panel so it is rebuilt fresh on the next show().
        // This resets all SwiftUI state (search text, selection) automatically —
        // the correct behaviour for a transient picker overlay.
        panel = nil
    }

    // MARK: - Panel Construction

    private func buildPanel() {
        let overlayView = ClipboardPickerViewFactory.make(
            repository: repository,
            pasteService: pasteService,
            monitor: monitor,
            pasteTargetApp: { [weak self] in self?.pasteTargetApp },
            showsBottomToolbar: false,
            close: { [weak self] in self?.close() }
        )

        let hostingView = NSHostingView(rootView: overlayView)
        hostingView.autoresizingMask = [.width, .height]

        let contentRect = NSRect(x: 0, y: 0, width: 380, height: 520)
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]

        let newPanel = EscapeHandlingPanel(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        newPanel.onEscape = { [weak self] in self?.close() }
        newPanel.level = .floating
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = true
        newPanel.isFloatingPanel = true
        newPanel.becomesKeyOnlyIfNeeded = false
        newPanel.hidesOnDeactivate = false
        newPanel.contentView = hostingView

        // Dismiss when clicking outside
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        panel = newPanel
    }

    private func positionPanelNearCursor() {
        guard let panel else { return }

        let cursorLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(cursorLocation) } ?? NSScreen.main
        guard let screen else { return }

        let visibleFrame = screen.visibleFrame
        let panelFrame = panel.frame
        let rawX = cursorLocation.x - panelFrame.width / 2
        let rawY = cursorLocation.y - panelFrame.height / 2
        let x = min(max(rawX, visibleFrame.minX + 8), visibleFrame.maxX - panelFrame.width - 8)
        let y = min(max(rawY, visibleFrame.minY + 8), visibleFrame.maxY - panelFrame.height - 8)

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == UInt16(kVK_Escape) else { return event }
            self?.close()
            return nil
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                guard let self, let panel = self.panel, panel.isVisible else { return }
                if !panel.frame.contains(NSEvent.mouseLocation) {
                    self.close()
                }
            }
        }
    }

    private func removeOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    private func frontmostPasteTarget() -> NSRunningApplication? {
        let ownBundleID = Bundle.main.bundleIdentifier
        let frontmost = NSWorkspace.shared.frontmostApplication
        guard frontmost?.bundleIdentifier != ownBundleID else { return nil }
        return frontmost
    }

    @objc private func applicationDidResignActive() {
        close()
    }
}

private final class EscapeHandlingPanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == UInt16(kVK_Escape) else {
            super.keyDown(with: event)
            return
        }
        onEscape?()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let clipwellOpenSettings = Notification.Name("clipwellOpenSettings")
    static let clipwellFocusSearch = Notification.Name("clipwellFocusSearch")
}
