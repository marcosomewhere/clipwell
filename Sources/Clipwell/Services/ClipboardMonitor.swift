// Services/ClipboardMonitor.swift
// Clipwell — Monitors the system clipboard for changes.
//
// NSPasteboard does not offer push notifications; polling is the standard approach.
// We use a repeating timer at 0.5s which is imperceptible to users while remaining
// low-CPU. The change count mechanism prevents processing the same content twice,
// including when Clipwell itself writes to the pasteboard.

import AppKit
import Foundation
import OSLog

@MainActor
final class ClipboardMonitor {

    // MARK: - Dependencies

    private let repository: ClipboardRepository
    private let settings: AppSettings
    private let logger = Logger(subsystem: "com.clipwell.app", category: "ClipboardMonitor")

    // MARK: - State

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount

    /// Deadline until which clipboard changes are suppressed.
    /// Using a timestamp instead of a boolean prevents a fast copy from being
    /// swallowed if the user copies something within the same poll window
    /// after Clipwell writes to the clipboard.
    private var suppressUntil: Date = .distantPast

    /// Suppress monitoring for `duration` seconds. Called by PasteService after writing.
    func suppressChanges(for duration: TimeInterval = 0.6) {
        suppressUntil = Date().addingTimeInterval(duration)
    }

    // MARK: - Init

    // No default arguments here — ClipboardRepository.shared and AppSettings.shared
    // are @MainActor-isolated. Default arguments are evaluated at the call site in a
    // nonisolated context, which triggers a Swift 6 error. AppDelegate always passes
    // explicit references so the defaults were unused anyway.
    init(repository: ClipboardRepository, settings: AppSettings) {
        self.repository = repository
        self.settings = settings
    }

    // MARK: - Lifecycle

    func start() {
        guard timer == nil else { return }
        // Initialize the change count so we don't re-process the current clipboard on launch.
        lastChangeCount = NSPasteboard.general.changeCount

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
        timer?.tolerance = 0.1 // Allow OS to coalesce timers for efficiency
        logger.info("Clipboard monitor started.")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        logger.info("Clipboard monitor stopped.")
    }

    // MARK: - Polling

    private func poll() {
        guard !settings.monitoringPaused else { return }

        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        if Date() < suppressUntil {
            logger.debug("Suppressed clipboard change (written by Clipwell).")
            return
        }

        guard let item = buildItem(from: pasteboard) else {
            logger.debug("Clipboard change detected but no supported content found.")
            return
        }

        // Check exclusions
        if let bundleID = item.sourceAppBundleID,
           settings.excludedAppBundleIDs.contains(bundleID) {
            logger.info("Skipped clipboard item from excluded app: \(bundleID)")
            return
        }

        repository.addItem(item)
        logger.debug("Captured clipboard item: \(item.typeLabel)")

        // Kick off background OCR for image items
        if case .image = item.content {
            OCRService.shared.enqueue(item: item)
        }

        // v1.2: Async URL metadata fetch for URL items
        if item.analysis?.detectedURL != nil {
            URLMetadataService.shared.enrich(item: item, in: repository)
        }
    }

    // MARK: - Content Extraction

    private func buildItem(from pasteboard: NSPasteboard) -> ClipboardItem? {
        let (bundleID, appName) = frontmostAppInfo()

        if let image = extractImage(from: pasteboard) {
            return ClipboardItem(content: image,
                                 sourceAppBundleID: bundleID,
                                 sourceAppName: appName)
        }

        if let files = extractFiles(from: pasteboard) {
            return ClipboardItem(content: files,
                                 sourceAppBundleID: bundleID,
                                 sourceAppName: appName)
        }

        if let text = extractText(from: pasteboard) {
            let analysis = buildAnalysis(for: text)
            return ClipboardItem(content: text,
                                 sourceAppBundleID: bundleID,
                                 sourceAppName: appName,
                                 analysis: analysis)
        }

        return nil
    }

    private func extractImage(from pasteboard: NSPasteboard) -> ClipboardContent? {
        guard let image = NSImage(pasteboard: pasteboard),
              image.isValid else { return nil }
        return ImageStore.prepareImageContent(from: image)
    }

    private func extractFiles(from pasteboard: NSPasteboard) -> ClipboardContent? {
        guard let items = pasteboard.readObjects(forClasses: [NSURL.self],
                                                 options: [.urlReadingFileURLsOnly: true]) as? [URL],
              !items.isEmpty else { return nil }
        let refs = items.map { FileReference(url: $0) }
        return .fileReferences(refs)
    }

    private func extractText(from pasteboard: NSPasteboard) -> ClipboardContent? {
        let rtfData = pasteboard.data(forType: .rtf)

        if let plain = pasteboard.string(forType: .string), !plain.isEmpty {
            return .text(plain: plain, rtfData: rtfData)
        }

        if let rtf = rtfData,
           let attributed = NSAttributedString(rtf: rtf, documentAttributes: nil) {
            return .text(plain: attributed.string, rtfData: rtf)
        }

        return nil
    }

    private func buildAnalysis(for content: ClipboardContent) -> ContentAnalysis? {
        guard case .text(let plain, _) = content else { return nil }
        return ContentAnalyzer.analyze(plain)
    }

    // MARK: - App Info

    private func frontmostAppInfo() -> (bundleID: String?, name: String?) {
        let app = NSWorkspace.shared.frontmostApplication
        return (app?.bundleIdentifier, app?.localizedName)
    }
}
