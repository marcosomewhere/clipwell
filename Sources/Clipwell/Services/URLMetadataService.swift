// Services/URLMetadataService.swift
// Clipwell v1.2 — Fetches page title and favicon for URL clipboard items.
//
// Runs asynchronously after item capture. Updates the item's analysis in the
// repository once data arrives. Uses URLSession with a short timeout so it
// never blocks the UI or hangs on unreachable URLs.

import Foundation
import OSLog

@MainActor
final class URLMetadataService {

    static let shared = URLMetadataService()
    private let logger = Logger(subsystem: "com.clipwell.app", category: "URLMetadata")

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 8
        // Identify as a browser-like client so servers don't block us
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15) AppleWebKit/537.36"
        ]
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: - Public

    /// Fetches title and favicon for the URL stored in the item's analysis.
    /// Updates the repository item in-place when done.
    func enrich(item: ClipboardItem, in repository: ClipboardRepository) {
        guard
            let analysis = item.effectiveAnalysis,
            let urlString = analysis.detectedURL,
            let url = URL(string: urlString),
            analysis.urlTitle == nil          // don't re-fetch if already done
        else { return }

        let itemID = item.id

        Task {
            async let title   = fetchTitle(from: url)
            async let favicon = fetchFavicon(from: url)

            let (resolvedTitle, resolvedFavicon) = await (title, favicon)

            guard resolvedTitle != nil || resolvedFavicon != nil else { return }

            await MainActor.run {
                repository.updateAnalysis(for: itemID) { analysis in
                    analysis.detectedURL = urlString
                    if let t = resolvedTitle  { analysis.urlTitle       = t }
                    if let f = resolvedFavicon { analysis.urlFaviconData = f }
                }
            }
        }
    }

    // MARK: - Private

    private func fetchTitle(from url: URL) async -> String? {
        guard let (data, _) = try? await session.data(from: url),
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { return nil }

        // Extract <title>…</title> with a simple regex — no need for a full HTML parser
        let pattern = #"<title[^>]*>(.*?)</title>"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
            let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
            let range = Range(match.range(at: 1), in: html)
        else { return nil }

        let raw = String(html[range])
        // Decode common HTML entities
        return raw
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;",  with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .truncated(to: 120)
    }

    private func fetchFavicon(from url: URL) async -> Data? {
        // Standard favicon locations — try /favicon.ico first, then Google's service
        var candidates: [URL] = []
        if let root = URL(string: "/favicon.ico", relativeTo: url)?.absoluteURL {
            candidates.append(root)
        }
        if let google = URL(string: "https://www.google.com/s2/favicons?domain=\(url.host ?? "")&sz=32") {
            candidates.append(google)
        }

        for candidate in candidates {
            if let (data, response) = try? await session.data(from: candidate),
               let http = response as? HTTPURLResponse,
               http.statusCode == 200,
               data.count > 100   // ignore empty/error responses
            {
                return data
            }
        }
        return nil
    }
}
