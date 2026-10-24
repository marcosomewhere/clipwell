# Clipwell: Funktionsvergleich Windows ↔ macOS

Stand der Analyse: 25.10.2026. Ziel: Unterschiede nachvollziehbar festhalten und als Grundlage für die Übernahme einzelner Features verwenden.

## Vergleichsbasis und Aussagekraft

| Version | Untersuchte Basis |
|---|---|
| macOS | Lokaler Checkout `marcosomewhere/clipwell`, Commit `fe6294d272d6860e7dc78aaa513148cc9dcaaa5c` |
| Windows | `marcosomewhere/clipwell_win`, Branch `main`, Commit `68c75acf56954676bd61ee28f859685ae77a8980` |

Grundlage ist eine statische Prüfung von Implementierung und Dokumentation. Die Apps wurden für diesen Vergleich nicht gestartet; die Windows-Tests wurden nicht ausgeführt. „Fehlt“ bedeutet: im untersuchten Stand keine entsprechende Implementierung gefunden. Aufwand und Prioritäten sind Einschätzungen, keine Zusagen.

Windows-Quellen sind unten auf den untersuchten Commit fixiert. Mac-Pfade beziehen sich auf `Sources/Clipwell/` im übergeordneten Repository-Verzeichnis. C#/WPF-Code lässt sich nicht direkt nach SwiftUI/AppKit kopieren; übertragbar sind Verhalten, Datenmodell und Algorithmen.

## Funktionsmatrix

