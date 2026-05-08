// Storage/PersistenceStore.swift
// Clipwell — JSON persistence for clipboard history.
//
// Design: A single JSON file stores all ClipboardItem records.
// Images are stored as separate files in an adjacent `images/` directory
// to keep the main JSON fast to parse.
//
// Tradeoff: JSON is human-readable and easy to inspect/debug. For very large
// histories (10k+), SQLite would be faster, but 200-500 items is the typical
// target and JSON performs fine at that scale.

import Foundation
import OSLog

final class PersistenceStore {

    static let shared = PersistenceStore()

    private let logger = Logger(subsystem: "com.clipwell.app", category: "PersistenceStore")
    private let queue = DispatchQueue(label: "com.clipwell.persistence", qos: .utility)

    // MARK: - File Paths

    private var appSupportURL: URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return urls[0].appendingPathComponent("Clipwell", isDirectory: true)
    }

    private var historyFileURL: URL {
        appSupportURL.appendingPathComponent("history.json")
    }

    private var imagesDirectoryURL: URL {
        appSupportURL.appendingPathComponent("images", isDirectory: true)
    }

    // MARK: - Init

    private init() {
        createDirectoriesIfNeeded()
    }

    private func createDirectoriesIfNeeded() {
        let fm = FileManager.default
        try? fm.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        try? fm.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)
    }

    // MARK: - Load

    func loadHistory() -> [ClipboardItem] {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: historyFileURL)
            let items = try JSONDecoder().decode([ClipboardItem].self, from: data)
            logger.debug("Loaded \(items.count) history items from disk.")
            return items
        } catch {
            logger.error("Failed to load history: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Save

    func saveHistory(_ items: [ClipboardItem]) {
        queue.async { [weak self] in
            guard let self else { return }
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(items)
                try data.write(to: self.historyFileURL, options: .atomicWrite)
            } catch {
                self.logger.error("Failed to save history: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Cleanup

    /// Removes orphaned image files that no longer have a corresponding history entry.
    func cleanupOrphanedImages(referencedIDs: Set<UUID>) {
        queue.async { [weak self] in
            guard let self else { return }
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(at: self.imagesDirectoryURL,
                                                           includingPropertiesForKeys: nil) else { return }
            for file in files {
                let nameWithoutExt = file.deletingPathExtension().lastPathComponent
                if let id = UUID(uuidString: nameWithoutExt), !referencedIDs.contains(id) {
                    try? fm.removeItem(at: file)
                    self.logger.debug("Removed orphaned image: \(file.lastPathComponent)")
                }
            }
        }
    }
}
