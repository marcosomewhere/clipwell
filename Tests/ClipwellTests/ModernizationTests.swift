import AppKit
import XCTest
import SwiftUI
import Carbon.HIToolbox
import UniformTypeIdentifiers
@testable import Clipwell

final class ModernizationTests: XCTestCase {
    @MainActor private func repository() -> (ClipboardRepository, PersistenceStore, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("clipwell-tests-\(UUID())")
        let persistence = PersistenceStore(directory: directory)
        return (ClipboardRepository(persistence: persistence, settings: .shared, startOCR: false), persistence, directory)
    }

    @MainActor func testNewCopyReplacesOldIdentityAndMigratesPin() async {
        let (repo, persistence, directory) = repository()
        defer { persistence.flush(); try? FileManager.default.removeItem(at: directory) }
        let old = ClipboardItem(content: .text(plain: "hello", rtfData: nil), isPinned: true)
        let new = ClipboardItem(content: .text(plain: "hello", rtfData: Data([1, 2])))
        repo.addItem(old); repo.addItem(new)
        XCTAssertEqual(repo.items.count, 1)
        XCTAssertEqual(repo.items.first?.id, new.id)
        XCTAssertEqual(repo.items.first?.isPinned, true)
        persistence.flush()
        XCTAssertEqual(persistence.loadHistory().first?.id, new.id)
    }

    @MainActor func testWhitespaceSignificantScriptsRemainSeparate() async {
        let (repo, persistence, directory) = repository()
        defer { persistence.flush(); try? FileManager.default.removeItem(at: directory) }
        repo.addItem(ClipboardItem(content: .text(plain: "if x:\n    y()", rtfData: nil)))
        repo.addItem(ClipboardItem(content: .text(plain: "if x:\n        y()", rtfData: nil)))
        XCTAssertEqual(repo.items.count, 2)
    }

    @MainActor func testEditedImageSurvivesRepeatedOriginalEvenWithIdenticalPixels() async throws {
        let (repo, persistence, directory) = repository()
        defer { persistence.flush(); try? FileManager.default.removeItem(at: directory) }
        let png = try imageData(width: 100, height: 60)
        let payload = ClipboardContent.image(pngData: png, thumbnailData: png)
        let original = ClipboardItem(content: payload)
        repo.addItem(original)
        let editedID = repo.saveEditedImage(payload, original: original, editedID: nil)
        let next = ClipboardItem(content: payload)
        repo.addItem(next)
        XCTAssertEqual(repo.items.count, 2)
        XCTAssertFalse(repo.items.contains { $0.id == original.id })
        XCTAssertTrue(repo.items.contains { $0.id == next.id && $0.isEditedImage != true })
        XCTAssertTrue(repo.items.contains { $0.id == editedID && $0.isEditedImage == true })
        persistence.flush()
        let reloaded = ClipboardRepository(persistence: persistence, settings: .shared, startOCR: false)
        XCTAssertEqual(reloaded.items.count, 2)
        XCTAssertTrue(reloaded.items.contains { $0.id == editedID && $0.isEditedImage == true })
    }