| Funktion | macOS | Windows | Konsequenz |
|---|---|---|---|
| Menüleisten-/Tray-App, persistente History | Vorhanden | Vorhanden | Gemeinsamer Kern |
| Globales Öffnen | Fest `⌘⇧V` | Konfigurierbar, Recorder und Fallback-Kombinationen | Windows-Konfiguration auf Mac übernehmen |
| Alternative Hotkey-Aktion | Picker öffnen | Popup öffnen oder neuesten Eintrag einfügen | Mac optional erweitern |
| Suche | Inhalt, Typbezeichnung, URL-Titel, OCR | Inhalt, OCR, URL-Titel, Codesprache; zusätzlich Präfixe | Erweiterte Suche übernehmen |
| Typfilter / nur Gepinnte | Keine dedizierten Filter-Chips | Text, Code, URL, Bild, Farbe, Gepinnt | Mac-Toolbar erweitern |
| Sortierung / Gruppierung | Neu/alt, Typ, Quell-App; Gruppen nach Datum, Typ, App oder keine | Gepinnte und Zeitgruppen | Mac ist hier flexibler |
| Text und Bilder | Vorhanden | Vorhanden | Gemeinsamer Kern |
| Datei-Referenzen | Eigener Typ, mehrere Dateien, Dateinamen und Wiederherstellung als Datei-URLs | Kein allgemeiner Datei-History-Typ; Pinboard liest unterstützte Text-/Bilddateien als Inhalt ein | Bei Übernahme Mac-Dateityp erhalten |
| Rich Text | RTF wird neben Klartext gespeichert und wiederhergestellt | Speicherung überwiegend als Text; Wiederherstellung über `SetText` | Keine Rich-Text-Parität |
| Plaintext-Einfügen | Vorhanden; bei Bildern OCR, bei Dateien Pfade | Eigener Befehl; Bilder werden im Schreibpfad trotzdem als Bild behandelt | Mac-Verhalten erhalten |
| Text bearbeiten | Einfaches Sheet mit Zeichenzähler und Speichern | Detaileditor mit Zeilennummern, Wrap, Sprachwahl, Hervorhebung und Datei-Export | Editor gezielt ausbauen |
| Code-Erkennung | Generisches „Code“, keine Sprachzuordnung | Sprachzuordnung, Erkennungsmodi, Content-Kind und Begründung | Metadaten optional erweitern |
| Typ manuell ändern | Keine entsprechende Aktion | Als Text / Code behandeln | Sinnvolle kleine Erweiterung |
| Bildvorschau / OCR-Suche | Vorhanden | Vorhanden | Kein neues Basisfeature |
| OCR-Text anzeigen / kopieren | Keine eigene OCR-Ansicht; über Plaintext-Paste nutzbar | Umschaltbare OCR-Textansicht | Mac-Vorschau erweitern |
| Bilder bearbeiten / exportieren | Skalierte Vorschau, keine Bearbeitungswerkzeuge | Zoom, Annotationen, Crop, Resize, Rand erweitern, Undo/Redo, PNG-Export | Größeres eigenständiges Feature |
| Farberkennung / Farbdetails | Kein eigener Farbtyp | Hex-Erkennung, Vorschau, HEX/RGB/HSL sowie CSS-Deklaration und Tailwind-Arbitrary-Value | Als Text-Metadaten gut übertragbar |
| Bildschirm-Pipette | Fehlt | Overlay zur Aufnahme einer Bildschirmfarbe | Nativ für macOS umsetzen |
| Schnellnotizen | Fehlen | Direkt erzeugte, gepinnte Texteinträge mit `NOTE`-Badge | Kleine, unabhängige Erweiterung |
| Separates Pinboard | Fehlt | Eigenes dauerhaft sichtbares Fenster mit gepinnten Einträgen | Mac-`NSPanel` als Grundlage |
| Drag & Drop | Keine entsprechende History-Drag-/Drop-Implementierung gefunden | Aus Popup/Pinboard heraus, ins Pinboard hinein | Getrennt von Datei-History betrachten |
| Mehrfachauswahl | Fehlt | Alle sichtbaren auswählen, pinnen/lösen, löschen, JSON exportieren | Repository-Batchaktionen ergänzen |
| JSON-Export / -Import | Fehlt | Gesamte History oder Auswahl; Import mit Dublettenprüfung | Hohe Übernahmepriorität |
| Backups | Keine Benutzerfunktion | SQLite-Kopie und tägliches JSON-Backup beim Start, Rotation auf sieben Dateien | JSON-Backup auch ohne SQLite möglich |
| History-Limits | Anzahl, Pins geschützt | Anzahl, Alter und optionale DB-Größe, Pins geschützt | Alter sinnvoll; Größenlimit braucht eigenes Konzept |
| Dubletten | Drei Einstellungsmodi, Text wird vorgelagert normalisiert zusammengeführt | Globale Zusammenführung nach Typ und Inhalt, Bilder byteweise | Verhalten vor Vereinheitlichung festlegen |
| App-Ausschlüsse / Quell-App | Bundle-ID-Ausschlüsse, App-Name und Gruppierung | Kein entsprechendes Feld/Filter in untersuchten Modellen | Mac-Vorteil; Kandidat für Windows |
| URL-Metadaten | Titel/Favicon automatisch, Google-Fallback | Schalter, Nachladen, Cache mit sieben Tagen TTL, Adressprüfung | Datenschutz und Kontrolle auf Mac verbessern |
| Monitoring pausieren / Autostart | Vorhanden | Vorhanden | Gemeinsamer Kern |
| UI-Sprache | System sowie EN/DE/PL/FR; einzelne Editor-Texte noch Englisch | Keine vergleichbare Sprachauswahl gefunden | Mac-Lokalisierung erhalten und vervollständigen |
| Darstellung | Native Systemfarben | System, hell, dunkel und Compact-Modus | Optional, geringere Priorität |
| Fenstergröße | Picker-View fest 400 Punkte breit | Popup verschieb-/skalierbar, Größe gespeichert | Anpassbare Mac-Overlaygröße erwägen |
| Onboarding | Keine vergleichbare geführte Erststartstrecke gefunden | Erststartfenster und Hotkey-Test | Optional mit Mac-Berechtigungsstatus verbinden |

