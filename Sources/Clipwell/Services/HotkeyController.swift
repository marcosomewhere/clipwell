import AppKit
import Carbon.HIToolbox
import SwiftUI

enum ShortcutAction: String, CaseIterable, Codable, Identifiable {
    case picker, pinboard, selectionScreenshot, fullScreenshot, colorPicker
    var id: String { rawValue }
    var title: String {
        switch self {
        case .picker: return "Clipboard öffnen"
        case .pinboard: return "Pinboard"
        case .selectionScreenshot: return "Screenshot: Auswahl"
        case .fullScreenshot: return "Screenshot: Vollbild"
        case .colorPicker: return "Farbpicker"
        }
    }
}

struct ShortcutBinding: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var label: String
}

@MainActor
final class ShortcutPreferences: ObservableObject {
    static let shared = ShortcutPreferences()
    @Published var bindings: [String: ShortcutBinding] {
        didSet {
            if let data = try? JSONEncoder().encode(bindings) { UserDefaults.standard.set(data, forKey: "shortcutBindings.v2") }
            NotificationCenter.default.post(name: .clipwellShortcutsChanged, object: nil)
        }
    }
    @Published var errors: [String: String] = [:]
    var recording = false {
        didSet { NotificationCenter.default.post(name: .clipwellShortcutsChanged, object: nil) }
    }
    private init() {
        let defaults: [String: ShortcutBinding] = [
            "picker": .init(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey), label: "⌘⇧V"),
            "pinboard": .init(keyCode: UInt32(kVK_ANSI_B), modifiers: UInt32(cmdKey | shiftKey), label: "⌘⇧B")
        ]
        bindings = UserDefaults.standard.data(forKey: "shortcutBindings.v2").flatMap { try? JSONDecoder().decode([String: ShortcutBinding].self, from: $0) } ?? defaults
    }
    @discardableResult func assign(_ binding: ShortcutBinding?, to action: ShortcutAction) -> Bool {
        if let binding, bindings.contains(where: { $0.key != action.rawValue && $0.value.keyCode == binding.keyCode && $0.value.modifiers == binding.modifiers }) {
            errors[action.rawValue] = "Diese Kombination wird bereits verwendet."
            return false
        }
        bindings[action.rawValue] = binding
        return true
    }
}

@MainActor
final class HotkeyController {
    var onAction: ((ShortcutAction) -> Void)?
    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var observer: NSObjectProtocol?
    private var localMonitor: Any?
    func register() {
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard !ShortcutPreferences.shared.recording else { return event }
                let preferences = ShortcutPreferences.shared
                guard let action = ShortcutAction.allCases.first(where: {
                    preferences.errors[$0.rawValue] == nil && preferences.bindings[$0.rawValue]?.matches(event) == true
                }) else { return event }
                self?.onAction?(action)
                return nil
            }
        }
        if observer == nil {
            observer = NotificationCenter.default.addObserver(forName: .clipwellShortcutsChanged, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.register() }
            }
        }
        refs.forEach { UnregisterEventHotKey($0) }; refs.removeAll()
        guard !ShortcutPreferences.shared.recording else { return }
        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, event, data in
                guard let event, let data else { return OSStatus(eventNotHandledErr) }
                var id = EventHotKeyID()
                let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                guard status == noErr, id.signature == 0x434C5057, id.id > 0, id.id <= UInt32(ShortcutAction.allCases.count) else { return status }
                let controller = Unmanaged<HotkeyController>.fromOpaque(data).takeUnretainedValue()
                controller.onAction?(ShortcutAction.allCases[Int(id.id) - 1])
                return noErr
            }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        }
        ShortcutPreferences.shared.errors = [:]
        for (index, action) in ShortcutAction.allCases.enumerated() {
            guard let binding = ShortcutPreferences.shared.bindings[action.rawValue] else { continue }
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(binding.keyCode, binding.modifiers, EventHotKeyID(signature: 0x434C5057, id: UInt32(index + 1)), GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref { refs.append(ref) }
            else { ShortcutPreferences.shared.errors[action.rawValue] = "Nicht verfügbar (\(status)). Andere Kombination wählen." }
        }
    }
    func unregister() {
        refs.forEach { UnregisterEventHotKey($0) }; refs.removeAll()
        if let handler { RemoveEventHandler(handler) }; handler = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }; observer = nil
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }; localMonitor = nil
    }
}

struct ShortcutSettingsView: View {
    @ObservedObject private var preferences = ShortcutPreferences.shared
    @State private var recording: ShortcutAction?
    var body: some View {
        Form {
            Section("Globale Tastenkombinationen") {
                ForEach(ShortcutAction.allCases) { action in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(action.title)
                            Spacer()
                            Button(recording == action ? "Taste drücken …" : preferences.bindings[action.rawValue]?.label ?? "Zuweisen …") { recording = action }
                                .frame(minWidth: 130)
                            Button { preferences.assign(nil, to: action); recording = nil } label: { Image(systemName: "xmark.circle") }
                                .buttonStyle(.borderless).help("Shortcut entfernen")
                        }
                        if let error = preferences.errors[action.rawValue] { Text(error).font(.caption).foregroundStyle(.red) }
                    }
                }
            }
            Text("Auf Zuweisen klicken und eine Kombination mit ⌘, ⌥ oder ⌃ drücken. Escape bricht ab. Systemweit belegte Kombinationen sind nicht verfügbar.")
                .font(.caption).foregroundStyle(.secondary)
            ShortcutRecorder(action: $recording).frame(width: 0, height: 0)
        }.formStyle(.grouped).padding()
            .onChange(of: recording) { _, action in preferences.recording = action != nil }
            .onDisappear { preferences.recording = false }
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    @Binding var action: ShortcutAction?
    func makeNSView(context: Context) -> RecorderView { RecorderView() }
    func updateNSView(_ view: RecorderView, context: Context) {
        view.onKey = { event in
            guard let action else { return }
            if event.keyCode == UInt16(kVK_Escape) { self.action = nil; return }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard !flags.intersection([.command, .option, .control]).isEmpty else { return }
            var modifiers: UInt32 = 0
            var label = ""
            for (flag, carbon, symbol) in [(NSEvent.ModifierFlags.control, controlKey, "⌃"), (.option, optionKey, "⌥"), (.shift, shiftKey, "⇧"), (.command, cmdKey, "⌘")] {
                if flags.contains(flag) { modifiers |= UInt32(carbon); label += symbol }
            }
            label += event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
            if ShortcutPreferences.shared.assign(.init(keyCode: UInt32(event.keyCode), modifiers: modifiers, label: label), to: action) { self.action = nil }
        }
        view.recording = action != nil
        if action != nil { DispatchQueue.main.async { view.window?.makeFirstResponder(view) } }
    }
    final class RecorderView: NSView {
        var recording = false
        var onKey: ((NSEvent) -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) { if recording { onKey?(event) } else { super.keyDown(with: event) } }
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            if recording { onKey?(event); return true }; return false
        }
    }
}

extension Notification.Name {
    static let clipwellShortcutsChanged = Notification.Name("clipwellShortcutsChanged")
    static let clipwellOpenPicker = Notification.Name("clipwellOpenPicker")
}

extension ShortcutBinding {
    func matches(_ event: NSEvent) -> Bool {
        var flags: UInt32 = 0
        for (flag, carbon) in [(NSEvent.ModifierFlags.control, controlKey), (.option, optionKey), (.shift, shiftKey), (.command, cmdKey)] {
            if event.modifierFlags.contains(flag) { flags |= UInt32(carbon) }
        }
        return UInt32(event.keyCode) == keyCode && flags == modifiers
    }
}
