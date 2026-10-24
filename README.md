# Clipwell

**A fast, native macOS clipboard manager.** — v1.3

Clipwell lives in your menu bar and keeps a searchable history of everything you copy — text, images, and files. Recall any item instantly with a global hotkey or by clicking the menu bar icon.

---

## What's New

Version 1.3 adds a floating pinboard with drag & drop, configurable global shortcuts,
selection/full-screen screenshots with OCR, a screen color picker, URL opening,
JSON export in Settings, and separate text/script and image editors. All editors
offer Save, Save As and Copy. New copies replace older duplicates while edited
image copies remain separate. See [the 1.3 guide](docs/MODERNIZATION_1.3.md).

| Feature | Details |
|---------|---------|
| **Custom App Icon** | Professional clipboard icon in all required macOS sizes via `Assets.xcassets` |
| **OCR on Images** | Vision framework extracts text from copied images in the background; recognized text is fully searchable |
| **Localized UI** | Settings, menus, rows, and context actions support English, German, Polish, and French |
| **Sorting & Grouping** | History can be sorted and grouped by time, type, or source app |

---

## Features

- **Global hotkey** (`⌘⇧V` by default, fully customizable) opens an instant clipboard picker
- **Menu bar popover** with search, keyboard navigation, and quick actions
- **Text, image, and file support** — previews and thumbnails for images, filenames for files
- **Persistent history** across launches
- **Pinned / favorited entries** that survive history truncation
- **Duplicate replacement** — new copies replace identical older captures; edited image copies stay separate
- **Auto-paste** — optionally pastes immediately after selecting an item
- **Pause monitoring** — stop recording without quitting
- **App exclusions** — block specific apps from clipboard recording (by bundle ID)
- **Launch at login** support
- **Local history** — no telemetry or cloud sync; URL previews fetch page titles and favicons over the network

---

## Requirements

| Component | Minimum |
|-----------|---------|
| macOS     | 14.0 (Sonoma) |
| Xcode     | 15.0+ |
| Swift     | 5.9+ |

---

## Build & Run

### Option 1: Xcode (recommended for development)

```bash
git clone https://github.com/marcosomewhere/clipwell.git
cd clipwell
open Package.swift
```

Select the `Clipwell` scheme, choose **My Mac** as the destination, and press **Run** (`⌘R`).

### Option 2: Command Line

```bash
git clone https://github.com/marcosomewhere/clipwell.git
cd clipwell
swift build -c release
.build/release/Clipwell
```

### Build a real `.app`

```bash
./scripts/build-app.sh
open dist/Clipwell.app
```

The script creates `dist/Clipwell.app`, embeds the executable, generates
`AppIcon.icns` from the asset catalog, validates `Info.plist`, and applies an
ad-hoc signature by default.

### Code Signing (for distribution)

To distribute outside the App Store, code sign with your Developer ID:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (XXXXXXXX)" ./scripts/build-app.sh
```

---

## Permissions

Clipwell requests permissions for the features you use:

- **Accessibility** — only needed for the **auto-paste** feature (synthetic `⌘V` keystroke). If you don't use auto-paste, no permission is required.
- **Screen Recording** — needed for the screenshot tools, requested when first used.

Clipwell shows the current Accessibility status in Settings and opens **System Settings → Privacy & Security → Accessibility** on request. It does not repeatedly prompt from the paste path.

---

## Architecture

```
Sources/Clipwell/
├── App/
│   ├── ClipwellApp.swift          — @main entry, NSApplicationDelegateAdaptor
│   └── AppDelegate.swift          — Service wiring, lifecycle, settings window
│
├── Models/
│   ├── ClipboardContent.swift     — Content type enum (text / image / files)
│   ├── ClipboardItem.swift        — History entry model
│   └── AppSettings.swift          — Persisted user preferences
│
├── Services/
│   ├── ClipboardMonitor.swift     — NSPasteboard polling (0.5s timer)
│   ├── HotkeyController.swift     — Carbon global hotkey registration
│   ├── PasteService.swift         — Clipboard restore + CGEvent auto-paste
│   ├── URLMetadataService.swift   — URL title/favicon enrichment
│   ├── ContentAnalyzer.swift      — URL/code detection
│   └── OCRService.swift           — Vision OCR + OCRIndex persistence
│
├── Storage/
│   ├── ClipboardRepository.swift  — In-memory state + business logic + OCR search
│   ├── PersistenceStore.swift     — JSON file storage in Application Support
│   └── ImageStore.swift           — Image normalization + thumbnail generation
│
├── UI/
│   ├── MenuBarController.swift    — NSStatusItem + NSPopover
│   ├── PopoverView.swift          — Main search + history list (SwiftUI)
│   ├── OverlayPanelController.swift — Floating NSPanel for hotkey overlay
│   ├── AppLocalization.swift      — Shared UI strings for supported languages
│   ├── SettingsView.swift         — Settings tabs (SwiftUI)
│   └── Components/
│       ├── HistoryRowView.swift   — Single history entry row
│       ├── ImagePreviewView.swift — Resizable image preview window
│       ├── EditItemView.swift     — Text item editing sheet
│       └── URLPreviewRow.swift    — URL metadata row
│
├── Utilities/
│   └── Extensions.swift           — String helpers
│
└── Resources/
    └── Assets.xcassets
```

### Key Design Decisions

**JSON + Application Support for persistence.** At 200–500 items, JSON is fast enough and human-debuggable. For 10k+ items, migrate to SQLite via GRDB.

**NSPasteboard polling at 0.5s.** macOS has no push API for clipboard changes. 0.5s is imperceptible in practice and uses < 0.1% CPU at idle.

**NSPanel for the overlay.** A floating `NSPanel` with `.nonactivatingPanel` style appears above all apps without stealing focus, matching the behavior of Spotlight and Alfred.

**Zero third-party dependencies.** Hotkeys, login item handling, OCR, and UI are implemented with Apple frameworks.

---

## Roadmap / Known TODOs

- [x] ~~App icon asset~~
- [x] ~~OCR on images (Vision framework)~~
- [x] ~~Per-app clipboard exclusions UI~~
- [ ] iCloud sync (CloudKit-backed repository)
- [ ] Snippet expansion with placeholders
- [x] Export history as JSON (Settings)
- [ ] Import history
- [ ] Accessibility VoiceOver audit
- [ ] Notarization workflow for distribution
- [ ] OCR language picker in Settings (currently auto-detects + en/de/fr/es)

---

## Dependencies

Clipwell has no third-party package dependencies.

---

## License

MIT License — see [LICENSE](LICENSE).

---

## Contributing

Pull requests are welcome. Please open an issue first to discuss significant changes.

- Keep the codebase modular — one concern per file
- Prefer extending existing types over adding new files
- Add `OSLog` logging for new service code
- Test on both macOS 14 and macOS 15 before submitting
