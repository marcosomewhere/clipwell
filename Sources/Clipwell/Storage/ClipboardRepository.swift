// Storage/ClipboardRepository.swift
// Clipwell — The authoritative in-memory store for clipboard history.
//
// All mutations go through this class. It owns persistence and publishes
// changes to SwiftUI views via @Published.

import Combine
import Foundation
import OSLog

@MainActor
final class ClipboardRepository: ObservableObject {

    static let shared = ClipboardRepository()

    // MARK: - Published State

    /// Full history, pinned items first, then newest-first.
    @Published private(set) var items: [ClipboardItem] = []

    // MARK: - Private

    private let persistence = PersistenceStore.shared
    private let settings = AppSettings.shared
    private let logger = Logger(subsystem: "com.clipwell.app", category: "Repository")

    private init() {
        items = persistence.loadHistory()
        compactDuplicateTextItemsIfNeeded()
        logger.info("Repository initialized with \(self.items.count) items.")
    }

    // MARK: - Queries

    func search(query: String) -> [ClipboardItem] {
        guard !query.isEmpty else { return items }
        let lowered = query.lowercased()
        return items.filter { item in
            if item.searchableText.lowercased().contains(lowered) { return true }
            if item.displayTypeLabel.lowercased().contains(lowered) { return true }
            // v1.2: Also search URL titles
            if let title = item.effectiveAnalysis?.urlTitle, title.lowercased().contains(lowered) { return true }
            // OCR text for image items
            if case .image = item.content {
                return OCRIndex.shared.matches(itemID: item.id, query: query)
            }
            return false
        }
    }

    // MARK: - Mutations

    /// Called by ClipboardMonitor when a new clipboard change is detected.
    func addItem(_ item: ClipboardItem) {
        if refreshDuplicateTextItem(with: item) {
            return
        }

        let mode = settings.duplicateHandling

        switch mode {
        case .keepAll:
            break

        case .collapseConsecutive:
            if let latest = items.first(where: { !$0.isPinned }),
               latest.hasSameContent(as: item) {
                return
            }

        case .deduplicateGlobal:
            items.removeAll { $0.hasSameContent(as: item) && !$0.isPinned }
        }

        let insertIndex = items.firstIndex(where: { !$0.isPinned }) ?? items.endIndex
        items.insert(item, at: insertIndex)

        enforceCapacity()
        persist()
    }

    func removeItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        OCRIndex.shared.remove(itemID: item.id)
        persist()
    }

    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        sortItems()
        persist()
    }

    func refreshItem(_ item: ClipboardItem) -> ClipboardItem {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return item
        }

        items[index].capturedAt = Date()
        sortItems()
        persist()
        return items.first(where: { $0.id == item.id }) ?? item
    }

    /// v1.2: Replaces the text content of an item (user edited it).
    func updateText(for itemID: UUID, newText: String) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        // Strip RTF — edited items are always plain text
        items[index].content = .text(plain: newText, rtfData: nil)
        // Re-analyse the new content
        items[index].analysis = ContentAnalyzer.analyze(newText)
        items[index].analysis?.isEditedByUser = true
        persist()
    }

    /// v1.2: Updates analysis metadata (URL title/favicon) without touching content.
    func updateAnalysis(for itemID: UUID, mutation: (inout ContentAnalysis) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        var analysis = items[index].analysis ?? .empty
        mutation(&analysis)
        items[index].analysis = analysis
        persist()
    }

    func clearUnpinnedHistory() {
        items.removeAll { !$0.isPinned }
        persist()
        persistence.cleanupOrphanedImages(referencedIDs: Set(items.map(\.id)))
    }

    func clearAll() {
        let allIDs = Set(items.map(\.id))
        items.removeAll()
        persist()
        allIDs.forEach { OCRIndex.shared.remove(itemID: $0) }
        persistence.cleanupOrphanedImages(referencedIDs: [])
    }

    // MARK: - Private Helpers

    private func enforceCapacity() {
        let max = settings.maxHistoryCount
        let pinned = items.filter(\.isPinned)
        var unpinned = items.filter { !$0.isPinned }

        if unpinned.count > max {
            unpinned = Array(unpinned.prefix(max))
        }

        // Pinned always come first, then unpinned newest-first
        items = pinned + unpinned
    }

    private func refreshDuplicateTextItem(with newItem: ClipboardItem) -> Bool {
        guard let newText = newItem.content.normalizedPlainText,
              let index = items.firstIndex(where: { existing in
                  existing.content.normalizedPlainText == newText
              }) else {
            return false
        }

        let existingID = items[index].id
        let wasPinned = items[index].isPinned
        // Keep the existing identity so OCR/search selection state and UI references stay stable.
        items[index] = ClipboardItem(
            id: existingID,
            content: newItem.content,
            capturedAt: Date(),
            sourceAppBundleID: newItem.sourceAppBundleID,
            sourceAppName: newItem.sourceAppName,
            isPinned: wasPinned,
            analysis: newItem.analysis
        )
        sortItems()
        enforceCapacity()
        persist()
        logger.debug("Refreshed duplicate text clipboard item.")
        return true
    }

    private func compactDuplicateTextItemsIfNeeded() {
        var newestTextItems: [String: ClipboardItem] = [:]
        var compacted: [ClipboardItem] = []
        var removedDuplicateCount = 0

        for item in items.sorted(by: { $0.capturedAt > $1.capturedAt }) {
            guard let textKey = item.content.normalizedPlainText else {
                compacted.append(item)
                continue
            }

            if var existing = newestTextItems[textKey] {
                existing.isPinned = existing.isPinned || item.isPinned
                newestTextItems[textKey] = existing
                removedDuplicateCount += 1
            } else {
                newestTextItems[textKey] = item
            }
        }

        guard removedDuplicateCount > 0 else { return }

        compacted.append(contentsOf: newestTextItems.values)
        items = compacted
        sortItems()
        enforceCapacity()
        persist()
        logger.info("Compacted \(removedDuplicateCount) duplicate text clipboard items.")
    }

    private func sortItems() {
        let pinned = items.filter(\.isPinned).sorted { $0.capturedAt > $1.capturedAt }
        let unpinned = items.filter { !$0.isPinned }.sorted { $0.capturedAt > $1.capturedAt }
        items = pinned + unpinned
    }

    private func persist() {
        persistence.saveHistory(items)
    }
}