Belege: Mac insbesondere `Models/AppSettings.swift`, `Models/ClipboardContent.swift`, `Models/ContentAnalysis.swift`, `Storage/ClipboardRepository.swift`, `UI/PopoverView.swift`, `UI/SettingsView.swift`, `Services/PasteService.swift`. Windows: [Einstellungen](https://github.com/marcosomewhere/clipwell_win/blob/68c75acf56954676bd61ee28f859685ae77a8980/ClipwellWin/Models/AppSettings.cs), [Popup-Logik und Suche](https://github.com/marcosomewhere/clipwell_win/blob/68c75acf56954676bd61ee28f859685ae77a8980/ClipwellWin/ViewModels/PopupViewModel.cs), [Clipboard-Erfassung](https://github.com/marcosomewhere/clipwell_win/blob/68c75acf56954676bd61ee28f859685ae77a8980/ClipwellWin/Services/ClipboardProcessor.cs), [App-Integration und Paste](https://github.com/marcosomewhere/clipwell_win/blob/68c75acf56954676bd61ee28f859685ae77a8980/ClipwellWin/App.xaml.cs).

## Übernahmepakete für macOS

Die Reihenfolge priorisiert kleine nützliche Erweiterungen und Datentransport vor umfangreicher Bildbearbeitung. Aufwand: **klein** = begrenzter Eingriff, **mittel** = mehrere Schichten, **groß** = neues Teilsystem. Die folgenden Namen neuer Methoden/Typen sind Vorschläge.

### 1. Schnellnotizen — Priorität hoch, Aufwand klein

**Windows-Verhalten:** `PopupViewModel.AddQuickNote` erzeugt einen gepinnten Texteintrag, ohne vorheriges Kopieren. Der Eintrag erhält `ContentKind = NOTE`. Eingabe und Tastatursteuerung liegen in `PopupWindow`.

**Mac-Umsetzung:**

- In `ClipboardRepository` eine explizite `addQuickNote(text:)`-Mutation ergänzen. Sie erzeugt `.text(plain:rtfData:nil)` mit neuer UUID und `isPinned = true`.
- Notizherkunft als optionales, rückwärtskompatibles Metadatum speichern; `isEditedByUser` beschreibt etwas anderes.
- Eingabe in `PopoverView`: Enter speichern, Shift+Enter Zeilenumbruch, Escape abbrechen. Strings in `AppLocalization.swift` ergänzen.
- Die normale `addItem`-Dublettenlogik nicht ungeprüft verwenden: Sie könnte eine neue Notiz mit einem vorhandenen normalisierten Text zusammenführen.

**Abnahme:** Notiz bleibt nach Neustart erhalten, überlebt das History-Limit, ändert beim Erstellen die Zwischenablage nicht und ist unabhängig von einer gleichlautenden alten Kopie.

### 2. Erweiterte Suche, Filter und manuelle Klassifikation — Priorität hoch, Aufwand mittel

**Windows-Verhalten:** `PopupViewModel.Filter` versteht `type:`, `kind:`, `domain:` und exakt `pinned:true/false`; Popup ergänzt Chips und Vorschläge. `SetType` erlaubt manuelles Umschalten zwischen Text und Code.

**Mac-Umsetzung:**

- Suchausdruck getrennt von der UI parsen, dann in `ClipboardRepository.search` auswerten. Zunächst ein Präfix pro Abfrage reicht für Parität.
- Filterzustand für Typ und „nur gepinnt“ in `PopoverView` ergänzen; vorhandene Sortierung/Gruppierung darauf anwenden.
- URL/Code als abgeleitete Typen über `effectiveAnalysis` abbilden; `fileReferences` bleibt eigener Nutzlasttyp.
- Für `kind:` ein optionales Format-/Badge-Feld ergänzen. Ein generisches Code-Flag kann JSON, TOML usw. nicht unterscheiden.
- Für „Als Text/Code behandeln“ ein explizites Override persistieren. Automatische Neuanalyse und manuelle Entscheidung müssen unterscheidbar bleiben.

**Bewusste Verbesserung gegenüber Windows:** `domain:` vergleicht dort nur Teilstrings der gesamten URL. Auf dem Mac den geparsten Host vergleichen, damit `https://evil.example/?x=github.com` nicht als GitHub-Domain zählt. Windows kombiniert Präfixe nicht als vollwertige Abfragesprache; Mehrfachkriterien wären zusätzlicher Umfang.

**Abnahme:** Präfixe, freie Suche, OCR und Chips funktionieren mit Pin-/Typ-/Datumsgruppen zusammen. Manuelles Override bleibt nach Neustart erhalten. Unbekannte Präfixe erhalten ein festgelegtes, verständliches Verhalten.

### 3. Import, Export und automatische Backups — Priorität hoch, Aufwand mittel

**Windows-Verhalten:** `DatabaseService.ExportAsJson` exportiert Metadaten und Base64-Bilder/Favicons, optional nur eine Auswahl. `ImportFromJson` überspringt Einträge mit identischem Timestamp und Inhalt. `App.RunAutoBackupIfNeeded` startet höchstens einmal pro Tag beim App-Start ein Backup; `AutoBackupIfNeeded` behält sieben Dateien.

**Mac-Umsetzung:**

- Separaten Transportdienst für `NSSavePanel`/`NSOpenPanel` und versionierte JSON-Daten ergänzen; `PersistenceStore` bleibt zunächst unverändert.
- Ein gemeinsames Format definieren, wenn Windows-Dateien importierbar sein sollen. Das bestehende Mac-`Codable`-Format und der Windows-Export sind nicht kompatibel.
- OCR aus `OCRIndex` ausdrücklich mit exportieren; im Mac-`ClipboardItem` steckt der OCR-Text nicht.
- Import erst vollständig validieren und als Vorschau zählen, anschließend gesammelt übernehmen und einmal persistieren. Größenlimits, defekte Base64-Daten und unbekannte Typen verständlich behandeln.
- Backup-Ziel, Aktivierung und letzten erfolgreichen Lauf in Einstellungen ablegen; erst nach erfolgreichem Schreiben rotieren. „Täglich beim Start“ ist kein Hintergrund-Zeitplan bei laufender App.

**Vorgeschlagenes gemeinsames Format:** `schemaVersion`, `exportedAt`, `items[]`; pro Eintrag stabile Transport-ID, ISO-8601-Zeit mit Zeitzone, Nutzlasttyp, Text, optional RTF, Bild/Thumbnail, OCR, URL-Metadaten, Pinstatus, Quell-App und Klassifikation. Windows-Integer-IDs beim Import auf neue Mac-UUIDs abbilden. Unbekannte optionale Felder tolerieren. Datei-Referenzen als Referenzen kennzeichnen: Sie übertragen die Dateien selbst nicht und Windows-Pfade sind auf macOS normalerweise unbrauchbar.

**Abnahme:** Export → leere History → Import erhält Text, Bild, OCR, Pins und Metadaten. Ein zweiter Import vervielfacht dieselben Einträge nicht. Defekte Dateien beschädigen keine vorhandene History. Windows-Import mit echten Exportbeispielen gesondert prüfen.

**Nicht kopieren:** Windows verschluckt Fehler einzelner Importdatensätze und prüft Dubletten nur über Zeit und Text; verschiedene Bilder ohne Text können dadurch kollidieren. Für ein gemeinsames Format Transport-ID bzw. Inhalts-Hash verwenden und übersprungene/fehlerhafte Datensätze melden.

Quelle: [Datenbank, Export, Import und Backup](https://github.com/marcosomewhere/clipwell_win/blob/68c75acf56954676bd61ee28f859685ae77a8980/ClipwellWin/Services/DatabaseService.cs).

### 4. URL-Vorschauen kontrollierbar machen — Priorität hoch, Aufwand mittel

**Windows-Verhalten:** Aktivierungsschalter, manuelles Nachladen, SQLite-Cache mit sieben Tagen TTL; `ShouldFetch` blockiert localhost und erkannte private/Loopback-/Link-Local-IP-Adressen. Favicons stammen aus HTML-Links oder `/favicon.ico`.

**Mac-Umsetzung:**

- `urlPreviewEnabled` in `AppSettings` und einen Schalter in `SettingsView` ergänzen. `ClipboardMonitor` und `URLMetadataService.enrich` müssen die Einstellung beachten.
- Gemeinsame Request-Prüfung für Seiten, Redirects und Favicons verwenden; nur HTTP(S), öffentliche Zieladressen, begrenzte Antwortgröße und Zeitlimits.
- Cache nach normalisierter URL mit Ablaufzeit aufbauen; kann zunächst JSON sein. Kontextaktion zum Nachladen und Einstellung zum Leeren ergänzen.
- Den aktuellen Google-Favicon-Fallback ausdrücklich überdenken: Er übermittelt die Domain an einen weiteren Dienst. Windows benötigt diesen Fallback nicht.

**Abnahme:** Bei deaktivierter Vorschau entstehen keine Vorschau-Requests. Lokale/private Ziele werden auch über Weiterleitungen und Favicon-Links abgewiesen. Erneuter Abruf nutzt den Cache, erzwungenes Nachladen erneuert ihn.

**Grenze der Windows-Vorlage:** `ShouldFetch` prüft Hostnamen nicht durch DNS-Auflösung; `FetchAsync` prüft Redirect- und Favicon-Ziele nicht erneut. Das ist eine Teilabsicherung und sollte nicht als vollständiger Schutz übernommen werden.

Quellen: [URL-Service Windows](https://github.com/marcosomewhere/clipwell_win/blob/68c75acf56954676bd61ee28f859685ae77a8980/ClipwellWin/Services/UrlPreviewService.cs), Mac `Services/URLMetadataService.swift` und `Services/ClipboardMonitor.swift`.

### 5. Mehrfachauswahl — Priorität mittel, Aufwand mittel

**Windows-Verhalten:** Bulk-Modus mit Checkboxen; alle sichtbaren auswählen, pinnen/lösen, löschen und exportieren. Löschen fragt einmal für die gesamte Auswahl nach.

**Mac-Umsetzung:** Ausgewählte UUIDs als `Set<UUID>` in `PopoverView` führen. Repository um Batchmethoden erweitern, die erst alle Mutationen ausführen und dann einmal sortieren/persistieren. Export an Paket 3 anbinden. Beim Filterwechsel definieren, ob unsichtbare ausgewählte Einträge ausgewählt bleiben; „Alle auswählen“ sollte eindeutig nur sichtbare Treffer meinen.

**Abnahme:** Veränderte Sortierung zerstört die Auswahl nicht. Einträge werden anhand ihrer IDs bearbeitet. Massen-Pinnen speichert nicht für jeden einzelnen Eintrag erneut die komplette JSON-History.

Quelle: [Popup-Aktionen Windows](https://github.com/marcosomewhere/clipwell_win/blob/68c75acf56954676bd61ee28f859685ae77a8980/ClipwellWin/Views/PopupWindow.xaml.cs).

### 6. Separates Pinboard und Drag & Drop — Priorität mittel, Aufwand mittel

**Windows-Verhalten:** Eigenes Fenster für Pins; beobachtet Änderungen an Sammlung und Pinstatus. Drag-out als Text/Bild; Drop-in verarbeitet unterstützte Bild-/Textdaten und Dateien, deren Inhalte gelesen werden.

**Mac-Umsetzung:** Eigenen Controller für ein schwebendes `NSPanel` ergänzen, bestehendes `ClipboardRepository` injizieren und nur Pins anzeigen. Fenster schließen blendet es aus. Zuvor aktive Ziel-App für Einfügen korrekt weitergeben; der vorhandene `PasteService` kann genutzt werden. Drag & Drop über native Pasteboard-/SwiftUI-Schnittstellen anbinden. Bei Dateien bewusst zwischen „Referenz pinnen“ und „Inhalt importieren“ unterscheiden.

**Abnahme:** Pinboard bleibt beim Schließen des Pickers sichtbar und aktualisiert sich beim Entpinnen/Löschen sofort. Einfügen trifft die Ziel-App. Große oder unbekannte Drop-Dateien blockieren die UI nicht.

Quelle: [Pinboard Windows](https://github.com/marcosomewhere/clipwell_win/blob/68c75acf56954676bd61ee28f859685ae77a8980/ClipwellWin/Views/PinboardWindow.xaml.cs).

### 7. Hotkey-Konfiguration und Popup-Shortcuts — Priorität mittel, Aufwand mittel

**Windows-Verhalten:** Globaler Hotkey mit Recorder, Registrierungsstatus und Fallbacks; Aktion „Öffnen“ oder „neuesten Eintrag einfügen“. Separate konfigurierbare Popup-Shortcuts für Pin, Details, Notiz und Pinboard.

**Mac-Umsetzung:** Festwerte in `HotkeyController` durch persistierte Taste/Modifier ersetzen. Registrierung soll ein auswertbares Ergebnis liefern; UI zeigt die tatsächlich aktive Kombination. `AppDelegate` entscheidet über die Hotkey-Aktion. Für „neuesten“ nach Datum auswählen, nicht den ersten Listeneintrag nehmen, da Pins vorangestellt sind. Lokale Shortcuts separat verwalten und mit Texteditor-Eingaben abstimmen.

**Abnahme:** Kombination bleibt nach Neustart erhalten. Konflikte werden angezeigt. Ein fehlgeschlagenes Umbelegen lässt die letzte funktionierende Kombination nutzbar. Direktes Einfügen respektiert den vorhandenen macOS-Bedienungshilfenstatus.

### 8. Farben und Bildschirm-Pipette — Priorität mittel, Aufwand mittel

**Windows-Verhalten:** Hexwerte werden erkannt, Details zeigen mehrere Farbformate mit Kopiermöglichkeiten. Die Pipette erzeugt Clipboard-Inhalt und History-Eintrag.

**Mac-Umsetzung:** Farbe zunächst als Analysemetadatum für Text modellieren; vorhandene Textspeicherung und Paste funktionieren weiter. Parser für klar definierte Hexformate sowie Formatkonvertierung ergänzen. Für die Pipette eine native macOS-Farbauswahl prüfen, z. B. `NSColorSampler`; ein eigenes Windows-artiges Bildschirm-Overlay ist kein notwendiger Bestandteil der Portierung.

**Abnahme:** Kurze/lange Hexwerte und gegebenenfalls Alpha werden korrekt interpretiert. Beliebige Textfragmente erzeugen keine überraschende Umklassifizierung. Abbruch der Pipette ändert weder History noch Clipboard.

### 9. Detaileditor, OCR-Ansicht und Datei-Export — Priorität mittel, Aufwand mittel bis groß

**Windows-Verhalten:** `DetailWindow` ergänzt Sprachwahl, Syntax-Overlay, Zeilennummern, Wrap, Zähler, Speichern, OCR-Ansicht sowie Export von Text mit passender Dateiendung.

**Mac-Umsetzung:** `EditItemView` schrittweise erweitern; für eng gekoppelte Zeilennummern, Highlighting und Scrollverhalten ein `NSTextView`-basiertes SwiftUI-Element erwägen. Sprachauswahl benötigt neue optionale Metadaten: `CodeLanguage` kennt auf dem Mac absichtlich nur `.code`. Bestehende gespeicherte Werte müssen weiterhin dekodierbar bleiben. OCR-Ansicht kann unabhängig davon sofort aus `OCRIndex.text(for:)` gespeist werden.

**Abnahme:** Änderungen bleiben unter derselben UUID gespeichert. OCR-Ansicht verändert den ursprünglichen Text nicht. Lange Inhalte bleiben bearbeitbar. RTF-Verlust beim Bearbeiten ist definiert; schon heute speichert `updateText` bearbeitete Inhalte als Klartext.

### 10. Bildeditor — Priorität nach Bedarf, Aufwand groß

**Windows-Verhalten:** Canvas mit Basisbild und Annotationen, Zoom, Undo/Redo, Formen/Pfeilen/Text/Markern, Crop, Resize und Rand-Erweiterung. `RenderEditedImage` erzeugt das zusammengesetzte Bild für Clipboard und PNG-Datei.

**Mac-Umsetzung in getrennten Schritten:**

1. `ImagePreviewView` um Zoom/Pan, PNG-Export und OCR-Text ergänzen.
2. Eigenes Bearbeitungsmodell mit Originalbild, Annotationen und Undo-Zuständen entwickeln; Crop/Resize getrennt von der Vorschau rendern.
3. Formen, Text, Marker und deckendes Schwärzen ergänzen; echte Pixelierung/Blur separat implementieren.
4. Explizit entscheiden, ob „Speichern“ den History-Eintrag ersetzt oder eine bearbeitete Kopie anlegt. Bei neuen Bilddaten Thumbnail und OCR erneuern.

**Wichtige Grenzen:** Windows exportiert/kopiert das gerenderte Bild; daraus folgt keine dauerhafte Speicherung des editierbaren Annotationenmodells im History-Eintrag. `Blur` ist eine halbtransparente graue Fläche. `PixelateBlock` zeichnet ein künstliches Grauraster, statt Bildpixel zu mitteln. Beides als echte Filter zu bezeichnen wäre falsch.

**Abnahme:** Export und Clipboard enthalten dieselben sichtbaren Änderungen. Undo stellt Bildgröße und Annotationen konsistent wieder her. Deckendes Schwärzen wird in die exportierten Pixel eingerechnet. Neu gespeicherte Bilder zeigen keine alten OCR-/Thumbnail-Daten.

Quelle für Pakete 8–10: [Detailfenster und Rendering Windows](https://github.com/marcosomewhere/clipwell_win/blob/68c75acf56954676bd61ee28f859685ae77a8980/ClipwellWin/Views/DetailWindow.xaml.cs), [Format-/Badge-Erkennung](https://github.com/marcosomewhere/clipwell_win/blob/68c75acf56954676bd61ee28f859685ae77a8980/ClipwellWin/Services/ContentKindService.cs), [Code-Erkennung](https://github.com/marcosomewhere/clipwell_win/blob/68c75acf56954676bd61ee28f859685ae77a8980/ClipwellWin/Services/SyntaxService.cs).

### 11. Aufbewahrung und Wiederherstellung — Priorität mittel, Aufwand mittel

**Windows-Verhalten:** Löschen ungepinnter Einträge nach Anzahl/Alter; optionale Größenbereinigung. SQLite startet mit WAL und `quick_check`; bei Fehlern gibt es einen Pfad zum Sichern der beschädigten Daten und Neustart mit leerer DB.

**Mac-Umsetzung:** Optionales maximales Alter in `AppSettings` und zentrale Bereinigung im Repository ergänzen, auch beim Start. Verwaiste OCR-Einträge mit bereinigen. Bei fehlerhafter `history.json` die Datei vor weiteren Schreibvorgängen sichern und Wiederherstellung anbieten; `PersistenceStore.loadHistory` liefert aktuell bei Decode-Fehler nur eine leere Liste.

Für diese Funktionen ist kein SQLite-Wechsel erforderlich. Ein späterer Wechsel braucht eigene Migration mit Rollback, UUID-Erhalt, Bildern und OCR. Windows lädt selbst über `LoadAll` alle Datensätze inklusive BLOBs; SQLite allein liefert noch keine paginierte History.

**Nicht unverändert übernehmen:** Windows-Größenbereinigung entfernt pro Aufruf nur einen Anteil alter Einträge. Dateigröße, WAL und frei gewordene DB-Seiten bilden kein hartes Speicherlimit. `SecureDelete` ist `DELETE` plus `VACUUM`; daraus folgt keine garantierte Entfernung aus Backups, Dateisystem-Snapshots oder sämtlichen Speicherorten. Eine solche Garantie sollte die Mac-UI nicht versprechen.

**Abnahme:** Pins bleiben erhalten. Alter gilt unabhängig von neuen Clipboard-Ereignissen. Beschädigte Ausgangsdaten werden vor einer leeren neuen History gesichert. Gelöschte Einträge hinterlassen keine weiterhin durchsuchbaren OCR-Daten.

## Mac-Funktionen, die auch für Windows interessant sind

| Feature | Einstiegspunkt auf macOS | Übernahmeidee für Windows |
|---|---|---|
| Quell-App und Ausschlüsse | `Services/ClipboardMonitor.swift`, `Models/ClipboardItem.swift`, `UI/SettingsView.swift` | Quellprozess erfassen, Identität persistieren, Ausschlussliste vor dem Speichern anwenden |
| Dateiliste als Nutzlast | `Models/ClipboardContent.swift`, `Services/PasteService.swift` | Eigenen Datei-Typ und `FileDrop`-Wiederherstellung statt nur Dateiinhalte hinzufügen |
| RTF erhalten | `Services/ClipboardMonitor.swift`, `Services/PasteService.swift` | Klartext und Rich-Text-Nutzlast gemeinsam speichern; Plaintext gezielt auswählen |
| Flexible Gruppen und Sortierung | `UI/PopoverView.swift` | Sortierung und Gruppierung unabhängig wählbar machen |
| Mehrsprachige Oberfläche | `UI/AppLocalization.swift`, `Models/AppSettings.swift` | UI-Strings aus Views lösen und Sprachwahl anbieten |
| Bild als OCR-Text einfügen | `Services/PasteService.swift` | Bildzweig muss Plaintext-Auswahl vor Bild-Restore auswerten |

## Abweichungen zwischen Doku und Implementierung

- **Mac-Hotkey:** README nennt „fully customizable“, `HotkeyController.swift` enthält aber feste Konstanten für `⌘⇧V`; `SettingsView` zeigt nur den Wert.
- **Mac-Dubletten:** Die drei Modi sind auswählbar, doch `refreshDuplicateTextItem` läuft vor der Modusauswertung. Wiederholte normalisierte Texte werden damit auch bei „keep all“ zusammengeführt. Das betrifft insbesondere identisch normalisierte Codeblöcke mit anderer Formatierung.
- **Mac-Netzwerk:** README sagt „no network“. `URLMetadataService` lädt tatsächlich Seiten/Favicons und verwendet bei Bedarf Google. In der Featureplanung vom Code ausgehen.
- **Mac-Bildspeicherung:** Kommentare in `PersistenceStore` beschreiben separate Bilddateien; `saveHistory` kodiert aber die vollständigen Items mit den im Modell enthaltenen PNG-/Thumbnail-Daten direkt ins JSON. Größen- und Exportkonzepte daran ausrichten.
- **Windows-Doppelklick:** Das Handbuch beschreibt an unterschiedlichen Stellen Paste und Details. Der Popup-Handler `EntryList_MouseDoubleClick` führt `PasteSelected(false)` aus; Details haben eigene Aktionen.
- **Windows-Fensterposition:** `SaveSizeAndPosition` speichert im untersuchten Code nur Breite/Höhe. Eine gespeicherte Position ist daraus trotz Methodenname und Handbuch nicht ableitbar.
- **Windows-Bildfunktionen:** Drehen/Spiegeln werden im Handbuch genannt, in der geprüften Detailfenster-Implementierung wurden keine entsprechenden Handler gefunden. Nicht als gesicherte Übernahmevorlage einplanen.
- **Windows-Farbformate:** `ShowColor` erzeugt eine CSS-Deklaration und `text-[#…]` für Tailwind. Eine Suche nach benannten CSS-Farben oder der nächsten Tailwind-Palettenfarbe ist damit trotz Handbuchbeschreibung nicht umgesetzt.
- **Windows-Blur/Pixelierung und „sicher löschen“:** Die oben beschriebenen Implementierungsgrenzen sind enger als manche Formulierungen im Handbuch.

Dokumentationsquellen Windows: [Handbuch](https://github.com/marcosomewhere/clipwell_win/blob/68c75acf56954676bd61ee28f859685ae77a8980/docs/handbuch.md), [Status](https://github.com/marcosomewhere/clipwell_win/blob/68c75acf56954676bd61ee28f859685ae77a8980/docs/STATUS.md). Bei Widersprüchen wurde die Implementierung höher gewichtet.

## Empfohlene Umsetzungsetappen

1. **Kleine Alltagsfunktionen:** Schnellnotiz, OCR-Textansicht, Typ-/Pinfilter und manuelles Klassifikations-Override.
2. **Daten und Kontrolle:** versionierter JSON-Import/-Export, Backups, URL-Schalter und abgesicherte Vorschau-Requests.
3. **Organisation:** Mehrfachauswahl, Pinboard, Hotkey-Konfiguration, Alterslimit und Wiederherstellung bei defekten Daten.
4. **Spezialwerkzeuge:** Farbdetails/Pipette, erweiterter Codeeditor und bei tatsächlichem Bedarf ein eigener Bildeditor.

Für jedes Paket zuerst das gewünschte Verhalten festlegen und die genannten Abnahmekriterien prüfen. Eine komplette Angleichung der Plattformen ist dafür nicht erforderlich. Diese Datei dokumentiert die Unterschiede und Vorschläge; App-Funktionen wurden im Rahmen dieser Analyse nicht geändert.
