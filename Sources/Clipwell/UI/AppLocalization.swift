// UI/AppLocalization.swift
// Clipwell — Small shared UI localization layer for user-facing strings.

import Foundation

struct SettingsLocalization {
    let selectedLanguage: AppLanguage

    init(_ language: AppLanguage) {
        self.selectedLanguage = language.resolved
    }

    var general: String { text(en: "General", de: "Allgemein", pl: "Ogólne", fr: "Général") }
    var privacy: String { text(en: "Privacy", de: "Datenschutz", pl: "Prywatność", fr: "Confidentialité") }
    var storage: String { text(en: "Storage", de: "Historie", pl: "Pamięć", fr: "Stockage") }
    var about: String { text(en: "About", de: "Über", pl: "O aplikacji", fr: "À propos") }
    var languageLabel: String { text(en: "Language", de: "Sprache", pl: "Język", fr: "Langue") }
    var language: String { languageLabel }

    var behavior: String { text(en: "Behavior", de: "Verhalten", pl: "Zachowanie", fr: "Comportement") }
    var launchAtLogin: String { text(en: "Launch at login", de: "Beim Anmelden starten", pl: "Uruchamiaj przy logowaniu", fr: "Lancer à l'ouverture de session") }
    var autoPaste: String { text(en: "Auto-paste on selection", de: "Beim Auswählen automatisch einfügen", pl: "Wklej automatycznie po wyborze", fr: "Coller automatiquement à la sélection") }
    var autoPasteHelp: String { text(en: "Automatically pastes selected item. Requires Accessibility permission.", de: "Fügt den ausgewählten Eintrag automatisch ein. Benötigt Bedienungshilfen.", pl: "Automatycznie wkleja wybrany element. Wymaga uprawnień dostępności.", fr: "Colle automatiquement l'élément sélectionné. Nécessite l'autorisation d'accessibilité.") }
    var pauseMonitoring: String { text(en: "Pause clipboard monitoring", de: "Zwischenablage-Überwachung pausieren", pl: "Wstrzymaj monitorowanie schowka", fr: "Suspendre la surveillance du presse-papiers") }
    var permissions: String { text(en: "Permissions", de: "Berechtigungen", pl: "Uprawnienia", fr: "Autorisations") }
    var accessibilityAllowed: String { text(en: "Accessibility allowed", de: "Bedienungshilfen erlaubt", pl: "Dostępność dozwolona", fr: "Accessibilité autorisée") }
    var accessibilityMissing: String { text(en: "Accessibility not recognized", de: "Bedienungshilfen nicht erkannt", pl: "Dostępność nierozpoznana", fr: "Accessibilité non reconnue") }
    var openAccessibilitySettings: String { text(en: "Open Settings", de: "Einstellungen öffnen", pl: "Otwórz ustawienia", fr: "Ouvrir les réglages") }
    var accessibilityNote: String { text(en: "Auto-paste only works when macOS trusts the currently running Clipwell binary. In debug builds, remove old Clipwell entries and allow the current one if this stays orange.", de: "Automatisches Einfügen funktioniert nur, wenn macOS die aktuell laufende Clipwell-Binary freigibt. Bei Debug-Builds alte Clipwell-Einträge entfernen und den aktuellen erlauben, falls das orange bleibt.", pl: "Automatyczne wklejanie działa tylko wtedy, gdy macOS ufa aktualnie uruchomionej binarce Clipwell. W kompilacjach debug usuń stare wpisy Clipwell i zezwól na aktualny, jeśli status pozostaje pomarańczowy.", fr: "Le collage automatique fonctionne uniquement si macOS autorise le binaire Clipwell actuellement lancé. En mode debug, supprimez les anciens éléments Clipwell et autorisez l'actuel si ce statut reste orange.") }
    var shortcuts: String { text(en: "Shortcuts", de: "Kurzbefehle", pl: "Skróty", fr: "Raccourcis") }
    var openPickerShortcut: String { text(en: "Open clipboard picker", de: "Zwischenablage-Picker öffnen", pl: "Otwórz wybór schowka", fr: "Ouvrir le sélecteur du presse-papiers") }
    var plainTextShortcut: String { text(en: "Paste as plain text", de: "Als Klartext einfügen", pl: "Wklej jako zwykły tekst", fr: "Coller en texte brut") }
    var shortcutsNote: String { text(en: "Hold Option while clicking or confirming an item to use plain text.", de: "Halte Option beim Klicken oder Bestätigen eines Eintrags, um Klartext zu verwenden.", pl: "Przytrzymaj Option podczas kliknięcia lub potwierdzania elementu, aby użyć zwykłego tekstu.", fr: "Maintenez Option en cliquant ou en validant un élément pour utiliser le texte brut.") }
    var history: String { text(en: "History", de: "Historie", pl: "Historia", fr: "Historique") }
    var duplicateHandling: String { text(en: "Duplicate handling", de: "Duplikate", pl: "Duplikaty", fr: "Doublons") }

