// UI/PopoverView.swift
// Clipwell v1.2 — Search bar + history list.
// New: plain-text paste (⌥+Enter or ⌥+click), edit sheet.

import SwiftUI

enum ClipboardSortMode: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case type
    case sourceApp

    var id: String { rawValue }
}

enum ClipboardGroupMode: String, CaseIterable, Identifiable {
    case none
    case date
    case type
    case sourceApp

    var id: String { rawValue }
}

private struct ClipboardGroupSection: Identifiable {
    let id: String
    let title: String?
    let items: [ClipboardItem]
}

private struct ClipboardGroupKey: Hashable {
    let id: String
    let title: String
}

struct PopoverView: View {

    @EnvironmentObject private var repository: ClipboardRepository
    @EnvironmentObject private var settings: AppSettings
    private var l10n: SettingsLocalization { SettingsLocalization(settings.language.resolved) }

    @AppStorage("popoverSortMode") private var sortModeRaw: String = ClipboardSortMode.newest.rawValue
    @AppStorage("popoverGroupMode") private var groupModeRaw: String = ClipboardGroupMode.none.rawValue

    @State private var searchText: String = ""
    @State private var selectedItemID: UUID? = nil
    @State private var shouldScrollSelectionIntoView = false
    @State private var editingItem: ClipboardItem? = nil
    @State private var imagePreviewWindow: NSWindow? = nil
    @FocusState private var searchFocused: Bool

    var showsBottomToolbar: Bool = true
    var onSelectItem: (ClipboardItem, Bool) -> Void = { _, _ in }   // (item, asPlainText)
    var onOpenSettings: () -> Void = {}
    var onClose: () -> Void = {}

    private var displayedItems: [ClipboardItem] {
        sortedItems(repository.search(query: searchText))
    }

    private var groupedDisplayedItems: [ClipboardGroupSection] {
        makeSections(from: displayedItems)
    }

    private var sortMode: ClipboardSortMode {
        get { ClipboardSortMode(rawValue: sortModeRaw) ?? .newest }
        nonmutating set { sortModeRaw = newValue.rawValue }
    }

