import AppKit
import CoreImage
import SwiftUI
import UniformTypeIdentifiers

enum ImageTool: String, CaseIterable, Identifiable {
    case select, arrow, line, rectangle, ellipse, pen, text, number, highlight, redact, crop, pixelate, blur
    var id: String { rawValue }
    var title: String {
        switch self {
        case .select: return "Auswahl"
        case .arrow: return "Pfeil"
        case .line: return "Linie"
        case .rectangle: return "Rechteck"
        case .ellipse: return "Ellipse"
        case .pen: return "Stift"
        case .text: return "Text"
        case .number: return "Nummer"
        case .highlight: return "Markieren"
        case .redact: return "Schwärzen"
        case .crop: return "Zuschneiden"
        case .pixelate: return "Pixelieren"
        case .blur: return "Weichzeichnen"
        }
    }
    var symbol: String {
        switch self {
        case .select: return "cursorarrow"
        case .arrow: return "arrow.up.right"
        case .line: return "line.diagonal"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .pen: return "pencil.tip"
        case .text: return "textformat"
        case .number: return "number.circle"
        case .highlight: return "highlighter"
        case .redact: return "rectangle.fill"
        case .crop: return "crop"
        case .pixelate: return "square.grid.3x3"
        case .blur: return "drop.halffull"
        }
    }
}

struct ImageMark: Identifiable {
    var id = UUID()
    var tool: ImageTool
    var points: [CGPoint]
    var color: Color
    var width: CGFloat
    var text = ""
    var bounds: CGRect {
        guard let first = points.first else { return .zero }
        if tool == .text { return CGRect(x: first.x, y: first.y, width: max(60, CGFloat(text.count) * max(14, width * 5) * 0.65), height: max(22, width * 7)) }
        if tool == .number {
            let radius = max(14, width * 4)
            return CGRect(x: first.x - radius, y: first.y - radius, width: radius * 2, height: radius * 2)
        }
        let xs = points.map(\.x), ys = points.map(\.y)
        return CGRect(x: xs.min() ?? first.x, y: ys.min() ?? first.y, width: max(1, (xs.max() ?? first.x) - (xs.min() ?? first.x)), height: max(1, (ys.max() ?? first.y) - (ys.min() ?? first.y)))
    }
}

@MainActor
final class ImageEditorModel: ObservableObject {
    struct Snapshot { let image: NSImage; let marks: [ImageMark] }
    let original: ClipboardItem
    @Published var image: NSImage
    @Published var marks: [ImageMark] = []
    @Published var selected: UUID?
    @Published var tool: ImageTool = .select
    @Published var color = Color.red
    @Published var thickness: CGFloat = 4
    @Published var zoom: CGFloat = 0.7
    @Published var text = "Text"
    @Published var showOCR = false
    @Published var status = ""
    @Published var dirty = false
    @Published var undoStack: [Snapshot] = []
    @Published var redoStack: [Snapshot] = []
    var editedID: UUID?
    var destination: URL?
    private var moveStart: CGPoint?
    private var originalPoints: [CGPoint] = []
    private var draft: UUID?

