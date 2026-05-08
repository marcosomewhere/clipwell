// Utilities/Extensions.swift
// Clipwell — Miscellaneous Swift and AppKit extensions.

import Foundation

// MARK: - String

extension String {
    /// Truncates to `length` characters, appending `…` if needed.
    func truncated(to length: Int) -> String {
        guard self.count > length else { return self }
        return String(prefix(length)) + "…"
    }
}