    func keepItems(_ count: Int) -> String {
        text(en: "Keep up to \(count) items", de: "Bis zu \(count) Einträge behalten", pl: "Przechowuj do \(count) elementów", fr: "Conserver jusqu'à \(count) éléments")
    }

    func duplicateMode(_ mode: DuplicateHandlingMode) -> String {
        switch mode {
        case .keepAll:
            return text(en: "Keep all copies", de: "Alle Kopien behalten", pl: "Zachowaj wszystkie kopie", fr: "Conserver toutes les copies")
        case .collapseConsecutive:
            return text(en: "Collapse identical consecutive", de: "Gleiche aufeinanderfolgende zusammenfassen", pl: "Scal identyczne kolejne wpisy", fr: "Fusionner les doublons consécutifs")
        case .deduplicateGlobal:
            return text(en: "Deduplicate globally", de: "Global deduplizieren", pl: "Usuń duplikaty globalnie", fr: "Dédupliquer globalement")
        }
    }

    var privacyIntro: String { text(en: "Choose a running app or enter its Bundle ID. A Bundle ID is macOS' unique app identifier, for example com.apple.Safari.", de: "Wähle eine laufende App aus oder gib ihre Bundle-ID ein. Eine Bundle-ID ist die eindeutige App-Kennung von macOS, zum Beispiel com.apple.Safari.", pl: "Wybierz uruchomioną aplikację albo wpisz jej Bundle ID. Bundle ID to unikalny identyfikator aplikacji w macOS, np. com.apple.Safari.", fr: "Choisissez une app en cours d'exécution ou saisissez son Bundle ID. Un Bundle ID est l'identifiant unique d'une app macOS, par exemple com.apple.Safari.") }
    var noAppsIgnored: String { text(en: "No apps ignored", de: "Keine Apps ignoriert", pl: "Brak ignorowanych aplikacji", fr: "Aucune app ignorée") }
    var remove: String { text(en: "Remove", de: "Entfernen", pl: "Usuń", fr: "Supprimer") }
    var ignoredApps: String { text(en: "Ignored Apps", de: "Ignorierte Apps", pl: "Ignorowane aplikacje", fr: "Apps ignorées") }
    var noAppsAvailable: String { text(en: "No apps available", de: "Keine Apps verfügbar", pl: "Brak dostępnych aplikacji", fr: "Aucune app disponible") }
    var addRunningApp: String { text(en: "Add Running App", de: "Laufende App hinzufügen", pl: "Dodaj uruchomioną aplikację", fr: "Ajouter une app active") }
    var filterRunningApps: String { text(en: "Filter running Apps", de: "Laufende Apps filtern", pl: "Filtruj uruchomione aplikacje", fr: "Filtrer les apps actives") }
    var bundleIDPlaceholder: String { text(en: "Bundle ID, e.g. com.apple.Safari", de: "Bundle-ID, z. B. com.apple.Safari", pl: "Bundle ID, np. com.apple.Safari", fr: "Bundle ID, p. ex. com.apple.Safari") }
    var add: String { text(en: "Add", de: "Hinzufügen", pl: "Dodaj", fr: "Ajouter") }
    var addApp: String { text(en: "Add App", de: "App hinzufügen", pl: "Dodaj aplikację", fr: "Ajouter une app") }
    var bundleIDSource: String { text(en: "Clipwell stores the source app Bundle ID with each clipboard item when macOS provides it.", de: "Clipwell speichert die Bundle-ID der Quell-App mit jedem Historieneintrag, wenn macOS sie bereitstellt.", pl: "Clipwell zapisuje Bundle ID aplikacji źródłowej przy każdym elemencie schowka, jeśli macOS ją udostępnia.", fr: "Clipwell enregistre le Bundle ID de l'app source avec chaque élément du presse-papiers lorsque macOS le fournit.") }

