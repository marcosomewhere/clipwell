// Models/ContentAnalysis.swift
// Clipwell v1.2 — Metadata derived from analysing a text clipboard entry.
// Stored alongside the item; enriched asynchronously (URL title/favicon).

import Foundation

// MARK: - ContentAnalysis

struct ContentAnalysis: Codable, Equatable {
    /// First URL found in the text, if any.
    var detectedURL: String?
    /// Page title fetched asynchronously from the URL.
    var urlTitle: String?
    /// Favicon PNG data, fetched asynchronously.
    var urlFaviconData: Data?
    /// Set when the text looks like code. Clipwell no longer guesses a language.
    var codeLanguage: CodeLanguage?
    /// True after the user has manually edited the item's text.
    var isEditedByUser: Bool

    static let empty = ContentAnalysis(
        detectedURL: nil,
        urlTitle: nil,
        urlFaviconData: nil,
        codeLanguage: nil,
        isEditedByUser: false
    )
}

// MARK: - CodeLanguage

enum CodeLanguage: String, Codable, Equatable {
    case code = "Code"

    init(from decoder: Decoder) throws {
        _ = try decoder.singleValueContainer().decode(String.self)
        self = .code
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