    init(item: ClipboardItem) {
        original = item
        if case .image(let png, _) = item.content, let rep = NSBitmapImageRep(data: png) {
            let image = NSImage(size: NSSize(width: rep.pixelsWide, height: rep.pixelsHigh))
            image.addRepresentation(rep)
            self.image = image
        } else { image = NSImage(size: NSSize(width: 1, height: 1)) }
        editedID = item.isEditedImage == true ? item.id : nil
    }
    var size: CGSize { image.size }
    func checkpoint() {
        undoStack.append(Snapshot(image: image, marks: marks))
        if undoStack.count > 30 { undoStack.removeFirst() }
        redoStack.removeAll(); dirty = true
    }
    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(Snapshot(image: image, marks: marks)); image = previous.image; marks = previous.marks; selected = nil; dirty = true
    }
    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(Snapshot(image: image, marks: marks)); image = next.image; marks = next.marks; selected = nil; dirty = true
    }
    func drag(start: CGPoint, current: CGPoint, ended: Bool) {
        let point = CGPoint(x: min(max(0, current.x), size.width), y: min(max(0, current.y), size.height))
        if tool == .select {
            if moveStart == nil {
                selected = marks.last(where: { $0.bounds.insetBy(dx: -12, dy: -12).contains(start) })?.id
                if let selected, let mark = marks.first(where: { $0.id == selected }) { checkpoint(); moveStart = start; originalPoints = mark.points }
            }
            if let selected, let index = marks.firstIndex(where: { $0.id == selected }), let origin = moveStart {
                marks[index].points = originalPoints.map { CGPoint(x: $0.x + point.x - origin.x, y: $0.y + point.y - origin.y) }
            }
            if ended { moveStart = nil }
            return
        }
        if draft == nil {
            checkpoint()
            var mark = ImageMark(tool: tool, points: [start, point], color: color, width: thickness)
            if tool == .text { mark.text = text }
            if tool == .number { mark.text = "\(marks.filter { $0.tool == .number }.count + 1)" }
            marks.append(mark); draft = mark.id; selected = mark.id
        }
        if let draft, let index = marks.firstIndex(where: { $0.id == draft }) {
            if tool == .pen { marks[index].points.append(point) }
            else { marks[index].points = [start, point] }
            if ended {
                let bounds = marks[index].bounds
                if [.crop, .pixelate, .blur].contains(tool) {
                    marks.remove(at: index)
                    if bounds.width > 2 && bounds.height > 2 { applyRegion(bounds, tool: tool) }
                }
                self.draft = nil
            }
        }
    }
    func deleteSelected() {
        guard let selected else { return }; checkpoint(); marks.removeAll { $0.id == selected }; self.selected = nil
    }
    func duplicateSelected() {
        guard let selected, var mark = marks.first(where: { $0.id == selected }) else { return }
        checkpoint(); mark.id = UUID(); mark.points = mark.points.map { CGPoint(x: $0.x + 15, y: $0.y + 15) }; marks.append(mark); self.selected = mark.id
    }
    func updateSelectedColor(_ color: Color) {
        guard tool == .select, let index = marks.firstIndex(where: { $0.id == selected }) else { return }
        checkpoint(); marks[index].color = color
    }
    func updateSelectedWidth(_ width: CGFloat) {
        guard tool == .select, let index = marks.firstIndex(where: { $0.id == selected }) else { return }
        checkpoint(); marks[index].width = width
    }
    func updateSelectedText(_ text: String) {
        guard tool == .select, let index = marks.firstIndex(where: { $0.id == selected }), marks[index].tool == .text else { return }
        checkpoint(); marks[index].text = text
    }
    func render() -> NSImage? {
        let renderer = ImageRenderer(content: ImageComposition(image: image, marks: marks, selected: nil).frame(width: size.width, height: size.height))
        renderer.scale = 1
        guard let cg = renderer.cgImage else { return nil }
        return NSImage(cgImage: cg, size: size)
    }
    private func cgImage() -> CGImage? { render()?.cgImage(forProposedRect: nil, context: nil, hints: nil) }
    private func applyRegion(_ raw: CGRect, tool: ImageTool) {
        guard let cg = cgImage() else { return }
        let bounds = raw.integral.intersection(CGRect(origin: .zero, size: size))
        let region = CGRect(x: bounds.minX, y: size.height - bounds.maxY, width: bounds.width, height: bounds.height)
        if tool == .crop {
            // CGImage cropping coordinates use the image's top-left origin.
            if let cropped = cg.cropping(to: bounds) { image = NSImage(cgImage: cropped, size: bounds.size); marks = [] }
        } else {
            let source = CIImage(cgImage: cg)
            let filtered = source.clampedToExtent().applyingFilter(tool == .pixelate ? "CIPixellate" : "CIGaussianBlur", parameters: tool == .pixelate ? [kCIInputScaleKey: max(8, thickness * 5)] : [kCIInputRadiusKey: max(5, thickness * 3)])
            let patch = filtered.cropped(to: region)
            let merged = patch.composited(over: source).cropped(to: source.extent)
            if let output = CIContext().createCGImage(merged, from: source.extent) { image = NSImage(cgImage: output, size: size); marks = [] }
        }
        selected = nil; status = "\(tool.title) angewendet"
    }
    func transform(_ kind: String) {
        guard let source = render() else { return }
        checkpoint()
        let targetSize = kind == "rotate" ? NSSize(width: size.height, height: size.width) : size
        let renderer = ImageRenderer(content: Image(nsImage: source).resizable().frame(width: size.width, height: size.height)
            .rotationEffect(.degrees(kind == "rotate" ? 90 : 0))
            .scaleEffect(x: kind == "flipH" ? -1 : 1, y: kind == "flipV" ? -1 : 1)
            .frame(width: targetSize.width, height: targetSize.height))
        renderer.scale = 1
        if let cg = renderer.cgImage { image = NSImage(cgImage: cg, size: targetSize); marks = []; selected = nil }
    }
    func resize(width: Int, height: Int, expand: Bool) {
        guard width > 0, height > 0, width <= 16384, height <= 16384, width * height <= 80_000_000, let source = render() else {
            status = "Größe muss zwischen 1 und 16384 px liegen (max. 80 MP)."; return
        }
        if expand && (CGFloat(width) < size.width || CGFloat(height) < size.height) { status = "Neue Fläche muss mindestens so groß wie das Bild sein."; return }
        checkpoint()
        let content = ZStack {
            Color.white
            Image(nsImage: source).resizable().frame(width: expand ? size.width : CGFloat(width), height: expand ? size.height : CGFloat(height))
        }.frame(width: CGFloat(width), height: CGFloat(height))
        let renderer = ImageRenderer(content: content); renderer.scale = 1
        if let cg = renderer.cgImage { image = NSImage(cgImage: cg, size: NSSize(width: width, height: height)); marks = []; selected = nil }
    }
    func png() -> Data? {
        guard let rendered = render(), let tiff = rendered.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
    func save() {
        guard let data = png() else { status = "Bild konnte nicht gerendert werden"; return }
        if let destination {
            do { try data.write(to: destination, options: .atomic); dirty = false; status = "Datei gespeichert" }
            catch { NSAlert(error: error).runModal() }
        } else if let image = NSImage(data: data), let content = ImageStore.prepareImageContent(from: image) {
            editedID = ClipboardRepository.shared.saveEditedImage(content, original: original, editedID: editedID)
            dirty = false; status = "Bearbeitete Kopie in History gespeichert"
        }
    }
    func saveAs() {
        guard let data = png() else { return }
        FileActions.save(data, name: "Bild.png", type: .png) { url in self.destination = url; self.dirty = false; self.status = "Datei gespeichert" }
    }
}