    var currentHistory: String { text(en: "Current History", de: "Aktuelle Historie", pl: "Bieżąca historia", fr: "Historique actuel") }
    var totalEntries: String { text(en: "Total entries", de: "Einträge gesamt", pl: "Wszystkie elementy", fr: "Nombre total d'éléments") }
    var pinnedEntries: String { text(en: "Pinned entries", de: "Angeheftete Einträge", pl: "Przypięte elementy", fr: "Éléments épinglés") }
    var imagesStored: String { text(en: "Images stored", de: "Gespeicherte Bilder", pl: "Zapisane obrazy", fr: "Images stockées") }
    var actions: String { text(en: "Actions", de: "Aktionen", pl: "Akcje", fr: "Actions") }
    var clearUnpinned: String { text(en: "Clear Unpinned History", de: "Nicht angeheftete Historie löschen", pl: "Wyczyść nieprzypiętą historię", fr: "Effacer l'historique non épinglé") }
    var clearAll: String { text(en: "Clear All History", de: "Gesamte Historie löschen", pl: "Wyczyść całą historię", fr: "Effacer tout l'historique") }

    var appLanguage: String { text(en: "App language", de: "App-Sprache", pl: "Język aplikacji", fr: "Langue de l'app") }
    var systemLanguageNote: String { text(en: "System uses your macOS language when it is supported, otherwise English.", de: "System verwendet deine macOS-Sprache, wenn sie unterstützt wird, sonst Englisch.", pl: "System używa języka macOS, jeśli jest obsługiwany, w przeciwnym razie angielskiego.", fr: "Système utilise la langue de macOS si elle est prise en charge, sinon l'anglais.") }

    var developmentStatus: String { text(en: "Development status", de: "Entwicklungsstand", pl: "Status rozwoju", fr: "État du développement") }
    var aboutDescription: String { text(en: "Clipwell is open-source, free software built as a lightweight local clipboard utility.", de: "Clipwell ist freie Open-Source-Software als leichtes lokales Zwischenablage-Werkzeug.", pl: "Clipwell to darmowe oprogramowanie open source jako lekki lokalny menedżer schowka.", fr: "Clipwell est un logiciel libre et open source conçu comme un outil local léger pour le presse-papiers.") }
    var openClipwellGuide: String { text(en: "What does Clipwell do?", de: "Was macht Clipwell?", pl: "Co robi Clipwell?", fr: "Que fait Clipwell ?") }
    var clipwellGuideTitle: String { text(en: "About Clipwell", de: "Über Clipwell", pl: "O Clipwell", fr: "À propos de Clipwell") }
    var clipwellGuideIntro: String { text(en: "Clipwell is a small menu bar clipboard manager that keeps your recent copies searchable and close at hand.", de: "Clipwell ist ein kleines Zwischenablage-Werkzeug in der Menüleiste, das deine letzten Kopien durchsuchbar und schnell erreichbar hält.", pl: "Clipwell to mały menedżer schowka w pasku menu, który przechowuje ostatnie kopie i pozwala je szybko wyszukać.", fr: "Clipwell est un petit gestionnaire de presse-papiers dans la barre de menus qui garde vos copies récentes faciles à rechercher et à réutiliser.") }
    var guideHistoryTitle: String { text(en: "Clipboard history", de: "Zwischenablage-Historie", pl: "Historia schowka", fr: "Historique du presse-papiers") }
    var guideHistoryBody: String { text(en: "Text, images, and file references are stored locally and can be recalled later.", de: "Text, Bilder und Dateiverweise werden lokal gespeichert und können später wiederverwendet werden.", pl: "Tekst, obrazy i odwołania do plików są zapisywane lokalnie i można do nich wrócić później.", fr: "Le texte, les images et les références de fichiers sont stockés localement et peuvent être rappelés plus tard.") }
    var guideSearchTitle: String { text(en: "Fast search and selection", de: "Schnelle Suche und Auswahl", pl: "Szybkie wyszukiwanie i wybór", fr: "Recherche et sélection rapides") }
    var guideSearchBody: String { text(en: "Open the picker with Cmd-Shift-V, search your history, and choose an item with the mouse or keyboard.", de: "Öffne den Picker mit Cmd-Shift-V, durchsuche deine Historie und wähle Einträge mit Maus oder Tastatur.", pl: "Otwórz wybór skrótem Cmd-Shift-V, przeszukaj historię i wybierz element myszą lub klawiaturą.", fr: "Ouvrez le sélecteur avec Cmd-Maj-V, recherchez dans l'historique et choisissez un élément à la souris ou au clavier.") }
    var guideContentTitle: String { text(en: "Image and file support", de: "Bilder und Dateien", pl: "Obsługa obrazów i plików", fr: "Images et fichiers") }
    var guideContentBody: String { text(en: "Image thumbnails, file names, previews, pinning, editing, and deletion are available from the history list.", de: "Bild-Thumbnails, Dateinamen, Vorschau, Anheften, Bearbeiten und Löschen sind direkt in der Historie verfügbar.", pl: "Miniatury obrazów, nazwy plików, podgląd, przypinanie, edycja i usuwanie są dostępne na liście historii.", fr: "Les miniatures d'images, noms de fichiers, aperçus, épinglage, édition et suppression sont disponibles dans l'historique.") }
    var guideOCRTitle: String { text(en: "OCR for images", de: "OCR für Bilder", pl: "OCR dla obrazów", fr: "OCR pour les images") }
    var guideOCRBody: String { text(en: "Text recognized in copied images becomes searchable and can be pasted as plain text.", de: "Erkannter Text in kopierten Bildern wird durchsuchbar und kann als Klartext eingefügt werden.", pl: "Tekst rozpoznany na skopiowanych obrazach można wyszukiwać i wkleić jako zwykły tekst.", fr: "Le texte reconnu dans les images copiées devient recherchable et peut être collé en texte brut.") }
    var guidePrivacyTitle: String { text(en: "Local and private", de: "Lokal und privat", pl: "Lokalnie i prywatnie", fr: "Local et privé") }
    var guidePrivacyBody: String { text(en: "Clipboard history stays on this Mac. You can pause monitoring and ignore selected apps.", de: "Die Zwischenablage-Historie bleibt auf diesem Mac. Du kannst die Überwachung pausieren und ausgewählte Apps ignorieren.", pl: "Historia schowka pozostaje na tym Macu. Możesz wstrzymać monitorowanie i ignorować wybrane aplikacje.", fr: "L'historique reste sur ce Mac. Vous pouvez suspendre la surveillance et ignorer certaines apps.") }
    var security: String { text(en: "Security", de: "Sicherheit", pl: "Bezpieczeństwo", fr: "Sécurité") }
    var localHistory: String { text(en: "Your clipboard history stays on this Mac.", de: "Deine Zwischenablage-Historie bleibt auf diesem Mac.", pl: "Historia schowka pozostaje na tym Macu.", fr: "Votre historique du presse-papiers reste sur ce Mac.") }
    var noUpload: String { text(en: "Clipwell does not upload clipboard content, send analytics, or contact external services for clipboard history.", de: "Clipwell lädt keine Inhalte der Zwischenablage hoch, sendet keine Analysen und kontaktiert keine externen Dienste für die Historie.", pl: "Clipwell nie przesyła zawartości schowka, nie wysyła analityki ani nie kontaktuje się z usługami zewnętrznymi w sprawie historii schowka.", fr: "Clipwell ne téléverse pas le contenu du presse-papiers, n'envoie pas d'analytics et ne contacte aucun service externe pour l'historique.") }

