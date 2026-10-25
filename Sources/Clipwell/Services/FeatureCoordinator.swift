import AppKit
import CryptoKit
import SwiftUI
import UniformTypeIdentifiers

enum ImageFingerprint {
    static func digest(_ data: Data) -> Data {
        // Compare pixels, not encoder metadata or thumbnails.
        if let rep = NSBitmapImageRep(data: data), let cg = rep.cgImage,
           let context = CGContext(data: nil, width: cg.width, height: cg.height, bitsPerComponent: 8,
                                   bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let bytes = context.data {
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
            var payload = Data("\(cg.width)x\(cg.height):".utf8)
            payload.append(Data(bytes: bytes, count: cg.width * cg.height * 4))
            return Data(SHA256.hash(data: payload))
        }
        return Data(SHA256.hash(data: data))
    }
}

@MainActor
enum FileActions {
    static func save(_ data: Data, name: String, type: UTType, completion: ((URL) -> Void)? = nil) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.allowedContentTypes = [type]
        panel.allowsOtherFileTypes = type.conforms(to: .text)
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try data.write(to: url, options: .atomic); completion?(url) }
        catch { NSAlert(error: error).runModal() }
    }
}

@MainActor
enum HistoryExport {
    private struct Archive: Encodable {
        let schemaVersion = 1
        let exportedAt = Date()
        let items: [ClipboardItem]
        let ocr: [String: String]
    }
    static func run(_ items: [ClipboardItem]) {
        let index = Dictionary(uniqueKeysWithValues: items.compactMap { item in
            OCRIndex.shared.text(for: item.id).map { (item.id.uuidString, $0) }
        })
        do {
            let data = try data(items, ocr: index)
            FileActions.save(data, name: "Clipwell-export.json", type: .json)
        } catch { NSAlert(error: error).runModal() }
    }
    static func data(_ items: [ClipboardItem], ocr: [String: String]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(Archive(items: items, ocr: ocr))
    }
}

@MainActor
final class FeatureCoordinator: NSObject, NSWindowDelegate, ObservableObject {
    static let shared = FeatureCoordinator()
    private var repository: ClipboardRepository { .shared }
    private var monitor: ClipboardMonitor?
    private var dismissPicker: (() -> Void)?
    private var pinboard: NSPanel?
    private var editors: [UUID: NSWindow] = [:]
    private var captureProcess: Process?
    @Published private(set) var capturing = false
    private var colorSampler: NSColorSampler?
    private var pasteTarget: NSRunningApplication?
    private var activationObserver: NSObjectProtocol?