    @MainActor func testOldHistoryWithoutEditedFlagDecodes() async throws {
        let item = ClipboardItem(content: .text(plain: "old", rtfData: nil))
        let data = try JSONEncoder().encode(item)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "isEditedImage")
        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.isEditedImage)
        XCTAssertEqual(decoded.plainText, "old")
    }

    @MainActor func testImageRenderingRedactionCropResizeAndUndo() async throws {
        _ = NSApplication.shared
        let png = try imageData(width: 100, height: 60)
        let item = ClipboardItem(content: .image(pngData: png, thumbnailData: png))
        let editor = ImageEditorModel(item: item)
        editor.tool = .redact
        editor.drag(start: CGPoint(x: 10, y: 10), current: CGPoint(x: 40, y: 30), ended: true)
        let rendered = try XCTUnwrap(editor.png())
        let rep = try XCTUnwrap(NSBitmapImageRep(data: rendered))
        XCTAssertEqual(rep.pixelsWide, 100)
        XCTAssertEqual(rep.pixelsHigh, 60)
        let black = try XCTUnwrap(rep.colorAt(x: 20, y: 20)?.usingColorSpace(.sRGB))
        XCTAssertLessThan(black.redComponent, 0.05)
        XCTAssertLessThan(black.greenComponent, 0.05)
        XCTAssertLessThan(black.blueComponent, 0.05)
        let white = try XCTUnwrap(rep.colorAt(x: 80, y: 45)?.usingColorSpace(.sRGB))
        XCTAssertGreaterThan(white.redComponent, 0.95)
        editor.tool = .crop
        editor.drag(start: CGPoint(x: 5, y: 5), current: CGPoint(x: 55, y: 35), ended: true)
        XCTAssertEqual(editor.size, CGSize(width: 50, height: 30))
        editor.undo()
        XCTAssertEqual(editor.size, CGSize(width: 100, height: 60))
        XCTAssertEqual(editor.marks.count, 1)
        editor.resize(width: 200, height: 120, expand: false)
        XCTAssertEqual(editor.size, CGSize(width: 200, height: 120))
        editor.transform("rotate")
        XCTAssertEqual(editor.size, CGSize(width: 120, height: 200))
    }

    @MainActor func testURLRecognitionRejectsSurroundingProse() async {
        XCTAssertEqual(ContentAnalyzer.detectURL(in: "https://example.com/test"), "https://example.com/test")
        XCTAssertNil(ContentAnalyzer.detectURL(in: "This is a longer sentence with a link https://example.com and a lot of unrelated surrounding text."))
    }

    @MainActor func testExportContainsVersionImagesPinsAndOCR() async throws {
        let png = try imageData(width: 10, height: 8)
        let image = ClipboardItem(content: .image(pngData: png, thumbnailData: png), isPinned: true)
        let data = try HistoryExport.data([image], ocr: [image.id.uuidString: "Screenshot text"])
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? Int, 1)
        XCTAssertEqual((object["ocr"] as? [String: String])?[image.id.uuidString], "Screenshot text")
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let records = try XCTUnwrap(object["items"])
        let decoded = try decoder.decode([ClipboardItem].self, from: JSONSerialization.data(withJSONObject: records))
        XCTAssertEqual(decoded.first?.content, image.content)
        XCTAssertEqual(decoded.first?.isPinned, true)
    }

    @MainActor func testGenericHighlightingPreservesNativeCodeSelection() async {
        _ = NSApplication.shared
        let source = "let answer = 42\n// comment\nreturn answer"
        let view = NSTextView()
        view.string = source
        let selection = NSRange(location: 4, length: 6)
        view.setSelectedRange(selection)
        let representable = NativeScriptEditor(text: .constant(source), script: true, wrap: true, highlight: true, selectionCount: .constant(0), reference: .constant(view))
        let coordinator = representable.makeCoordinator()
        coordinator.colorize(view)
        XCTAssertEqual(view.string, source)
        XCTAssertEqual(view.selectedRange(), selection)
        let keyword = view.textStorage?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertEqual(keyword, .systemPurple)
    }

    @MainActor func testPinboardAcceptsInternalItemsTextImagesAndWebURLs() async throws {
        let (repo, persistence, directory) = repository()
        defer { persistence.flush(); try? FileManager.default.removeItem(at: directory) }
        let original = ClipboardItem(content: .text(plain: "internal pin", rtfData: nil))
        repo.addItem(original)
        let internalProvider = ClipboardTransfer.provider(for: original)
        let textProvider = NSItemProvider(object: "external pin" as NSString)
        let urlProvider = NSItemProvider(object: NSURL(string: "https://example.com/clipwell-test")!)
        let png = try imageData(width: 32, height: 20)
        let imageProvider = NSItemProvider()
        imageProvider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in completion(png, nil); return nil }
        XCTAssertTrue(ClipboardTransfer.accept([internalProvider, textProvider, urlProvider, imageProvider], into: repo))
        for _ in 0..<100 {
            if repo.items.count == 4 && repo.items.allSatisfy(\.isPinned) { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(repo.items.count, 4)
        XCTAssertTrue(repo.items.allSatisfy(\.isPinned))
        XCTAssertTrue(repo.items.contains { $0.id == original.id })
        XCTAssertTrue(repo.items.contains { $0.effectiveAnalysis?.detectedURL == "https://example.com/clipwell-test" })
        XCTAssertTrue(repo.items.contains { if case .image = $0.content { return true }; return false })
    }

    @MainActor func testScreenshotTextIsRecognizedByRealVisionOCR() async throws {
        let image = NSImage(size: NSSize(width: 1000, height: 230))
        image.lockFocus()
        NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 1000, height: 230).fill()
        ("CLIPWELL SCREENSHOT 4826\nSecond line of text" as NSString).draw(in: NSRect(x: 30, y: 20, width: 940, height: 190), withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 42, weight: .medium), .foregroundColor: NSColor.black])
        image.unlockFocus()
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let recognized = try await Task.detached { try OCRService.extractText(from: png) }.value
        XCTAssertTrue(recognized.contains("CLIPWELL SCREENSHOT 4826"), recognized)
        XCTAssertTrue(recognized.contains("Second line of text"), recognized)
        XCTAssertTrue(recognized.contains("\n"), recognized)
    }

    @MainActor func testShortcutMatchingRequiresExactModifiers() async throws {
        let binding = ShortcutBinding(keyCode: UInt32(kVK_ANSI_B), modifiers: UInt32(cmdKey | shiftKey), label: "⇧⌘B")
        func key(_ flags: NSEvent.ModifierFlags) throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil, characters: "B", charactersIgnoringModifiers: "b", isARepeat: false, keyCode: UInt16(kVK_ANSI_B)))
        }
        XCTAssertTrue(binding.matches(try key([.command, .shift])))
        XCTAssertFalse(binding.matches(try key([.command])))
        XCTAssertFalse(binding.matches(try key([.command, .shift, .option])))
    }

    @MainActor func testEditorLayoutsRenderOffscreen() async throws {
        _ = NSApplication.shared
        let item = ClipboardItem(content: .text(plain: "let answer = 42\n// Clipwell\nreturn answer", rtfData: nil), analysis: ContentAnalyzer.analyze("let answer = 42\nreturn answer"))
        try snapshot(TextItemEditor(item: item), name: "clipwell-text-editor-qa")
        let png = try imageData(width: 300, height: 180)
        try snapshot(ImageItemEditor(item: ClipboardItem(content: .image(pngData: png, thumbnailData: png))), name: "clipwell-image-editor-qa")
    }

    @MainActor private func snapshot<V: View>(_ content: V, name: String) throws {
        let host = NSHostingView(rootView: content)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 720), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        host.frame = NSRect(x: 0, y: 0, width: 1000, height: 720)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        XCTAssertGreaterThan(data.count, 1000)
        try data.write(to: URL(fileURLWithPath: "/tmp/\(name).png"))
        window.orderOut(nil)
    }

    @MainActor private func imageData(width: Int, height: Int) throws -> Data {
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let rep = NSBitmapImageRep(cgImage: try XCTUnwrap(context.makeImage()))
        return try XCTUnwrap(rep.representation(using: .png, properties: [:]))
    }
}