    var searchClipboard: String { text(en: "Search clipboard...", de: "Zwischenablage durchsuchen...", pl: "Przeszukaj schowek...", fr: "Rechercher dans le presse-papiers...") }
    var monitoringPausedHelp: String { text(en: "Clipboard monitoring is paused", de: "Zwischenablage-Überwachung ist pausiert", pl: "Monitorowanie schowka jest wstrzymane", fr: "La surveillance du presse-papiers est suspendue") }
    var sortHistory: String { text(en: "Sort history", de: "Historie sortieren", pl: "Sortuj historię", fr: "Trier l'historique") }
    var groupHistory: String { text(en: "Group history", de: "Historie gruppieren", pl: "Grupuj historię", fr: "Grouper l'historique") }
    var noClipboardHistory: String { text(en: "No clipboard history", de: "Keine Zwischenablage-Historie", pl: "Brak historii schowka", fr: "Aucun historique du presse-papiers") }
    var noResults: String { text(en: "No results", de: "Keine Ergebnisse", pl: "Brak wyników", fr: "Aucun résultat") }
    var clear: String { text(en: "Clear", de: "Leeren", pl: "Wyczyść", fr: "Effacer") }
    var plainTextHint: String { text(en: "⌥ = plain text", de: "⌥ = Klartext", pl: "⌥ = zwykły tekst", fr: "⌥ = texte brut") }
    var pasteShortcut: String { text(en: "⌘⇧V paste", de: "⌘⇧V einfügen", pl: "⌘⇧V wklej", fr: "⌘⇧V coller") }
    var openClipwell: String { text(en: "Open Clipwell", de: "Clipwell öffnen", pl: "Otwórz Clipwell", fr: "Ouvrir Clipwell") }
    var resume: String { text(en: "Resume", de: "Fortsetzen", pl: "Wznów", fr: "Reprendre") }
    var pause: String { text(en: "Pause", de: "Pause", pl: "Pauza", fr: "Pause") }
    var settings: String { text(en: "Settings", de: "Einstellungen", pl: "Ustawienia", fr: "Réglages") }
    var quitClipwell: String { text(en: "Quit Clipwell", de: "Clipwell beenden", pl: "Zamknij Clipwell", fr: "Quitter Clipwell") }
    var unknownApp: String { text(en: "Unknown App", de: "Unbekannte App", pl: "Nieznana aplikacja", fr: "App inconnue") }
    var today: String { text(en: "Today", de: "Heute", pl: "Dzisiaj", fr: "Aujourd'hui") }
    var yesterday: String { text(en: "Yesterday", de: "Gestern", pl: "Wczoraj", fr: "Hier") }
    var imagePreviewUnavailable: String { text(en: "Preview unavailable", de: "Vorschau nicht verfügbar", pl: "Podgląd niedostępny", fr: "Aperçu indisponible") }
    var close: String { text(en: "Close", de: "Schließen", pl: "Zamknij", fr: "Fermer") }

