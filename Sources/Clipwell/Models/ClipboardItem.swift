// Models/ClipboardItem.swift
// Clipwell v1.2 — Added analysis metadata and edit support.

import Foundation

struct ClipboardItem: Identifiable, Codable, Equatable {

    // MARK: - Identity & Metadata

    let id: UUID
    var content: ClipboardContent       // var — allows inline editing
    var capturedAt: Date
    var sourceAppBundleID: String?
    var sourceAppName: String?

    // MARK: - User State

    var isPinned: Bool
    /// v1.2: Rich analysis — URLs, URL metadata, and generic code detection.
    /// Optional so existing persisted items without it decode cleanly.
    var analysis: ContentAnalysis?

    // MARK: - Init

    init(
        id: UUID = UUID(),
        content: ClipboardContent,
        capturedAt: Date = Date(),
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        isPinned: Bool = false,
        analysis: ContentAnalysis? = nil
    ) {
        self.id = id
        self.content = content
        self.capturedAt = capturedAt
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.isPinned = isPinned
        self.analysis = analysis
    }

    // MARK: - Convenience

    var typeLabel: String { content.typeLabel }
    var previewText: String { content.previewText }
    var searchableText: String { content.searchableText }

    var effectiveAnalysis: ContentAnalysis? {
        guard case .text(let plain, _) = content else { return analysis }

        var refreshed = ContentAnalyzer.analyze(plain)
        if refreshed.detectedURL == analysis?.detectedURL {
            refreshed.urlTitle = analysis?.urlTitle
            refreshed.urlFaviconData = analysis?.urlFaviconData
        }
        refreshed.isEditedByUser = analysis?.isEditedByUser ?? false
        return refreshed
    }

    var displayTypeLabel: String {
        if effectiveAnalysis?.detectedURL != nil { return "URL" }
        return typeLabel
    }

    func hasSameContent(as other: ClipboardItem) -> Bool {
        content == other.content
    }

    /// Returns the plain-text string for this item, regardless of content type.
    var plainText: String? {
        if case .text(let plain, _) = content { return plain }
        return nil
    }
}
