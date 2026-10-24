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

    static let shared = ClipboardRepository(persistence: .shared, settings: .shared)

    // MARK: - Published State

    /// Full history, pinned items first, then newest-first.
    @Published private(set) var items: [ClipboardItem] = []

    // MARK: - Private

    private let persistence: PersistenceStore
    private let settings: AppSettings
    private let startOCR: Bool
    private var imageDigests: [UUID: Data] = [:]
    private let logger = Logger(subsystem: "com.clipwell.app", category: "Repository")

    init(persistence: PersistenceStore, settings: AppSettings, startOCR: Bool = true) {
        self.persistence = persistence
        self.settings = settings
        self.startOCR = startOCR
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
        insertReplacingDuplicates(item)
    }

    func removeItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        removeOCR(item.id)
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
        allIDs.forEach { removeOCR($0) }
        persistence.cleanupOrphanedImages(referencedIDs: [])
    }

    /// Exact text equality preserves whitespace-significant scripts. Pins migrate to the new copy.
    private func insertReplacingDuplicates(_ incoming: ClipboardItem) {
        var next = incoming
        let duplicates = items.filter { $0.isEditedImage != true && incoming.isEditedImage != true && samePayloadCached($0, incoming) }
        next.isPinned = next.isPinned || duplicates.contains(where: \.isPinned)
        let ids = Set(duplicates.map(\.id))
        items.removeAll { ids.contains($0.id) }
        ids.forEach { removeOCR($0) }
        items.append(next)
        sortItems()
        enforceCapacity()
        persist()
        if startOCR, case .image = next.content { OCRService.shared.enqueue(item: next) }
    }

    private func digest(_ item: ClipboardItem, png: Data) -> Data {
        if let cached = imageDigests[item.id] { return cached }
        let result = ImageFingerprint.digest(png)
        imageDigests[item.id] = result
        return result
    }

    private func samePayloadCached(_ lhs: ClipboardItem, _ rhs: ClipboardItem) -> Bool {
        if case .image(let a, _) = lhs.content, case .image(let b, _) = rhs.content {
            return digest(lhs, png: a) == digest(rhs, png: b)
        }
        return Self.samePayload(lhs, rhs)
    }

    static func samePayload(_ lhs: ClipboardItem, _ rhs: ClipboardItem) -> Bool {
        switch (lhs.content, rhs.content) {
        case (.text(let a, _), .text(let b, _)): return a == b
        case (.image(let a, _), .image(let b, _)): return ImageFingerprint.digest(a) == ImageFingerprint.digest(b)
        case (.fileReferences(let a), .fileReferences(let b)): return a.map(\.path) == b.map(\.path)
        default: return false
        }
    }

    func setPinned(_ id: UUID, _ pinned: Bool) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned = pinned
        sortItems()
        persist()
    }

    func saveEditedImage(_ content: ClipboardContent, original: ClipboardItem, editedID: UUID?) -> UUID {
        if let editedID, let index = items.firstIndex(where: { $0.id == editedID }) {
            items[index].content = content
            items[index].isEditedImage = true
            removeOCR(editedID)
            imageDigests.removeValue(forKey: editedID)
            if startOCR { OCRService.shared.enqueue(item: items[index]) }
            persist()
            return editedID
        }
        var copy = ClipboardItem(content: content, isPinned: original.isPinned)
        copy.isEditedImage = true
        addItem(copy)
        return copy.id
    }

    private func removeOCR(_ id: UUID) { if startOCR { OCRIndex.shared.remove(itemID: id) } }

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

    private func compactDuplicateTextItemsIfNeeded() {
        var kept: [ClipboardItem] = []
        for item in items.sorted(by: { $0.capturedAt > $1.capturedAt }) {
            if item.isEditedImage != true,
               let index = kept.firstIndex(where: { $0.isEditedImage != true && samePayloadCached($0, item) }) {
                kept[index].isPinned = kept[index].isPinned || item.isPinned
                removeOCR(item.id)
            } else { kept.append(item) }
        }
        if kept.count != items.count { items = kept; sortItems(); persist() }
    }

    private func sortItems() {
        let pinned = items.filter(\.isPinned).sorted { $0.capturedAt > $1.capturedAt }
        let unpinned = items.filter { !$0.isPinned }.sorted { $0.capturedAt > $1.capturedAt }
        items = pinned + unpinned
    }

    private func persist() {
        let retained = Set(items.map(\.id))
        imageDigests = imageDigests.filter { retained.contains($0.key) }
        if startOCR { OCRIndex.shared.prune(keeping: retained) }
        persistence.saveHistory(items)
    }
}