private struct ImageComposition: View {
    let image: NSImage
    let marks: [ImageMark]
    let selected: UUID?
    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: image).resizable()
            Canvas { context, _ in
                for mark in marks {
                    let rect = mark.bounds
                    let color = GraphicsContext.Shading.color(mark.color)
                    switch mark.tool {
                    case .rectangle, .ellipse:
                        context.stroke(mark.tool == .ellipse ? Path(ellipseIn: rect) : Path(rect), with: color, lineWidth: mark.width)
                    case .redact: context.fill(Path(rect), with: .color(.black))
                    case .highlight: context.fill(Path(rect), with: .color(mark.color.opacity(0.3)))
                    case .crop, .pixelate, .blur: context.stroke(Path(rect), with: .color(.accentColor), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    case .text:
                        if let point = mark.points.first { context.draw(Text(mark.text).font(.system(size: max(14, mark.width * 5), weight: .medium)).foregroundStyle(mark.color), at: point, anchor: .topLeading) }
                    case .number:
                        if let point = mark.points.first {
                            let radius = max(14, mark.width * 4)
                            context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)), with: color)
                            context.draw(Text(mark.text).font(.system(size: radius, weight: .bold)).foregroundStyle(.white), at: point)
                        }
                    default:
                        guard let first = mark.points.first, let last = mark.points.last else { continue }
                        var path = Path(); path.move(to: first)
                        for point in mark.points.dropFirst() { path.addLine(to: point) }
                        if mark.tool == .arrow {
                            let angle = atan2(last.y - first.y, last.x - first.x)
                            let length = max(12, mark.width * 4)
                            path.move(to: CGPoint(x: last.x - length * cos(angle - .pi / 6), y: last.y - length * sin(angle - .pi / 6)))
                            path.addLine(to: last)
                            path.addLine(to: CGPoint(x: last.x - length * cos(angle + .pi / 6), y: last.y - length * sin(angle + .pi / 6)))
                        }
                        context.stroke(path, with: color, style: StrokeStyle(lineWidth: mark.width, lineCap: .round, lineJoin: .round))
                    }
                    if mark.id == selected { context.stroke(Path(rect.insetBy(dx: -5, dy: -5)), with: .color(.accentColor), style: StrokeStyle(lineWidth: 1, dash: [4, 3])) }
                }
            }
        }
    }
}

