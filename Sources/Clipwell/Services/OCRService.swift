// Services/OCRService.swift
// Clipwell — Extracts text from image clipboard entries using Vision.
//
// OCR runs asynchronously in the background after an image is captured.
// Recognized text is stored in a separate index that the search layer queries.
// We do NOT mutate ClipboardItem itself — OCR results live in OCRIndex,
// keeping the model layer clean and the OCR opt-in / failure-safe.

import Foundation
import OSLog
import Vision

// MARK: - OCR Index

/// Thread-safe in-memory map of item ID → recognized text.
/// Persisted as a companion JSON file alongside history.json.
@MainActor
final class OCRIndex: ObservableObject {

    static let shared = OCRIndex()

    /// item.id → recognized lines, preserved for copying screenshot text.
    @Published private(set) var recognizedText: [UUID: String] = [:]

    private let logger = Logger(subsystem: "com.clipwell.app", category: "OCRIndex")
    private let persistence = OCRIndexPersistence()

    private init() {
        recognizedText = persistence.load()
        logger.debug("OCR index loaded: \(self.recognizedText.count) entries")
    }

    func store(text: String, for itemID: UUID) {
        recognizedText[itemID] = text
        persistence.save(recognizedText)
    }

    func text(for itemID: UUID) -> String? {
        recognizedText[itemID]
    }

    func remove(itemID: UUID) {
        recognizedText.removeValue(forKey: itemID)
        persistence.save(recognizedText)
    }

    func prune(keeping ids: Set<UUID>) {
        let filtered = recognizedText.filter { ids.contains($0.key) }
        guard filtered.count != recognizedText.count else { return }
        recognizedText = filtered
        persistence.save(recognizedText)
    }

    /// Returns whether `query` matches the OCR text of `itemID`.
    func matches(itemID: UUID, query: String) -> Bool {
        guard let text = recognizedText[itemID] else { return false }
        return text.localizedCaseInsensitiveContains(query)
    }
}

// MARK: - OCR Service

/// Submits image items for background Vision OCR and stores results in OCRIndex.
/// @unchecked Sendable: internal state is only the immutable logger and a serial
/// DispatchQueue, so cross-actor access is safe in practice.
final class OCRService: @unchecked Sendable {

    static let shared = OCRService()

    private let logger = Logger(subsystem: "com.clipwell.app", category: "OCRService")
    private let queue = DispatchQueue(label: "com.clipwell.ocr", qos: .utility)

    private init() {}

    /// Enqueues Vision OCR for an image clipboard item.
    /// Must be called from the MainActor (ClipboardMonitor is @MainActor).
    @MainActor
    func enqueue(item: ClipboardItem) {
        guard case .image(let pngData, _) = item.content else { return }
        guard OCRIndex.shared.text(for: item.id) == nil else { return }

        let id = item.id
        queue.async { [weak self] in
            self?.recognize(pngData: pngData, itemID: id)
        }
    }

    // MARK: - Vision

    private func recognize(pngData: Data, itemID: UUID) {
        do {
            let joined = try Self.extractText(from: pngData)
            guard !joined.isEmpty else { return }
            Task { @MainActor in
                guard ClipboardRepository.shared.items.contains(where: {
                    guard $0.id == itemID, case .image(let current, _) = $0.content else { return false }
                    return current == pngData
                }) else { return }
                OCRIndex.shared.store(text: joined, for: itemID)
            }
            logger.debug("OCR completed for \(itemID)")
        } catch {
            logger.error("OCR handler error: \(error.localizedDescription)")
        }
    }

    static func extractText(from pngData: Data) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        // Recognize top languages; Vision auto-detects from image content
        request.recognitionLanguages = ["en-US", "de-DE", "fr-FR", "es-ES"]

        let handler = VNImageRequestHandler(data: pngData, options: [:])
        try handler.perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}

// MARK: - OCR Index Persistence

/// Persists the OCR index as a lightweight JSON file.
private struct OCRIndexPersistence {

    private var fileURL: URL {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Clipwell")
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("ocr-index.json")
    }

    func load() -> [UUID: String] {
        guard let data = try? Data(contentsOf: fileURL),
              let raw = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        var result: [UUID: String] = [:]
        for (key, value) in raw {
            if let uuid = UUID(uuidString: key) {
                result[uuid] = value
            }
        }
        return result
    }

    func save(_ index: [UUID: String]) {
        let raw = Dictionary(uniqueKeysWithValues: index.map { ($0.key.uuidString, $0.value) })
        guard let data = try? JSONEncoder().encode(raw) else { return }
        try? data.write(to: fileURL, options: .atomicWrite)
    }
}
