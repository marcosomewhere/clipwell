import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TextItemEditor: View {
    let item: ClipboardItem
    @State private var text: String
    @State private var savedText: String
    @State private var script: Bool
    @State private var wrap = true
    @State private var highlight = true
    @State private var search = ""
    @State private var replacement = ""
    @State private var status = ""
    @State private var selectedCount = 0
    @State private var destination: URL?
    @State private var editor: NSTextView?

    init(item: ClipboardItem) {
        self.item = item
        _text = State(initialValue: item.plainText ?? "")
        _savedText = State(initialValue: item.plainText ?? "")
        _script = State(initialValue: item.effectiveAnalysis?.codeLanguage != nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Picker("Ansicht", selection: $script) { Text("Text").tag(false); Text("Skript").tag(true) }
                    .pickerStyle(.segmented).frame(width: 170)
                Toggle("Umbruch", isOn: $wrap).toggleStyle(.checkbox)
                if script { Toggle("Hervorheben", isOn: $highlight).toggleStyle(.checkbox) }
                Spacer()
                Button { editor?.undoManager?.undo() } label: { Image(systemName: "arrow.uturn.backward") }.help("Rückgängig (⌘Z)")
                Button { editor?.undoManager?.redo() } label: { Image(systemName: "arrow.uturn.forward") }.help("Wiederholen (⇧⌘Z)")
            }.padding(12)
            Divider()
            HStack {
                TextField("Suchen", text: $search).frame(maxWidth: 200)
                    .onSubmit { find() }
                Button("Weiter") { find() }.disabled(search.isEmpty)
                TextField("Ersetzen durch", text: $replacement).frame(maxWidth: 200)
                Button("Auswahl ersetzen") { replaceSelection() }.disabled(search.isEmpty)
                Button("Alle ersetzen") { text = text.replacingOccurrences(of: search, with: replacement) }.disabled(search.isEmpty)
                Spacer()
            }.textFieldStyle(.roundedBorder).padding(.horizontal, 12).padding(.vertical, 8)
            Divider()
            NativeScriptEditor(text: $text, script: script, wrap: wrap, highlight: highlight,
                               selectionCount: $selectedCount, reference: $editor)
            Divider()
            HStack {
                Text("\(text.count) Zeichen · \(text.components(separatedBy: .newlines).count) Zeilen\(selectedCount > 0 ? " · \(selectedCount) ausgewählt" : "")")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary) }
                if text != savedText { Circle().fill(Color.accentColor).frame(width: 6, height: 6).help("Ungespeicherte Änderungen") }
            }.padding(.horizontal, 12).padding(.vertical, 8)
            HStack {
                Button("Alles auswählen") { editor?.selectAll(nil) }
                if script {
                    Button("Einrücken") { indent() }
                }
                Spacer()
                Button("Kopieren") {
                    if let editor, editor.selectedRange().length > 0 {
                        FeatureCoordinator.shared.copyText((text as NSString).substring(with: editor.selectedRange()))
                        status = "Auswahl kopiert"
                    } else { FeatureCoordinator.shared.copyText(text); status = "Kopiert" }
                }.keyboardShortcut("c", modifiers: [.command, .shift])
                Button("Speichern unter …") { saveAs() }.keyboardShortcut("s", modifiers: [.command, .shift])
                Button("Speichern") { save() }.keyboardShortcut("s", modifiers: .command).buttonStyle(.borderedProminent)
            }.padding(12)
        }.frame(minWidth: 760, minHeight: 500)
            .background(EditorDirtyState(dirty: text != savedText))
    }

    private func save() {
        if let destination {
            do { try Data(text.utf8).write(to: destination, options: .atomic); savedText = text; status = "Datei gespeichert" }
            catch { NSAlert(error: error).runModal() }
        } else {
            guard ClipboardRepository.shared.items.contains(where: { $0.id == item.id }) else {
                let alert = NSAlert(); alert.messageText = "Der History-Eintrag wurde inzwischen entfernt."; alert.informativeText = "Mit Speichern unter kannst du den Text weiterhin als Datei sichern."; alert.runModal(); return
            }
            ClipboardRepository.shared.updateText(for: item.id, newText: text)
            savedText = text
            status = "In History gespeichert"
        }
    }
    private func saveAs() {
        FileActions.save(Data(text.utf8), name: script ? "Skript.txt" : "Text.txt", type: .plainText) { url in destination = url; savedText = text; status = "Datei gespeichert" }
    }
    private func find() {
        guard !search.isEmpty, let editor else { return }
        let source = text as NSString
        let start = NSMaxRange(editor.selectedRange())
        var range = source.range(of: search, options: .caseInsensitive, range: NSRange(location: min(start, source.length), length: max(0, source.length - start)))
        if range.location == NSNotFound { range = source.range(of: search, options: .caseInsensitive) }
        if range.location != NSNotFound { editor.setSelectedRange(range); editor.scrollRangeToVisible(range); status = "" }
        else { status = "Kein Treffer" }
    }
    private func replaceSelection() {
        guard let editor else { return }
        let range = editor.selectedRange()
        guard range.length > 0, (text as NSString).substring(with: range).localizedCaseInsensitiveCompare(search) == .orderedSame else { find(); return }
        if editor.shouldChangeText(in: range, replacementString: replacement) {
            editor.textStorage?.replaceCharacters(in: range, with: replacement)
            editor.didChangeText()
        }
    }
    private func indent() {
        guard let editor else { return }
        let range = (text as NSString).lineRange(for: editor.selectedRange())
        let original = (text as NSString).substring(with: range)
        let replacement = "    " + original.replacingOccurrences(of: "\n", with: "\n    ")
        if editor.shouldChangeText(in: range, replacementString: replacement) {
            editor.textStorage?.replaceCharacters(in: range, with: replacement); editor.didChangeText()
        }
    }
}