    func shortDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = Locale(identifier: localeIdentifier)
            formatter.unitsStyle = .full
            return formatter.localizedString(for: date, relativeTo: Date())
        }
        if calendar.isDateInYesterday(date) {
            return yesterday
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    func sortMode(_ mode: ClipboardSortMode) -> String {
        switch mode {
        case .newest: return text(en: "Newest", de: "Neueste", pl: "Najnowsze", fr: "Plus récent")
        case .oldest: return text(en: "Oldest", de: "Älteste", pl: "Najstarsze", fr: "Plus ancien")
        case .type: return text(en: "Type", de: "Typ", pl: "Typ", fr: "Type")
        case .sourceApp: return text(en: "App", de: "App", pl: "Aplikacja", fr: "App")
        }
    }

    func groupMode(_ mode: ClipboardGroupMode) -> String {
        switch mode {
        case .none: return text(en: "None", de: "Keine", pl: "Brak", fr: "Aucun")
        case .date: return text(en: "Date", de: "Datum", pl: "Data", fr: "Date")
        case .type: return text(en: "Type", de: "Typ", pl: "Typ", fr: "Type")
        case .sourceApp: return text(en: "App", de: "App", pl: "Aplikacja", fr: "App")
        }
    }

    func typeLabel(for item: ClipboardItem) -> String {
        if item.effectiveAnalysis?.detectedURL != nil { return "URL" }
        switch item.content {
        case .text: return text(en: "Text", de: "Text", pl: "Tekst", fr: "Texte")
        case .image: return text(en: "Image", de: "Bild", pl: "Obraz", fr: "Image")
        case .fileReferences: return text(en: "Files", de: "Dateien", pl: "Pliki", fr: "Fichiers")
        }
    }

    var code: String { text(en: "Code", de: "Code", pl: "Kod", fr: "Code") }
    var paste: String { text(en: "Paste", de: "Einfügen", pl: "Wklej", fr: "Coller") }
    var pasteAsPlainText: String { text(en: "Paste as Plain Text", de: "Als Klartext einfügen", pl: "Wklej jako zwykły tekst", fr: "Coller en texte brut") }
    var edit: String { text(en: "Edit...", de: "Bearbeiten...", pl: "Edytuj...", fr: "Modifier...") }
    var preview: String { text(en: "Preview...", de: "Vorschau...", pl: "Podgląd...", fr: "Aperçu...") }
    var pin: String { text(en: "Pin", de: "Anheften", pl: "Przypnij", fr: "Épingler") }
    var unpin: String { text(en: "Unpin", de: "Lösen", pl: "Odepnij", fr: "Désépingler") }
    var delete: String { text(en: "Delete", de: "Löschen", pl: "Usuń", fr: "Supprimer") }

    private func text(en: String, de: String, pl: String, fr: String) -> String {
        switch selectedLanguage {
        case .german: return de
        case .polish: return pl
        case .french: return fr
        case .system, .english: return en
        }
    }

    private var localeIdentifier: String {
        switch selectedLanguage {
        case .german: return "de_DE"
        case .polish: return "pl_PL"
        case .french: return "fr_FR"
        case .system, .english: return "en_US"
        }
    }
}
