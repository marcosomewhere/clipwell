# Clipwell 1.3 – macOS-Modernisierung

## Bedienung

Die zusätzliche Werkzeugleiste im Picker enthält Pinboard, Screenshot-Auswahl, Vollbild-Screenshot des Hauptbildschirms und Farbpicker. Das Design folgt den nativen Systemfarben; Bild- und Textwerkzeuge öffnen sich in separaten, skalierbaren Fenstern.

- **Pinboard:** dauerhaftes schwebendes Fenster, eigene Suche, Drag & Drop von History-Einträgen, externem Text, Bildern und Datei-Referenzen. Ziehen aus dem Pinboard kopiert den Inhalt. Rechtsklick bietet Einfügen, Bearbeiten, Entpinnen und Löschen. Datei-Drops speichern Referenzen, keine Dateikopien.
- **Shortcuts:** Einstellungen → Shortcuts. Globales Öffnen des Pickers, Pinboard, beide Screenshot-Aktionen und Farbpicker lassen sich separat zuweisen oder deaktivieren. Standard: `⌘⇧V` und `⌘⇧B`. Während der Aufnahme sind Clipwell-Hotkeys ausgesetzt. Doppelte Zuweisungen und Registrierungsfehler werden angezeigt.
- **URLs:** erkannte Webadressen haben ein Link-Symbol und einen Globus zum Öffnen der Website. Die vorhandene Titel-/Favicon-Anreicherung bleibt bestehen.
- **Screenshots:** Auswahl nutzt den nativen macOS-Auswahlmodus; Escape bricht ab. Vollbild erfasst den Hauptbildschirm. Clipwell-Fenster werden vor der Aufnahme ausgeblendet. Ergebnis landet in Zwischenablage und History; OCR läuft automatisch. macOS verlangt dafür die Freigabe zur Bildschirmaufnahme.
- **Farbpicker:** native Bildschirm-Pipette, Hexwert in Zwischenablage und History. Escape verändert keine Daten.
- **Export:** Einstellungen → Speicher → JSON-Export. Enthält versionierte Daten, Bilder, OCR, Pins und Metadaten; keine automatische Übertragung. Das Format ist ein Mac-Export und kein ungeprüft kompatibler Windows-Import.

## Editoren

Text- und Bildeditor haben immer **Speichern**, **Speichern unter** und **Kopieren**. Speichern schreibt zunächst in die History; nach „Speichern unter“ schreibt weiteres Speichern in die gewählte Datei. Ungespeicherte Änderungen werden beim Schließen abgefragt.

### Text / Skript

Umschaltbar zwischen Text und Skript, ohne Sprachbezeichnungen. Skriptansicht mit Monospace, Zeilennummern, allgemeiner Syntaxhervorhebung und nativer Text-/Codeauswahl. Hinzu kommen Umbruch, Undo/Redo, Zeichen-/Zeilenzähler, Suchen/Ersetzen und Einrücken. „Kopieren“ kopiert eine vorhandene Auswahl, sonst den gesamten Inhalt. `⌘S` speichert, `⇧⌘S` öffnet Speichern unter; `⌘C` bleibt native Auswahl-Kopie.

Hervorhebung ist eine allgemeine Lexer-Darstellung, keine sprachspezifische Analyse oder IDE. Bei Texten ab 500.000 UTF-16-Zeichen bleibt der Editor ohne Hervorhebung nutzbar. Bearbeiten speichert Klartext und entfernt zuvor vorhandene RTF-Formatierung.

### Bild

Zoom und Scrollen, Pfeil/Linie/Rechteck/Ellipse, Stift, Text, nummerierte Marker, Hervorheben und deckendes Schwärzen. Auswahl ermöglicht Verschieben, Duplizieren, Löschen sowie Farb-/Stärkenänderung. Zuschneiden, Größenänderung, Flächenerweiterung, 90°-Rotation und Spiegeln werden unterstützt. Pixelierung und Weichzeichnung sind echte Core-Image-Filter auf dem gewählten Bereich. OCR-Ansicht mit Textauswahl und Kopieren. PNG-Export rendert Bild und Annotationen zusammen.

Undo/Redo speichert bis zu 30 Bearbeitungszustände im geöffneten Fenster. History und PNG enthalten das fertige Bild; eine spätere Sitzung lädt keine getrennten Annotationen-Layer. Größenänderungen sind auf 16.384 Pixel pro Seite und 80 Megapixel begrenzt. Bei sehr großen Bildern können Rendering und Filter Zeit und Arbeitsspeicher benötigen. Zum Verschieben des sichtbaren Ausschnitts Trackpad/Maus-Scrollen verwenden.

## Dubletten und Bildidentität

Neue Kopien ersetzen ältere identische Einträge mit neuer ID und neuem Erfassungszeitpunkt. Ein vorhandener Pinstatus wird übernommen. Text wird exakt verglichen; Einrückung und andere Whitespaces werden nicht zusammengefasst. Bilder werden anhand der normalisierten Pixel verglichen, unabhängig von Thumbnail und PNG-Metadaten. Datei-Referenzen anhand ihrer Pfade.

**Bearbeitete Bilder sind davon ausgenommen:** Erstes Speichern erzeugt eine getrennte, als bearbeitet markierte Kopie. Weiteres Speichern aus derselben Sitzung aktualisiert diese Kopie. Das Original kann später erneut kopiert werden, ohne die bearbeitete Kopie zu entfernen. Alte Histories ohne dieses zusätzliche optionale Feld bleiben lesbar.

OCR wird für erfasste und neu gespeicherte Bilder neu berechnet. Veraltete Ergebnisse werden verworfen, wenn die Bilddaten inzwischen geändert wurden. Beim Löschen oder Kürzen der History werden OCR-Einträge mit bereinigt.

## Technische Einstiegspunkte

| Bereich | Dateien unter `Sources/Clipwell/` |
|---|---|
| Werkzeuge, Pinboard, Drag & Drop, Export | `Services/FeatureCoordinator.swift` |
| Shortcuts und Recorder | `Services/HotkeyController.swift` |
| Text-/Skripteditor | `UI/Components/TextItemEditor.swift` |
| Bildeditor und Rendering | `UI/Components/ImageItemEditor.swift` |
| Dubletten, editierte Bildkopien | `Storage/ClipboardRepository.swift`, `Models/ClipboardItem.swift` |
| OCR und Index-Bereinigung | `Services/OCRService.swift` |
| Integration | `App/AppDelegate.swift`, `UI/PopoverView.swift`, `UI/SettingsView.swift` |

## Prüfung

`swift test` prüft mit isolierten temporären Daten Dublettenersatz und Pinübernahme, Whitespace in Skripten, Schutz bearbeiteter Bildkopien nach Neustart, alte History-Dateien, URL-Erkennung sowie gerenderte PNG-Pixel bei Schwärzung, Crop, Resize, Rotation und Undo.

Release bauen: `./scripts/build-app.sh`. Das Skript prüft App-Signatur und Info.plist. Auf dem lokalen Mac zusätzlich Pinboard/Shortcuts und Editor-Oberflächen prüfen; Bildschirmaufnahme erfordert die jeweilige macOS-Freigabe. Ad-hoc-Signierung ist für lokale Nutzung vorgesehen, keine Notarisierung für öffentliche Distribution.