    func configure(repository: ClipboardRepository, monitor: ClipboardMonitor, dismiss: @escaping () -> Void) {
        self.monitor = monitor
        dismissPicker = dismiss
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            Task { @MainActor in self?.pasteTarget = app }
        }
        pasteTarget = NSWorkspace.shared.frontmostApplication
    }

    func perform(_ action: ShortcutAction) {
        switch action {
        case .picker: NotificationCenter.default.post(name: .clipwellOpenPicker, object: nil)
        case .pinboard: togglePinboard()
        case .selectionScreenshot: screenshot(selection: true)
        case .fullScreenshot: screenshot(selection: false)
        case .colorPicker: sampleColor()
        }
    }

    func togglePinboard() {
        dismissPicker?()
        if let pinboard {
            if pinboard.isVisible { pinboard.orderOut(nil) }
            else { NSApp.activate(ignoringOtherApps: true); pinboard.makeKeyAndOrderFront(nil) }
            return
        }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 430, height: 540), styleMask: [.titled, .closable, .resizable, .utilityWindow], backing: .buffered, defer: false)
        panel.title = "Pinboard"
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 340, height: 300)
        panel.contentView = NSHostingView(rootView: PinboardView().environmentObject(repository).environmentObject(AppSettings.shared))
        panel.center()
        pinboard = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func edit(_ item: ClipboardItem) {
        dismissPicker?()
        if let window = editors[item.id] { NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil); return }
        let window: NSWindow
        switch item.content {
        case .text:
            window = NSWindow(contentViewController: NSHostingController(rootView: TextItemEditor(item: item)))
            window.title = item.effectiveAnalysis?.codeLanguage == nil ? "Text" : "Skript"
        case .image:
            window = NSWindow(contentViewController: NSHostingController(rootView: ImageItemEditor(item: item)))
            window.title = "Bild"
        case .fileReferences(let refs):
            refs.first.map { NSWorkspace.shared.activateFileViewerSelecting([$0.url]) }; return
        }
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 1000, height: 720))
        window.minSize = NSSize(width: 760, height: 540)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        editors[item.id] = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        editors = editors.filter { $0.value !== window }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender.isDocumentEdited else { return true }
        let alert = NSAlert()
        alert.messageText = "Ungespeicherte Änderungen verwerfen?"
        alert.informativeText = "Mit Abbrechen kannst du zum Editor zurückkehren und deine Änderungen speichern."
        alert.addButton(withTitle: "Abbrechen")
        alert.addButton(withTitle: "Verwerfen")
        return alert.runModal() == .alertSecondButtonReturn
    }

    func copyText(_ text: String) {
        monitor?.suppressChanges()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    func copyImage(_ image: NSImage) {
        monitor?.suppressChanges()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }
    func paste(_ item: ClipboardItem, asPlainText: Bool = false) {
        guard let monitor else { return }
        PasteService.shared.select(item: item, monitor: monitor, asPlainText: asPlainText, forcePaste: true, targetApp: pasteTarget)
    }
    func record(_ content: ClipboardContent, pinned: Bool = false) {
        repository.addItem(ClipboardItem(content: content, isPinned: pinned, analysis: {
            if case .text(let text, _) = content { return ContentAnalyzer.analyze(text) }; return nil
        }()))
    }

    func sampleColor() {
        dismissPicker?()
        colorSampler = NSColorSampler()
        colorSampler?.show { [weak self] color in
            guard let rgb = color?.usingColorSpace(.sRGB) else {
                Task { @MainActor in self?.colorSampler = nil }; return
            }
            let hex = String(format: "#%02X%02X%02X", Int((rgb.redComponent * 255).rounded()), Int((rgb.greenComponent * 255).rounded()), Int((rgb.blueComponent * 255).rounded()))
            Task { @MainActor in
                self?.copyText(hex)
                self?.record(.text(plain: hex, rtfData: nil))
                self?.colorSampler = nil
            }
        }
    }

    func screenshot(selection: Bool) {
        guard !capturing else { return }
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            let alert = NSAlert()
            alert.messageText = "Bildschirmaufnahme erlauben"
            alert.informativeText = "Bitte Clipwell in Systemeinstellungen → Datenschutz & Sicherheit → Bildschirmaufnahme freigeben. Eventuell muss Clipwell danach neu gestartet werden."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        dismissPicker?()
        let visibleWindows = NSApp.windows.filter(\.isVisible)
        visibleWindows.forEach { $0.orderOut(nil) }
        capturing = true
        let target = FileManager.default.temporaryDirectory.appendingPathComponent("clipwell-capture-\(UUID().uuidString).png")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = (selection ? ["-i", "-s", "-x"] : ["-m", "-x"]) + ["-t", "png", target.path]
            process.standardError = Pipe()
            process.terminationHandler = { [weak self] process in
                DispatchQueue.main.async {
                    guard let self else { return }
                    defer {
                        try? FileManager.default.removeItem(at: target)
                        self.captureProcess = nil
                        self.capturing = false
                        visibleWindows.forEach { $0.orderFront(nil) }
                    }
                    // Escape produces no file. Never reuse previous clipboard contents.
                    if let image = NSImage(contentsOf: target), let content = ImageStore.prepareImageContent(from: image) {
                        self.copyImage(image)
                        self.record(content)
                    } else if process.terminationStatus != 0 && !selection {
                        let alert = NSAlert()
                        alert.messageText = "Screenshot nicht möglich"
                        alert.informativeText = "Bitte Clipwell unter Systemeinstellungen → Datenschutz & Sicherheit → Bildschirmaufnahme erlauben und erneut versuchen."
                        alert.runModal()
                    }
                }
            }
            do { try process.run(); self.captureProcess = process }
            catch { self.capturing = false; visibleWindows.forEach { $0.orderFront(nil) }; NSAlert(error: error).runModal() }
        }
    }
}

struct FeatureToolbar: View {
    @ObservedObject private var coordinator = FeatureCoordinator.shared
    var body: some View {
        HStack(spacing: 16) {
            Button { coordinator.togglePinboard() } label: { Image(systemName: "pin.square") }.help("Pinboard")
            Divider().frame(height: 14)
            Button { coordinator.screenshot(selection: true) } label: { Image(systemName: "viewfinder") }.help("Screenshot: Auswahl")
                .disabled(coordinator.capturing)
            Button { coordinator.screenshot(selection: false) } label: { Image(systemName: "display") }.help("Screenshot: Vollbild (Hauptbildschirm)")
                .disabled(coordinator.capturing)
            Button { coordinator.sampleColor() } label: { Image(systemName: "eyedropper") }.help("Farbpicker")
            Spacer()
        }.buttonStyle(.borderless).padding(.horizontal, 14).padding(.vertical, 9)
    }
}

