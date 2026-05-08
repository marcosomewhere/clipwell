// Models/ClipboardContent.swift
// Clipwell — Content type abstraction for clipboard entries.

import AppKit
import Foundation

/// Represents the actual payload stored in a clipboard entry.
/// New content types can be added here without changing the rest of the model layer.
enum ClipboardContent: Codable, Equatable {

    /// Plain or attributed text. `attributedString` is stored as RTF data when available.
    case text(plain: String, rtfData: Data?)

    /// An image stored as PNG data, with a smaller JPEG thumbnail for display.
    case image(pngData: Data, thumbnailData: Data)

    /// One or more file-system URLs (e.g., a Finder copy).
    case fileReferences([FileReference])

    // MARK: - Helpers

    /// Human-readable type label for UI display.
    var typeLabel: String {
        switch self {
        case .text:           return "Text"
        case .image:          return "Image"
        case .fileReferences: return "Files"
        }
    }

    /// The plain-text representation used for search indexing.
    var searchableText: String {
        switch self {
        case .text(let plain, _):
            return plain
        case .image:
            return ""
        case .fileReferences(let refs):
            return refs.map(\.filename).joined(separator: " ")
        }
    }

    /// Short preview string shown in the history list.
    var previewText: String {
        switch self {
        case .text(let plain, _):
            // Collapse whitespace for compact display
            return plain
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
                .joined(separator: " ")
        case .image:
            return "Image"
        case .fileReferences(let refs):
            if refs.count == 1 { return refs[0].filename }
            return "\(refs.count) files — \(refs.map(\.filename).prefix(3).joined(separator: ", "))"
        }
    }

    /// Reconstructs an NSImage from stored data (image entries only).
    var nsImage: NSImage? {
        guard case .image(let pngData, _) = self else { return nil }
        return NSImage(data: pngData)
    }

    /// Returns the thumbnail NSImage for display in the list (image entries only).
    var thumbnailImage: NSImage? {
        guard case .image(_, let thumbData) = self else { return nil }
        return NSImage(data: thumbData)
    }

    var normalizedPlainText: String? {
        guard case .text(let plain, _) = self else { return nil }
        let normalized = plain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return normalized.isEmpty ? nil : normalized
    }
}

// MARK: - FileReference

/// Lightweight serializable representation of a file URL.
struct FileReference: Codable, Equatable {
    let path: String
    let filename: String
    let fileSize: Int64?
    let uniformTypeIdentifier: String?

    init(url: URL) {
        self.path = url.path
        self.filename = url.lastPathComponent
        self.fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) }
        self.uniformTypeIdentifier = (try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier)
    }

    var url: URL { URL(fileURLWithPath: path) }
}
