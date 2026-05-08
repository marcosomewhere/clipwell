// UI/Components/HistoryRowView.swift
// Clipwell v1.2 — History row with rich text, code detection, URL preview,
// plain-text paste, and inline edit.

import SwiftUI

struct HistoryRowView: View {

    @EnvironmentObject private var settings: AppSettings

    let item: ClipboardItem
    var onPaste: () -> Void = {}
    var onPlainTextPaste: () -> Void = {}
    var onPin: () -> Void = {}
    var onDelete: () -> Void = {}
    var onEdit: () -> Void = {}
    var onPreview: () -> Void = {}

    private var analysis: ContentAnalysis? {
        item.effectiveAnalysis
    }

    private var l10n: SettingsLocalization {
        SettingsLocalization(settings.language.resolved)
    }

    var body: some View {
        HStack(spacing: 10) {
            contentIcon
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                contentPreview
                bottomRow
            }

            Spacer(minLength: 0)

            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .contextMenu { contextMenu }
    }

    // MARK: - Content Icon

    @ViewBuilder
    private var contentIcon: some View {
        switch item.content {
        case .text:
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
                if analysis?.codeLanguage != nil {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                } else if analysis?.detectedURL != nil {
                    Image(systemName: "link")
                        .font(.system(size: 13))
                        .foregroundStyle(.blue)
                } else {
                    Image(systemName: "doc.text")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

        case .image(_, let thumbData):
            ZStack(alignment: .bottomTrailing) {
                if let image = NSImage(data: thumbData) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipped()
                } else {
                    iconPlaceholder("photo")
                }
                if OCRIndex.shared.text(for: item.id) != nil {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 8, weight: .bold))
                        .padding(2)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .offset(x: 4, y: 4)
                }
            }

        case .fileReferences(let refs):
            if let first = refs.first {
                fileIcon(for: first)
            } else {
                iconPlaceholder("folder")
            }
        }
    }

    // MARK: - Content Preview

    @ViewBuilder
    private var contentPreview: some View {
        switch item.content {
        case .text(let plain, _):
            if analysis?.codeLanguage != nil {
                Text(plain.truncated(to: 160))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
            } else if analysis?.detectedURL != nil {
                // URL: show raw URL as monospaced, title shown below in bottomRow
                Text(plain.truncated(to: 80))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.blue)
                    .lineLimit(1)
            } else {
                Text(plain.truncated(to: 120))
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
            }

        case .image:
            Text(l10n.typeLabel(for: item))
                .font(.system(size: 12))
                .foregroundStyle(.primary)

        case .fileReferences:
            Text(item.previewText.truncated(to: 120))
                .font(.system(size: 12))
                .lineLimit(2)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Bottom Row (meta + enrichments)

    private var bottomRow: some View {
        HStack(spacing: 6) {
            // Type tag
            typeBadge

            if analysis?.codeLanguage != nil {
                codeBadge
            }

            // v1.2: URL title/domain
            if let analysis, analysis.detectedURL != nil {
                URLPreviewRow(analysis: analysis)
            }

            // Edited indicator
            if analysis?.isEditedByUser == true {
                Image(systemName: "pencil")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            // Source app + timestamp
            if let appName = item.sourceAppName {
                Text(appName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Text(l10n.shortDate(item.capturedAt))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var typeBadge: some View {
        Text(l10n.typeLabel(for: item))
            .font(.caption2)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .quaternaryLabelColor))
            )
            .foregroundStyle(.secondary)
    }

    private var codeBadge: some View {
        Text(l10n.code)
            .font(.caption2)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .quaternaryLabelColor))
            )
            .foregroundStyle(.secondary)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenu: some View {
        Button(l10n.paste) { onPaste() }
        // Plain text paste is available for text, and for images with OCR text.
        if canPasteAsPlainText {
            Button(l10n.pasteAsPlainText) { onPlainTextPaste() }
        }
        // v1.2: Edit — only for text items
        if item.plainText != nil {
            Button(l10n.edit) { onEdit() }
        }
        if case .image = item.content {
            Button(l10n.preview) { onPreview() }
        }
        Divider()
        Button(item.isPinned ? l10n.unpin : l10n.pin) { onPin() }
        Divider()
        Button(l10n.delete, role: .destructive) { onDelete() }
    }

    // MARK: - Helpers

    private var canPasteAsPlainText: Bool {
        if case .text = item.content { return true }
        if case .image = item.content, OCRIndex.shared.text(for: item.id) != nil { return true }
        return false
    }

    private func iconPlaceholder(_ systemName: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
            Image(systemName: systemName)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    private func fileIcon(for ref: FileReference) -> some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: ref.path))
            .resizable()
            .scaledToFit()
            .frame(width: 28, height: 28)
    }
}
