// UI/Components/URLPreviewRow.swift
// Clipwell v1.2 — Compact URL preview: favicon + title + domain.

import SwiftUI

struct URLPreviewRow: View {

    let analysis: ContentAnalysis

    private var domain: String? {
        guard let urlStr = analysis.detectedURL,
              let url = URL(string: urlStr),
              let host = url.host else { return nil }
        // Strip www. prefix
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    var body: some View {
        HStack(spacing: 6) {
            // Favicon
            Group {
                if let data = analysis.urlFaviconData, let img = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "link")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 14, height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 3))

            // Title or domain
            if let title = analysis.urlTitle, !title.isEmpty {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if let domain {
                Text(domain)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
