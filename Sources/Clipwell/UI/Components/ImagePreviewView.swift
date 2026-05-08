// UI/Components/ImagePreviewView.swift
// Clipwell — Larger image preview for clipboard history items.

import SwiftUI

struct ImagePreviewView: View {

    @EnvironmentObject private var settings: AppSettings
    let item: ClipboardItem
    var onClose: () -> Void = {}

    private var l10n: SettingsLocalization {
        SettingsLocalization(settings.language.resolved)
    }

    private var image: NSImage? {
        item.content.nsImage
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color(nsColor: .textBackgroundColor)

                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(18)
                } else {
                    ContentUnavailableView(l10n.imagePreviewUnavailable, systemImage: "photo")
                }
            }

            Divider()

            HStack(spacing: 10) {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.typeLabel(for: item))
                        .font(.system(size: 12, weight: .semibold))
                    Text(l10n.shortDate(item.capturedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(l10n.close) {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(12)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 360, minHeight: 280)
    }
}