    private var groupMode: ClipboardGroupMode {
        get { ClipboardGroupMode(rawValue: groupModeRaw) ?? .none }
        nonmutating set { groupModeRaw = newValue.rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            filterToolbar
            Divider()
            historyList
            if showsBottomToolbar {
                Divider()
                bottomToolbar
            }
        }
        .frame(width: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $editingItem) { item in
            EditItemView(item: item, isPresented: Binding(
                get: { editingItem != nil },
                set: { if !$0 { editingItem = nil } }
            ))
            .environmentObject(repository)
        }
        .onAppear {
            focusSearchField()
            selectedItemID = displayedItems.first?.id
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipwellFocusSearch)) { _ in
            focusSearchField()
        }
        .onChange(of: searchText) { _, _ in
            selectedItemID = displayedItems.first?.id
        }
    }

    // MARK: - Search Bar

    private func focusSearchField() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            searchFocused = true
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
                .font(.system(size: 13))

            TextField(l10n.searchClipboard, text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
                .onKeyPress(.upArrow)   { moveSelection(by: -1); return .handled }
                .onKeyPress(.downArrow) { moveSelection(by: +1); return .handled }
                .onKeyPress(.return)    { commitSelection(asPlainText: false); return .handled }
                .onKeyPress(.escape)    { onClose(); return .handled }
                .onKeyPress(.delete)    { deleteSelected(); return .handled }

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            if settings.monitoringPaused {
                Image(systemName: "pause.circle.fill")
                    .foregroundStyle(.orange)
                    .help(l10n.monitoringPausedHelp)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var filterToolbar: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(ClipboardSortMode.allCases) { mode in
                    Button {
                        sortMode = mode
                        selectedItemID = displayedItems.first?.id
                    } label: {
                        if sortMode == mode {
                            Label(l10n.sortMode(mode), systemImage: "checkmark")
                        } else {
                            Text(l10n.sortMode(mode))
                        }
                    }
                }
            } label: {
                Label(l10n.sortMode(sortMode), systemImage: "arrow.up.arrow.down")
                    .font(.system(size: 11))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(l10n.sortHistory)

            Menu {
                ForEach(ClipboardGroupMode.allCases) { mode in
                    Button {
                        groupMode = mode
                        selectedItemID = displayedItems.first?.id
                    } label: {
                        if groupMode == mode {
                            Label(l10n.groupMode(mode), systemImage: "checkmark")
                        } else {
                            Text(l10n.groupMode(mode))
                        }
                    }
                }
            } label: {
                Label(l10n.groupMode(groupMode), systemImage: "rectangle.3.group")
                    .font(.system(size: 11))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(l10n.groupHistory)

            Spacer()

            Text("\(displayedItems.count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    // MARK: - History List

    private var historyList: some View {
        Group {
            if displayedItems.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(groupedDisplayedItems) { section in
                                if let title = section.title {
                                    sectionHeader(title)
                                }

                                ForEach(section.items) { item in
                                    rowView(for: item)
                                        .id(item.id)
                                        .background(rowBackground(for: item))
                                        .onHover { isHovering in
                                            if isHovering {
                                                selectedItemID = item.id
                                            }
                                        }
                                        .onTapGesture(count: 1) {
                                            // ⌥+click = plain text paste
                                            let plainText = NSEvent.modifierFlags.contains(.option)
                                            selectAndCommit(item, asPlainText: plainText)
                                        }
                                    if item.id != section.items.last?.id {
                                        Divider().padding(.leading, 50)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: selectedItemID) { _, newID in
                        if let id = newID, shouldScrollSelectionIntoView {
                            shouldScrollSelectionIntoView = false
                            withAnimation(.linear(duration: 0.1)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 440)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 3)
    }

    private func rowView(for item: ClipboardItem) -> some View {
        HistoryRowView(
            item: item,
            onPaste:          { selectAndCommit(item, asPlainText: false) },
            onPlainTextPaste: { selectAndCommit(item, asPlainText: true) },
            onPin:            { repository.togglePin(item) },
            onDelete:         { repository.removeItem(item) },
            onEdit:           { editingItem = item },
            onPreview:        { openImagePreview(for: item) }
        )
    }

    private func openImagePreview(for item: ClipboardItem) {
        if let imagePreviewWindow {
            imagePreviewWindow.close()
        }

        let previewView = ImagePreviewView(item: item) {
            imagePreviewWindow?.close()
            imagePreviewWindow = nil
        }
        .environmentObject(settings)
        let hostingController = NSHostingController(rootView: previewView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = l10n.preview
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 720, height: 520))
        window.minSize = NSSize(width: 360, height: 280)
        window.center()
        imagePreviewWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func rowBackground(for item: ClipboardItem) -> some View {
        Group {
            if item.id == selectedItemID {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.12))
                    .padding(.horizontal, 4)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clipboard")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(searchText.isEmpty ? l10n.noClipboardHistory : l10n.noResults)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack {
            Button(action: { repository.clearUnpinnedHistory() }) {
                Label(l10n.clear, systemImage: "trash")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Text(l10n.plainTextHint)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Divider().frame(height: 14)

            Text(l10n.pasteShortcut)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .help(l10n.openClipwell)

            Divider().frame(height: 14)

            Button(action: { settings.monitoringPaused.toggle() }) {
                Label(
                    settings.monitoringPaused ? l10n.resume : l10n.pause,
                    systemImage: settings.monitoringPaused ? "play.circle" : "pause.circle"
                )
                .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Divider().frame(height: 14)

            Button(action: { onOpenSettings() }) {
                Image(systemName: "gear")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(l10n.settings)

            Divider().frame(height: 14)

            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .help(l10n.quitClipwell)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Navigation

    private func moveSelection(by delta: Int) {
        let items = displayedItems
        guard !items.isEmpty else { return }
        if let current = selectedItemID,
           let index = items.firstIndex(where: { $0.id == current }) {
            let next = min(max(index + delta, 0), items.count - 1)
            shouldScrollSelectionIntoView = true
            selectedItemID = items[next].id
        } else {
            shouldScrollSelectionIntoView = true
            selectedItemID = delta > 0 ? items.first?.id : items.last?.id
        }
    }

    private func commitSelection(asPlainText: Bool) {
        guard let id = selectedItemID,
              let item = displayedItems.first(where: { $0.id == id }) else { return }
        selectAndCommit(item, asPlainText: asPlainText)
    }

    private func selectAndCommit(_ item: ClipboardItem, asPlainText: Bool) {
        onSelectItem(item, asPlainText)
    }

    private func deleteSelected() {
        let items = displayedItems
        guard let id = selectedItemID,
              let item = items.first(where: { $0.id == id }),
              let currentIndex = items.firstIndex(where: { $0.id == id }) else { return }

        let nextIndex: Int?
        if items.count == 1 {
            nextIndex = nil
        } else if currentIndex < items.count - 1 {
            nextIndex = min(currentIndex + 1, items.count - 1)
        } else {
            nextIndex = currentIndex - 1
        }

        selectedItemID = nextIndex.map { items[$0].id }
        repository.removeItem(item)
    }

    // MARK: - Sorting & Grouping

    private func sortedItems(_ items: [ClipboardItem]) -> [ClipboardItem] {
        let sorted = items.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }

            switch sortMode {
            case .newest:
                return lhs.capturedAt > rhs.capturedAt
            case .oldest:
                return lhs.capturedAt < rhs.capturedAt
            case .type:
                let typeCompare = l10n.typeLabel(for: lhs).localizedCaseInsensitiveCompare(l10n.typeLabel(for: rhs))
                if typeCompare != .orderedSame { return typeCompare == .orderedAscending }
                return lhs.capturedAt > rhs.capturedAt
            case .sourceApp:
                let lhsApp = lhs.sourceAppName ?? l10n.unknownApp
                let rhsApp = rhs.sourceAppName ?? l10n.unknownApp
                let appCompare = lhsApp.localizedCaseInsensitiveCompare(rhsApp)
                if appCompare != .orderedSame { return appCompare == .orderedAscending }
                return lhs.capturedAt > rhs.capturedAt
            }
        }
        return sorted
    }

    private func makeSections(from items: [ClipboardItem]) -> [ClipboardGroupSection] {
        guard groupMode != .none else {
            return [ClipboardGroupSection(id: "all", title: nil, items: items)]
        }

        let grouped = Dictionary(grouping: items) { groupKey(for: $0) }
        return grouped
            .map { key, sectionItems in
                ClipboardGroupSection(id: key.id, title: key.title, items: sortedItems(sectionItems))
            }
            .sorted { lhs, rhs in
                switch groupMode {
                case .date:
                    return lhs.id > rhs.id
                case .type, .sourceApp:
                    return (lhs.title ?? "").localizedCaseInsensitiveCompare(rhs.title ?? "") == .orderedAscending
                case .none:
                    return false
                }
            }
    }

    private func groupKey(for item: ClipboardItem) -> ClipboardGroupKey {
        switch groupMode {
        case .none:
            return ClipboardGroupKey(id: "all", title: "")
        case .date:
            let day = Calendar.current.startOfDay(for: item.capturedAt)
            return ClipboardGroupKey(id: String(day.timeIntervalSince1970), title: groupTitle(for: day))
        case .type:
            let typeLabel = l10n.typeLabel(for: item)
            return ClipboardGroupKey(id: typeLabel, title: typeLabel)
        case .sourceApp:
            let appName = item.sourceAppName ?? l10n.unknownApp
            return ClipboardGroupKey(id: appName, title: appName)
        }
    }

    private func groupTitle(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return l10n.today }
        if calendar.isDateInYesterday(day) { return l10n.yesterday }
        return DateFormatter.clipwellSection.string(from: day)
    }
}

private extension DateFormatter {
    static let clipwellSection: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
