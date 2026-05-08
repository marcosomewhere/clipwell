// UI/SettingsView.swift
// Clipwell — Settings window.
// Uses SMAppService directly for launch-at-login support.

import ServiceManagement
import AppKit
import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var settings: AppSettings
    private var l10n: SettingsLocalization { SettingsLocalization(settings.language.resolved) }

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label(l10n.general, systemImage: "gear") }
            PrivacySettingsTab()
                .tabItem { Label(l10n.privacy, systemImage: "lock.shield") }
            StorageSettingsTab()
                .tabItem { Label(l10n.storage, systemImage: "internaldrive") }
            LanguageSettingsTab()
                .tabItem { Label(l10n.language, systemImage: "globe") }
            AboutSettingsTab()
                .tabItem { Label(l10n.about, systemImage: "info.circle") }
        }
        .frame(width: 660, height: 420)
        .environmentObject(settings)
    }
}

// MARK: - General Tab

private struct GeneralSettingsTab: View {

    @EnvironmentObject private var settings: AppSettings
    @State private var accessibilityTrusted = PasteService.shared.checkAccessibilityPermission()
    private var l10n: SettingsLocalization { SettingsLocalization(settings.language.resolved) }

    var body: some View {
        Form {
            Section(l10n.behavior) {
                Toggle(l10n.launchAtLogin, isOn: Binding(
                    get: { SMAppService.mainApp.status == .enabled },
                    set: { enable in
                        do {
                            if enable {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            // Non-fatal: user can retry or set manually
                        }
                    }
                ))

                Toggle(l10n.autoPaste, isOn: $settings.autoPasteOnSelection)
                    .help(l10n.autoPasteHelp)

                Toggle(l10n.pauseMonitoring, isOn: $settings.monitoringPaused)
            }

            Section(l10n.permissions) {
                HStack {
                    Label(
                        accessibilityTrusted ? l10n.accessibilityAllowed : l10n.accessibilityMissing,
                        systemImage: accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(accessibilityTrusted ? .green : .orange)

                    Spacer()

                    Button(l10n.openAccessibilitySettings) {
                        PasteService.shared.openAccessibilitySettings()
                    }
                }

                Text(l10n.accessibilityNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(l10n.shortcuts) {
                LabeledContent(l10n.openPickerShortcut, value: "⌘⇧V")
                LabeledContent(l10n.plainTextShortcut, value: "⌥")
                Text(l10n.shortcutsNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(l10n.history) {
                Stepper(
                    l10n.keepItems(settings.maxHistoryCount),
                    value: $settings.maxHistoryCount,
                    in: 10...2000,
                    step: 10
                )
                Picker(l10n.duplicateHandling, selection: $settings.duplicateHandling) {
                    ForEach(DuplicateHandlingMode.allCases) { mode in
                        Text(l10n.duplicateMode(mode)).tag(mode)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            accessibilityTrusted = PasteService.shared.checkAccessibilityPermission()
        }
    }
}

// MARK: - Privacy Tab

private struct PrivacySettingsTab: View {

    @EnvironmentObject private var settings: AppSettings
    @State private var newBundleID: String = ""
    @State private var appSearchText: String = ""
    private var l10n: SettingsLocalization { SettingsLocalization(settings.language.resolved) }

    var body: some View {
        Form {
            Section {
                Text(l10n.privacyIntro)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if settings.excludedAppBundleIDs.isEmpty {
                    Text(l10n.noAppsIgnored).foregroundStyle(.tertiary).italic()
                } else {
                    ForEach(Array(settings.excludedAppBundleIDs).sorted(), id: \.self) { bundleID in
                        let appInfo = AppDisplayInfo(bundleID: bundleID)
                        HStack(spacing: 10) {
                            Image(nsImage: appInfo.icon)
                                .resizable()
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(appInfo.name)
                                Text(bundleID)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button(l10n.remove) { settings.excludedAppBundleIDs.remove(bundleID) }
                                .buttonStyle(.borderless)
                        }
                    }
                }
            } header: {
                Text(l10n.ignoredApps)
            }

            Section {
                Menu {
                    if availableRunningApps.isEmpty {
                        Text(l10n.noAppsAvailable)
                    } else {
                        ForEach(availableRunningApps, id: \.bundleID) { app in
                            Button {
                                settings.excludedAppBundleIDs.insert(app.bundleID)
                            } label: {
                                Text("\(app.name)  \(app.bundleID)")
                            }
                        }
                    }
                } label: {
                    Label(l10n.addRunningApp, systemImage: "plus.app")
                }

                TextField(l10n.filterRunningApps, text: $appSearchText)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 8) {
                    TextField(l10n.bundleIDPlaceholder, text: $newBundleID)
                        .textFieldStyle(.roundedBorder)
                    Button(l10n.add) {
                        let t = newBundleID.trimmingCharacters(in: .whitespaces)
                        guard !t.isEmpty else { return }
                        settings.excludedAppBundleIDs.insert(t)
                        newBundleID = ""
                    }
                    .disabled(newBundleID.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text(l10n.addApp)
            } footer: {
                Text(l10n.bundleIDSource)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var availableRunningApps: [RunningAppInfo] {
        let query = appSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return NSWorkspace.shared.runningApplications
            .compactMap { app -> RunningAppInfo? in
                guard let bundleID = app.bundleIdentifier,
                      bundleID != Bundle.main.bundleIdentifier,
                      !settings.excludedAppBundleIDs.contains(bundleID) else { return nil }
                let name = app.localizedName ?? bundleID
                if !query.isEmpty,
                   !name.lowercased().contains(query),
                   !bundleID.lowercased().contains(query) {
                    return nil
                }
                return RunningAppInfo(name: name, bundleID: bundleID)
            }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }
}

private struct RunningAppInfo {
    let name: String
    let bundleID: String
}

private struct AppDisplayInfo {
    let name: String
    let icon: NSImage

    init(bundleID: String) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            self.name = url.deletingPathExtension().lastPathComponent
            self.icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            self.name = bundleID
            self.icon = NSWorkspace.shared.icon(for: .application)
        }
    }
}

// MARK: - Storage Tab

private struct StorageSettingsTab: View {

    @EnvironmentObject private var repository: ClipboardRepository
    @EnvironmentObject private var settings: AppSettings
    private var l10n: SettingsLocalization { SettingsLocalization(settings.language.resolved) }

    var body: some View {
        Form {
            Section(l10n.currentHistory) {
                LabeledContent(l10n.totalEntries,  value: "\(repository.items.count)")
                LabeledContent(l10n.pinnedEntries, value: "\(repository.items.filter(\.isPinned).count)")
                LabeledContent(l10n.imagesStored,  value: "\(imageCount)")
            }
            Section(l10n.actions) {
                Button(l10n.clearUnpinned, role: .destructive) { repository.clearUnpinnedHistory() }
                Button(l10n.clearAll,      role: .destructive) { repository.clearAll() }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var imageCount: Int {
        repository.items.filter { if case .image = $0.content { return true }; return false }.count
    }
}

// MARK: - Language Tab

private struct LanguageSettingsTab: View {

    @EnvironmentObject private var settings: AppSettings
    private var l10n: SettingsLocalization { SettingsLocalization(settings.language.resolved) }

    var body: some View {
        Form {
            Section(l10n.language) {
                Picker(l10n.appLanguage, selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                Text(l10n.systemLanguageNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - About Tab

private struct AboutSettingsTab: View {

    @EnvironmentObject private var settings: AppSettings
    @State private var detailsWindow: NSWindow? = nil
    private var l10n: SettingsLocalization { SettingsLocalization(settings.language.resolved) }

    var body: some View {
        Form {
            Section(l10n.about) {
                Text("Made with ♥ by Marco Seefeldt")
                LabeledContent(l10n.developmentStatus, value: "2026")
                Text(l10n.aboutDescription)
                    .foregroundStyle(.secondary)
                Button(l10n.openClipwellGuide) {
                    openDetailsWindow()
                }
            }

            Section(l10n.security) {
                Text(l10n.localHistory)
                Text(l10n.noUpload)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func openDetailsWindow() {
        if let detailsWindow {
            NSApp.activate(ignoringOtherApps: true)
            detailsWindow.makeKeyAndOrderFront(nil)
            return
        }

        let detailsView = ClipwellGuideView()
            .environmentObject(settings)
        let hostingController = NSHostingController(rootView: detailsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = l10n.clipwellGuideTitle
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 620, height: 520))
        window.minSize = NSSize(width: 520, height: 420)
        window.isReleasedWhenClosed = false
        window.center()
        detailsWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct ClipwellGuideView: View {

    @EnvironmentObject private var settings: AppSettings
    private var l10n: SettingsLocalization { SettingsLocalization(settings.language.resolved) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.clipwellGuideTitle)
                        .font(.title2.weight(.semibold))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(l10n.clipwellGuideIntro)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 14) {
                    guideRow(systemImage: "clock.arrow.circlepath", title: l10n.guideHistoryTitle, body: l10n.guideHistoryBody)
                    guideRow(systemImage: "magnifyingglass", title: l10n.guideSearchTitle, body: l10n.guideSearchBody)
                    guideRow(systemImage: "photo.on.rectangle", title: l10n.guideContentTitle, body: l10n.guideContentBody)
                    guideRow(systemImage: "text.viewfinder", title: l10n.guideOCRTitle, body: l10n.guideOCRBody)
                    guideRow(systemImage: "lock.shield", title: l10n.guidePrivacyTitle, body: l10n.guidePrivacyBody)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 520, minHeight: 420)
    }

    private func guideRow(systemImage: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text(body)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
