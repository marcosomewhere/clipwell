// UI/ClipboardPickerViewFactory.swift
// Shared construction for the clipboard picker used by the menu bar popover and hotkey overlay.

import AppKit
import SwiftUI

@MainActor
enum ClipboardPickerViewFactory {

    static func make(
        repository: ClipboardRepository,
        pasteService: PasteService,
        monitor: ClipboardMonitor,
        pasteTargetApp: @escaping () -> NSRunningApplication?,
        showsBottomToolbar: Bool,
        close: @escaping () -> Void
    ) -> some View {
        PopoverView(
            showsBottomToolbar: showsBottomToolbar,
            onSelectItem: { item, asPlainText in
                let refreshedItem = repository.refreshItem(item)
                let targetApp = pasteTargetApp()
                close()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    pasteService.select(
                        item: refreshedItem,
                        monitor: monitor,
                        asPlainText: asPlainText,
                        forcePaste: false,
                        targetApp: targetApp
                    )
                }
            },
            onOpenSettings: {
                close()
                NotificationCenter.default.post(name: .clipwellOpenSettings, object: nil)
            },
            onClose: close
        )
        .environmentObject(repository)
        .environmentObject(AppSettings.shared)
    }
}
