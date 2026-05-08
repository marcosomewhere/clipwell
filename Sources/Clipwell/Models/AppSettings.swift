// Models/AppSettings.swift
// Clipwell — Persisted user preferences.

import Foundation

final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    // MARK: - History

    @Published var maxHistoryCount: Int {
        didSet { UserDefaults.standard.set(maxHistoryCount, forKey: Keys.maxHistoryCount) }
    }

    @Published var duplicateHandling: DuplicateHandlingMode {
        didSet { UserDefaults.standard.set(duplicateHandling.rawValue, forKey: Keys.duplicateHandling) }
    }

    // MARK: - Behavior

    @Published var autoPasteOnSelection: Bool {
        didSet { UserDefaults.standard.set(autoPasteOnSelection, forKey: Keys.autoPasteOnSelection) }
    }

    @Published var monitoringPaused: Bool {
        didSet { UserDefaults.standard.set(monitoringPaused, forKey: Keys.monitoringPaused) }
    }

    // MARK: - Privacy

    @Published var excludedAppBundleIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(excludedAppBundleIDs), forKey: Keys.excludedAppBundleIDs)
        }
    }

    // MARK: - Language

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Keys.language) }
    }

    // MARK: - Init

    private init() {
        let d = UserDefaults.standard
        self.maxHistoryCount     = d.object(forKey: Keys.maxHistoryCount) as? Int ?? 200
        let rawDupe              = d.string(forKey: Keys.duplicateHandling) ?? ""
        self.duplicateHandling   = DuplicateHandlingMode(rawValue: rawDupe) ?? .collapseConsecutive
        self.autoPasteOnSelection = d.object(forKey: Keys.autoPasteOnSelection) as? Bool ?? false
        self.monitoringPaused    = d.object(forKey: Keys.monitoringPaused) as? Bool ?? false
        self.excludedAppBundleIDs = Set(d.stringArray(forKey: Keys.excludedAppBundleIDs) ?? [])
        self.language             = AppLanguage(rawValue: d.string(forKey: Keys.language) ?? "") ?? .system
    }

    private enum Keys {
        static let maxHistoryCount      = "maxHistoryCount"
        static let duplicateHandling    = "duplicateHandling"
        static let autoPasteOnSelection = "autoPasteOnSelection"
        static let monitoringPaused     = "monitoringPaused"
        static let excludedAppBundleIDs = "excludedAppBundleIDs"
        static let language             = "language"
    }
}

// MARK: - AppLanguage

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case german
    case polish
    case french

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .german: return "Deutsch"
        case .polish: return "Polski"
        case .french: return "Français"
        }
    }

    var resolved: AppLanguage {
        guard self == .system else { return self }
        let languageCode = Locale.preferredLanguages.first?
            .split(separator: "-")
            .first?
            .lowercased()

        switch languageCode {
        case "de": return .german
        case "pl": return .polish
        case "fr": return .french
        default: return .english
        }
    }
}

// MARK: - DuplicateHandlingMode

enum DuplicateHandlingMode: String, CaseIterable, Identifiable {
    case keepAll             = "keepAll"
    case collapseConsecutive = "collapseConsecutive"
    case deduplicateGlobal   = "deduplicateGlobal"

    var id: String { rawValue }
}