struct ImageItemEditor: View {
    @StateObject private var model: ImageEditorModel
    @ObservedObject private var ocr = OCRIndex.shared
    @State private var width = ""
    @State private var height = ""
    @State private var sizePanel = false
    @State private var expand = false
    init(item: ClipboardItem) { _model = StateObject(wrappedValue: ImageEditorModel(item: item)) }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }.disabled(model.undoStack.isEmpty).keyboardShortcut("z", modifiers: .command)
                Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }.disabled(model.redoStack.isEmpty).keyboardShortcut("z", modifiers: [.command, .shift])
                Divider().frame(height: 18)
                Button { model.transform("rotate") } label: { Image(systemName: "rotate.right") }.help("90° drehen")
                Button { model.transform("flipH") } label: { Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right") }.help("Horizontal spiegeln")
                Button { model.transform("flipV") } label: { Image(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down") }.help("Vertikal spiegeln")
                Button("Größe …") { expand = false; openSize() }
                Button("Fläche …") { expand = true; openSize() }
                Spacer()
                Button { model.zoom = max(0.05, model.zoom / 1.25) } label: { Image(systemName: "minus.magnifyingglass") }
                Button("\(Int(model.zoom * 100)) %") { model.zoom = 1 }
                Button { model.zoom = min(4, model.zoom * 1.25) } label: { Image(systemName: "plus.magnifyingglass") }
                Toggle("OCR", isOn: $model.showOCR).toggleStyle(.button)
            }.padding(12)
            Divider()
            HStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 5) {
                        ForEach(ImageTool.allCases) { tool in
                            Button { model.tool = tool } label: {
                                Image(systemName: tool.symbol).frame(width: 34, height: 29)
                                    .background(model.tool == tool ? Color.accentColor.opacity(0.16) : .clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }.buttonStyle(.plain).help(tool.title)
                        }
                    }.padding(8)
                }.frame(width: 52)
                Divider()
                if model.showOCR {
                    ScrollView {
                        Text(ocr.text(for: model.editedID ?? model.original.id) ?? "Noch kein Text erkannt. OCR läuft nach dem Erfassen oder Speichern automatisch.")
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .topLeading).padding(24)
                    }
                } else {
                    GeometryReader { geometry in
                        ScrollView([.horizontal, .vertical]) {
                            ImageComposition(image: model.image, marks: model.marks, selected: model.selected)
                                .frame(width: model.size.width, height: model.size.height)
                                .scaleEffect(model.zoom, anchor: .topLeading)
                                .frame(width: model.size.width * model.zoom, height: model.size.height * model.zoom, alignment: .topLeading)
                                .contentShape(Rectangle())
                                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                                    model.drag(start: point(value.startLocation), current: point(value.location), ended: false)
                                }.onEnded { value in model.drag(start: point(value.startLocation), current: point(value.location), ended: true) })
                                .padding(24)
                                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                        }.background(Color(nsColor: .underPageBackgroundColor))
                        .onAppear { model.zoom = min(1, max(0.05, min((geometry.size.width - 48) / model.size.width, (geometry.size.height - 48) / model.size.height))) }
                    }
                }
            }
            Divider()
            HStack {
                ColorPicker("Farbe", selection: $model.color).fixedSize()
                Text("Stärke").font(.caption)
                Slider(value: $model.thickness, in: 1...20).frame(width: 95)
                if model.tool == .text || model.marks.first(where: { $0.id == model.selected })?.tool == .text {
                    TextField("Text", text: $model.text).textFieldStyle(.roundedBorder).frame(maxWidth: 220)
                }
                Button { model.duplicateSelected() } label: { Image(systemName: "plus.square.on.square") }.help("Annotation duplizieren").disabled(model.selected == nil)
                Button { model.deleteSelected() } label: { Image(systemName: "trash") }.help("Annotation löschen").disabled(model.selected == nil)
                Spacer()
                Text("\(Int(model.size.width)) × \(Int(model.size.height)) px").font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal, 12).padding(.vertical, 8)
            Divider()
            HStack {
                Text(model.status.isEmpty ? model.tool.title : model.status).font(.caption).foregroundStyle(.secondary)
                if model.dirty { Circle().fill(Color.accentColor).frame(width: 6, height: 6) }
                Spacer()
                Button("Kopieren") {
                    if model.showOCR { FeatureCoordinator.shared.copyText(ocr.text(for: model.editedID ?? model.original.id) ?? "") }
                    else if let image = model.render() { FeatureCoordinator.shared.copyImage(image) }
                    model.status = "Kopiert"
                }.keyboardShortcut("c", modifiers: [.command, .shift])
                Button("Speichern unter …") { model.saveAs() }.keyboardShortcut("s", modifiers: [.command, .shift])
                Button("Speichern") { model.save() }.keyboardShortcut("s", modifiers: .command).buttonStyle(.borderedProminent)
            }.padding(12)
        }.frame(minWidth: 760, minHeight: 540)
        .background(EditorDirtyState(dirty: model.dirty))
        .onChange(of: model.color) { _, value in model.updateSelectedColor(value) }
        .onChange(of: model.thickness) { _, value in model.updateSelectedWidth(value) }
        .onChange(of: model.text) { _, value in model.updateSelectedText(value) }
        .sheet(isPresented: $sizePanel) {
            VStack(alignment: .leading, spacing: 16) {
                Text(expand ? "Bildfläche erweitern" : "Bildgröße ändern").font(.headline)
                TextField("Breite (Pixel)", text: $width)
                TextField("Höhe (Pixel)", text: $height)
                HStack { Button("Abbrechen") { sizePanel = false }.keyboardShortcut(.cancelAction); Spacer(); Button("Anwenden") { model.resize(width: Int(width) ?? 0, height: Int(height) ?? 0, expand: expand); sizePanel = false }.keyboardShortcut(.defaultAction) }
            }.textFieldStyle(.roundedBorder).padding(24).frame(width: 330)
        }
    }
    private func point(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x / model.zoom, y: point.y / model.zoom) }
    private func openSize() { width = "\(Int(model.size.width))"; height = "\(Int(model.size.height))"; sizePanel = true }
}