struct NativeScriptEditor: NSViewRepresentable {
    @Binding var text: String
    var script: Bool
    var wrap: Bool
    var highlight: Bool
    @Binding var selectionCount: Int
    @Binding var reference: NSTextView?

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        let view = NSTextView(frame: .zero)
        view.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        view.textColor = .textColor
        view.backgroundColor = .textBackgroundColor
        view.isRichText = false
        view.allowsUndo = true
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isContinuousSpellCheckingEnabled = false
        view.usesFindBar = true
        view.textContainerInset = NSSize(width: 16, height: 14)
        view.minSize = .zero
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.isVerticallyResizable = true
        view.autoresizingMask = [.width]
        view.delegate = context.coordinator
        scroll.documentView = view
        scroll.verticalRulerView = ScriptLineRuler(textView: view, scrollView: scroll)
        scroll.hasVerticalRuler = true
        scroll.rulersVisible = script
        view.string = text
        DispatchQueue.main.async { reference = view }
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let view = scroll.documentView as? NSTextView else { return }
        if view.string != text {
            let range = view.selectedRange()
            view.string = text
            view.setSelectedRange(NSRange(location: min(range.location, (text as NSString).length), length: 0))
        }
        scroll.rulersVisible = script
        let width = max(100, scroll.contentSize.width)
        view.isHorizontallyResizable = !wrap
        view.textContainer?.widthTracksTextView = wrap
        view.textContainer?.containerSize = NSSize(width: wrap ? width : CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        if wrap { view.setFrameSize(NSSize(width: width, height: max(view.frame.height, scroll.contentSize.height))) }
        context.coordinator.colorize(view)
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeScriptEditor
        private var styling = false
        init(_ parent: NativeScriptEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard !styling, let view = notification.object as? NSTextView else { return }
            parent.text = view.string
            colorize(view)
        }
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            let count = view.selectedRange().length
            DispatchQueue.main.async { [weak self] in self?.parent.selectionCount = count }
            view.enclosingScrollView?.verticalRulerView?.needsDisplay = true
        }
        func colorize(_ view: NSTextView) {
            guard !styling, let storage = view.textStorage else { return }
            styling = true
            defer { styling = false }
            let all = NSRange(location: 0, length: storage.length)
            let font = parent.script ? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular) : NSFont.systemFont(ofSize: 14)
            view.font = font
            storage.beginEditing()
            storage.addAttributes([.foregroundColor: NSColor.textColor, .font: font], range: all)
            // A language-neutral lexer: keywords, literals, strings, comments. Selection remains native.
            if parent.script && parent.highlight && storage.length < 500_000 {
                let rules: [(String, NSColor)] = [
                    (#"\b(?:if|else|for|while|return|func|function|class|struct|let|var|const|import|from|public|private|static|async|await|try|catch|throw|def|in|new|switch|case|break|continue|guard|enum|export|interface|type|extends|implements|select|where|true|false|null|nil|None|True|False)\b"#, .systemPurple),
                    (#"\b\d+(?:\.\d+)?\b"#, .systemOrange),
                    (#"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`"#, .systemGreen),
                    (#"(?m)//[^\n]*|/\*[\s\S]*?\*/|^\s*#[^\n]*"#, .secondaryLabelColor)
                ]
                for (pattern, color) in rules {
                    if let regex = try? NSRegularExpression(pattern: pattern) {
                        for match in regex.matches(in: view.string, range: all) { storage.addAttribute(.foregroundColor, value: color, range: match.range) }
                    }
                }
            }
            storage.endEditing()
            view.typingAttributes = [.font: font, .foregroundColor: NSColor.textColor]
            view.enclosingScrollView?.verticalRulerView?.needsDisplay = true
        }
    }
}

private final class ScriptLineRuler: NSRulerView {
    weak var textView: NSTextView?
    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 52
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(redraw), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func redraw() { needsDisplay = true }
    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let view = textView, let layout = view.layoutManager, let container = view.textContainer else { return }
        NSColor.controlBackgroundColor.setFill(); rect.fill()
        let visible = view.visibleRect
        let range = layout.glyphRange(forBoundingRect: visible, in: container)
        let characters = layout.characterRange(forGlyphRange: range, actualGlyphRange: nil)
        let source = view.string as NSString
        let prefix = source.substring(to: min(characters.location, source.length))
        var line = prefix.components(separatedBy: "\n").count
        var index = source.lineRange(for: NSRange(location: min(characters.location, source.length), length: 0)).location
        while index <= min(NSMaxRange(characters), source.length) {
            let glyph = layout.glyphIndexForCharacter(at: index)
            if glyph < layout.numberOfGlyphs {
                let box = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
                let y = convert(NSPoint(x: 0, y: box.minY + view.textContainerInset.height), from: view).y
                ("\(line)" as NSString).draw(at: NSPoint(x: 8, y: y), withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular), .foregroundColor: NSColor.secondaryLabelColor])
            }
            if index >= source.length { break }
            let next = NSMaxRange(source.lineRange(for: NSRange(location: index, length: 0)))
            if next <= index { break }; index = next; line += 1
        }
    }
}