struct EditorDirtyState: NSViewRepresentable {
    var dirty: Bool
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { view.window?.isDocumentEdited = dirty }
    }
}

enum ClipboardTransfer {
    static let itemType = "com.clipwell.history-item"
    @MainActor static func provider(for item: ClipboardItem) -> NSItemProvider {
        let provider: NSItemProvider
        switch item.content {
        case .text(let text, _): provider = NSItemProvider(object: text as NSString)
        case .image(let png, _):
            provider = NSItemProvider()
            provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { callback in callback(png, nil); return nil }
        case .fileReferences(let refs):
            provider = refs.first.map { NSItemProvider(object: $0.url as NSURL) } ?? NSItemProvider()
        }
        provider.registerDataRepresentation(forTypeIdentifier: itemType, visibility: .ownProcess) { callback in callback(Data(item.id.uuidString.utf8), nil); return nil }
        return provider
    }

    @MainActor static func accept(_ providers: [NSItemProvider], into target: ClipboardRepository? = nil) -> Bool {
        let repository = target ?? .shared
        var accepted = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(itemType) {
                accepted = true
                provider.loadDataRepresentation(forTypeIdentifier: itemType) { data, _ in
                    guard let data, let value = String(data: data, encoding: .utf8), let id = UUID(uuidString: value) else { return }
                    Task { @MainActor in repository.setPinned(id, true) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                accepted = true
                provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor in record(.fileReferences([FileReference(url: url)]), in: repository) }
                }
            } else if provider.canLoadObject(ofClass: NSURL.self) {
                accepted = true
                _ = provider.loadObject(ofClass: NSURL.self) { object, _ in
                    guard let url = object as? URL else { return }
                    Task { @MainActor in
                        if url.isFileURL { record(.fileReferences([FileReference(url: url)]), in: repository) }
                        else { record(.text(plain: url.absoluteString, rtfData: nil), in: repository) }
                    }
                }
            } else if provider.canLoadObject(ofClass: NSImage.self) {
                accepted = true
                _ = provider.loadObject(ofClass: NSImage.self) { object, _ in
                    guard let image = object as? NSImage else { return }
                    Task { @MainActor in
                        if let content = ImageStore.prepareImageContent(from: image) { record(content, in: repository) }
                    }
                }
            } else if provider.canLoadObject(ofClass: NSString.self) {
                accepted = true
                _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                    guard let text = object as? String else { return }
                    Task { @MainActor in record(.text(plain: text, rtfData: nil), in: repository) }
                }
            }
        }
        return accepted
    }

    @MainActor private static func record(_ content: ClipboardContent, in repository: ClipboardRepository) {
        let analysis: ContentAnalysis?
        if case .text(let text, _) = content { analysis = ContentAnalyzer.analyze(text) } else { analysis = nil }
        repository.addItem(ClipboardItem(content: content, isPinned: true, analysis: analysis))
    }
}

struct PinboardView: View {
    @EnvironmentObject private var repository: ClipboardRepository
    @State private var query = ""
    @State private var dropTarget = false
    private var items: [ClipboardItem] { repository.search(query: query).filter(\.isPinned) }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Pins durchsuchen", text: $query).textFieldStyle(.plain)
            }.padding(12)
            Divider()
            if items.isEmpty {
                ContentUnavailableView("Dein Pinboard", systemImage: "pin", description: Text("Einträge, Text, Bilder oder Dateien hierher ziehen."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            HistoryRowView(item: item, onPaste: { FeatureCoordinator.shared.paste(item) }, onPlainTextPaste: { FeatureCoordinator.shared.paste(item, asPlainText: true) }, onPin: { repository.setPinned(item.id, false) }, onDelete: { repository.removeItem(item) }, onEdit: { FeatureCoordinator.shared.edit(item) }, onPreview: { FeatureCoordinator.shared.edit(item) })
                            Divider()
                        }
                    }.padding(6)
                }
            }
            Divider()
            HStack {
                Text("\(items.count) Pins").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("Ziehen zum Kopieren · Rechtsklick zum Einfügen").font(.caption2).foregroundStyle(.secondary)
            }.padding(10)
        }
        .background(dropTarget ? Color.accentColor.opacity(0.1) : Color(nsColor: .windowBackgroundColor))
        .onDrop(of: [ClipboardTransfer.itemType, UTType.fileURL.identifier, UTType.url.identifier, UTType.image.identifier, UTType.text.identifier], isTargeted: $dropTarget) { ClipboardTransfer.accept($0) }
    }
}
