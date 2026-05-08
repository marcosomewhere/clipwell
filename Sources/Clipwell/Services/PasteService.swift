// Services/PasteService.swift
// Clipwell — Restores a ClipboardItem to NSPasteboard and optionally triggers a paste.
//
// Auto-paste is implemented via a CGEvent keystroke (Cmd+V). This requires
// the Accessibility permission (AXIsProcessTrusted). We never trigger the
// macOS permission prompt from the paste path; if trust is missing, Clipwell
// falls back to clipboard-only.

import AppKit
import Carbon
import Foundation
import OSLog

@MainActor
final class PasteService {

    static let shared = PasteService()
    private let logger = Logger(subsystem: "com.clipwell.app", category: "PasteService")

    private init() {}

    // MARK: - Public API

    /// Restores `item` to the system clipboard and auto-pastes if configured.
    /// - Parameter asPlainText: When true, strips all formatting before pasting.
    func select(
        item: ClipboardItem,
        monitor: ClipboardMonitor,
        asPlainText: Bool = false,
        forcePaste: Bool = false,
        targetApp: NSRunningApplication? = nil
    ) {
        monitor.suppressChanges(for: 0.6)
        writeToClipboard(item: item, asPlainText: asPlainText)

        if forcePaste || AppSettings.shared.autoPasteOnSelection {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.simulatePaste(targetApp: targetApp)
            }
        }
    }

    private func writeToClipboard(item: ClipboardItem, asPlainText: Bool = false) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.content {
        case .text(let plain, let rtfData):
            if !asPlainText, let rtf = rtfData {
                pasteboard.setData(rtf, forType: .rtf)
            }
            pasteboard.setString(plain, forType: .string)

        case .image(let pngData, _):
            if asPlainText {
                // Plain text paste of an image: use OCR text if available, else skip
                if let ocr = OCRIndex.shared.text(for: item.id) {
                    pasteboard.setString(ocr, forType: .string)
                }
            } else if let image = NSImage(data: pngData) {
                pasteboard.writeObjects([image])
            }

        case .fileReferences(let refs):
            if asPlainText {
                // Plain text paste of files: comma-separated paths
                let paths = refs.map(\.path).joined(separator: "\n")
                pasteboard.setString(paths, forType: .string)
            } else {
                let urls = refs.map(\.url) as [NSURL]
                pasteboard.writeObjects(urls)
            }
        }

        logger.debug("Wrote to clipboard: \(item.typeLabel)\(asPlainText ? " (plain text)" : "")")
    }

    // MARK: - Auto-Paste

    /// Sends a synthetic Cmd+V to the frontmost application.
    /// Requires Accessibility permission.
    private func simulatePaste(targetApp: NSRunningApplication? = nil) {
        guard AXIsProcessTrusted() else {
            logger.warning("Auto-paste skipped because Accessibility permission is not trusted.")
            return
        }

        if let targetApp, !targetApp.isTerminated {
            targetApp.activate(options: [])
        }

        let source = CGEventSource(stateID: .hidSystemState)

        // Key down
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        // Key up
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)

        logger.debug("Sent synthetic Cmd+V for auto-paste.")
    }

    // MARK: - Accessibility

    func checkAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
