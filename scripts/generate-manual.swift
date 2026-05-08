#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

let lightAppearance = NSAppearance(named: .aqua)
NSApplication.shared.appearance = lightAppearance

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let docsURL = root.appendingPathComponent("docs", isDirectory: true)
let screenshotsURL = docsURL.appendingPathComponent("screenshots", isDirectory: true)
let pdfURL = docsURL.appendingPathComponent("Clipwell_User_Manual.pdf")

try FileManager.default.createDirectory(at: screenshotsURL, withIntermediateDirectories: true)

struct Shot {
    let filename: String
    let caption: String
}

let shots: [Shot] = [
    Shot(filename: "01-picker-overview.png", caption: "The Clipwell clipboard picker with search, sorting, grouping, pinned items, and history rows."),
    Shot(filename: "02-row-actions.png", caption: "Context actions are available from each history row, including paste, plain-text paste, edit, preview, pin, and delete."),
    Shot(filename: "03-general-settings.png", caption: "General settings control login behavior, auto-paste, monitoring, permissions, shortcuts, and history limits."),
    Shot(filename: "04-privacy-settings.png", caption: "Privacy settings let you ignore selected apps by choosing a running app or entering a Bundle ID."),
    Shot(filename: "05-storage-settings.png", caption: "Storage settings show history counts and provide cleanup actions."),
    Shot(filename: "06-language-about.png", caption: "Language and About settings provide localization, app information, and the built-in Clipwell guide."),
    Shot(filename: "07-image-preview.png", caption: "Copied images can be previewed, indexed by OCR, and searched by recognized text.")
]

let paragraph = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
paragraph.lineBreakMode = .byWordWrapping
paragraph.lineSpacing = 3

func attrs(size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> [NSAttributedString.Key: Any] {
    [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
}

func monoAttrs(size: CGFloat, color: NSColor = .labelColor) -> [NSAttributedString.Key: Any] {
    [
        .font: NSFont.monospacedSystemFont(ofSize: size, weight: .regular),
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
}

func drawText(_ text: String, in rect: CGRect, attributes: [NSAttributedString.Key: Any]) {
    NSString(string: text).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes)
}

func measureText(_ text: String, width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
    NSString(string: text)
        .boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                      options: [.usesLineFragmentOrigin, .usesFontLeading],
                      attributes: attributes)
        .height.rounded(.up)
}

func roundedRect(_ rect: CGRect, radius: CGFloat, color: NSColor, stroke: NSColor? = nil) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    color.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

func line(_ from: CGPoint, _ to: CGPoint, color: NSColor = .separatorColor) {
    let path = NSBezierPath()
    path.move(to: from)
    path.line(to: to)
    color.setStroke()
    path.lineWidth = 1
    path.stroke()
}

func saveImage(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "ManualGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }
    try data.write(to: url)
}

func image(size: CGSize, draw: (CGRect) -> Void) -> NSImage {
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.windowBackgroundColor.setFill()
    NSRect(origin: .zero, size: size).fill()
    draw(CGRect(origin: .zero, size: size))
    image.unlockFocus()
    return image
}

func drawWindowChrome(_ rect: CGRect, title: String) {
    roundedRect(rect, radius: 14, color: NSColor.windowBackgroundColor, stroke: NSColor.separatorColor)
    roundedRect(CGRect(x: rect.minX, y: rect.maxY - 42, width: rect.width, height: 42), radius: 14, color: NSColor.controlBackgroundColor)
    ["systemRed", "systemYellow", "systemGreen"].enumerated().forEach { index, name in
        let color: NSColor = name == "systemRed" ? .systemRed : (name == "systemYellow" ? .systemYellow : .systemGreen)
        color.setFill()
        NSBezierPath(ovalIn: CGRect(x: rect.minX + 17 + CGFloat(index) * 20, y: rect.maxY - 27, width: 12, height: 12)).fill()
    }
    drawText(title, in: CGRect(x: rect.minX + 72, y: rect.maxY - 30, width: rect.width - 144, height: 18), attributes: attrs(size: 13, weight: .semibold, color: .secondaryLabelColor))
}

func pill(_ text: String, x: CGFloat, y: CGFloat, color: NSColor = .quaternaryLabelColor) {
    let w = max(42, measureText(text, width: 200, attributes: attrs(size: 10)) + CGFloat(text.count) * 4)
    roundedRect(CGRect(x: x, y: y, width: w, height: 20), radius: 5, color: color)
    drawText(text, in: CGRect(x: x + 8, y: y + 4, width: w - 16, height: 12), attributes: attrs(size: 10, color: .secondaryLabelColor))
}

func drawPickerScreenshot() -> NSImage {
    image(size: CGSize(width: 900, height: 620)) { _ in
        let panel = CGRect(x: 250, y: 70, width: 400, height: 500)
        roundedRect(panel, radius: 12, color: .windowBackgroundColor, stroke: .separatorColor)
        roundedRect(CGRect(x: panel.minX + 12, y: panel.maxY - 47, width: 376, height: 28), radius: 7, color: .controlBackgroundColor)
        drawText("Search clipboard...", in: CGRect(x: panel.minX + 42, y: panel.maxY - 40, width: 200, height: 16), attributes: attrs(size: 13, color: .tertiaryLabelColor))
        drawText("Newest", in: CGRect(x: panel.minX + 13, y: panel.maxY - 75, width: 70, height: 15), attributes: attrs(size: 11, color: .secondaryLabelColor))
        drawText("None", in: CGRect(x: panel.minX + 95, y: panel.maxY - 75, width: 70, height: 15), attributes: attrs(size: 11, color: .secondaryLabelColor))
        drawText("7", in: CGRect(x: panel.maxX - 32, y: panel.maxY - 75, width: 20, height: 15), attributes: attrs(size: 10, weight: .medium, color: .tertiaryLabelColor))
        line(CGPoint(x: panel.minX, y: panel.maxY - 88), CGPoint(x: panel.maxX, y: panel.maxY - 88))

        let rows = [
            ("Text", "Invoice note for Q2 planning review", "Notes", "now", true),
            ("URL", "https://www.apple.com/macos/", "Safari", "5 min ago", false),
            ("Code", "let item = ClipboardItem(content: .text(...))", "Xcode", "18 min ago", false),
            ("Image", "Screenshot with recognized OCR text", "Preview", "1 h ago", false),
            ("Files", "Clipwell_User_Manual.pdf, Release.zip", "Finder", "Yesterday", false)
        ]
        var y = panel.maxY - 130
        for (index, row) in rows.enumerated() {
            if index == 0 { roundedRect(CGRect(x: panel.minX + 5, y: y - 6, width: 390, height: 57), radius: 6, color: NSColor.controlAccentColor.withAlphaComponent(0.12)) }
            roundedRect(CGRect(x: panel.minX + 12, y: y + 11, width: 32, height: 32), radius: 6, color: .controlBackgroundColor)
            drawText(row.0 == "URL" ? "link" : row.0.prefix(1).uppercased(), in: CGRect(x: panel.minX + 19, y: y + 19, width: 22, height: 13), attributes: attrs(size: 10, weight: .semibold, color: .secondaryLabelColor))
            drawText(row.1, in: CGRect(x: panel.minX + 54, y: y + 28, width: 280, height: 16), attributes: row.0 == "Code" ? monoAttrs(size: 11) : attrs(size: 12))
            pill(row.0, x: panel.minX + 54, y: y + 6)
            drawText(row.2, in: CGRect(x: panel.maxX - 108, y: y + 8, width: 48, height: 12), attributes: attrs(size: 9, color: .tertiaryLabelColor))
            drawText(row.3, in: CGRect(x: panel.maxX - 58, y: y + 8, width: 48, height: 12), attributes: attrs(size: 9, color: .tertiaryLabelColor))
            if row.4 { drawText("pin", in: CGRect(x: panel.maxX - 30, y: y + 29, width: 18, height: 14), attributes: attrs(size: 9, color: .secondaryLabelColor)) }
            line(CGPoint(x: panel.minX + 50, y: y - 9), CGPoint(x: panel.maxX, y: y - 9))
            y -= 72
        }

        line(CGPoint(x: panel.minX, y: panel.minY + 40), CGPoint(x: panel.maxX, y: panel.minY + 40))
        drawText("Clear", in: CGRect(x: panel.minX + 12, y: panel.minY + 15, width: 45, height: 14), attributes: attrs(size: 11, color: .secondaryLabelColor))
        drawText("Option = plain text", in: CGRect(x: panel.minX + 120, y: panel.minY + 16, width: 105, height: 12), attributes: attrs(size: 10, color: .tertiaryLabelColor))
        drawText("Cmd-Shift-V", in: CGRect(x: panel.minX + 250, y: panel.minY + 16, width: 72, height: 12), attributes: attrs(size: 10, weight: .medium, color: .tertiaryLabelColor))
        drawText("gear", in: CGRect(x: panel.maxX - 72, y: panel.minY + 15, width: 32, height: 14), attributes: attrs(size: 11, color: .secondaryLabelColor))
        drawText("quit", in: CGRect(x: panel.maxX - 35, y: panel.minY + 15, width: 28, height: 14), attributes: attrs(size: 11, color: .secondaryLabelColor))
    }
}

func drawContextScreenshot() -> NSImage {
    let base = drawPickerScreenshot()
    base.lockFocus()
    let menu = CGRect(x: 560, y: 205, width: 210, height: 202)
    roundedRect(menu, radius: 8, color: NSColor.windowBackgroundColor, stroke: .separatorColor)
    let items = ["Paste", "Paste as Plain Text", "Edit...", "Preview...", "Pin", "Delete"]
    var y = menu.maxY - 32
    for item in items {
        drawText(item, in: CGRect(x: menu.minX + 16, y: y, width: 180, height: 17), attributes: attrs(size: 13, color: item == "Delete" ? .systemRed : .labelColor))
        if item == "Preview..." || item == "Pin" {
            line(CGPoint(x: menu.minX, y: y - 8), CGPoint(x: menu.maxX, y: y - 8))
            y -= 15
        }
        y -= 28
    }
    base.unlockFocus()
    return base
}

func drawSettingsScreenshot(tab: String) -> NSImage {
    image(size: CGSize(width: 1000, height: 650)) { _ in
        let win = CGRect(x: 170, y: 85, width: 660, height: 420)
        drawWindowChrome(win, title: "Clipwell Settings")
        let tabs = ["General", "Privacy", "Storage", "Language", "About"]
        var x = win.minX + 45
        for t in tabs {
            let selected = t == tab
            roundedRect(CGRect(x: x - 10, y: win.maxY - 77, width: 92, height: 30), radius: 7, color: selected ? NSColor.controlAccentColor.withAlphaComponent(0.14) : .clear)
            drawText(t, in: CGRect(x: x, y: win.maxY - 68, width: 80, height: 14), attributes: attrs(size: 12, weight: selected ? .semibold : .regular, color: selected ? .labelColor : .secondaryLabelColor))
            x += 112
        }
        line(CGPoint(x: win.minX, y: win.maxY - 92), CGPoint(x: win.maxX, y: win.maxY - 92))

        let content = CGRect(x: win.minX + 34, y: win.minY + 35, width: win.width - 68, height: win.height - 145)
        func section(_ title: String, _ rows: [String], at yTop: inout CGFloat) {
            drawText(title, in: CGRect(x: content.minX, y: yTop, width: content.width, height: 16), attributes: attrs(size: 12, weight: .semibold, color: .secondaryLabelColor))
            yTop -= 9
            roundedRect(CGRect(x: content.minX, y: yTop - CGFloat(rows.count) * 34, width: content.width, height: CGFloat(rows.count) * 34), radius: 8, color: .controlBackgroundColor, stroke: .separatorColor)
            for (i, row) in rows.enumerated() {
                let rowY = yTop - CGFloat(i + 1) * 34 + 10
                drawText(row, in: CGRect(x: content.minX + 14, y: rowY, width: content.width - 28, height: 16), attributes: attrs(size: 12))
                if i < rows.count - 1 { line(CGPoint(x: content.minX + 14, y: rowY - 9), CGPoint(x: content.maxX, y: rowY - 9)) }
            }
            yTop -= CGFloat(rows.count) * 34 + 28
        }
        var y = content.maxY - 20
        switch tab {
        case "General":
            section("Behavior", ["Launch at login", "Auto-paste on selection", "Pause clipboard monitoring"], at: &y)
            section("Permissions", ["Accessibility not recognized                         Open Settings", "Auto-paste only works when macOS trusts Clipwell."], at: &y)
            section("Shortcuts", ["Open clipboard picker                                      Cmd-Shift-V", "Paste as plain text                                      Option"], at: &y)
        case "Privacy":
            section("Ignored Apps", ["Choose a running app or enter its Bundle ID.", "Safari                                                com.apple.Safari"], at: &y)
            section("Add App", ["Add Running App", "Filter running Apps", "Bundle ID, e.g. com.apple.Safari                  Add"], at: &y)
        case "Storage":
            section("Current History", ["Total entries                                                        27", "Pinned entries                                                        3", "Images stored                                                         4"], at: &y)
            section("Actions", ["Clear Unpinned History", "Clear All History"], at: &y)
        case "Language":
            section("Language", ["App language                                                   English", "System uses your macOS language when it is supported."], at: &y)
        default:
            section("About", ["Made with love by Marco Seefeldt", "Development status                                           2026", "Clipwell is open-source, free software.", "What does Clipwell do?"], at: &y)
            section("Security", ["Your clipboard history stays on this Mac.", "Clipwell does not upload clipboard content or analytics."], at: &y)
        }
    }
}

func drawImagePreviewScreenshot() -> NSImage {
    image(size: CGSize(width: 1000, height: 650)) { _ in
        let win = CGRect(x: 140, y: 70, width: 720, height: 520)
        drawWindowChrome(win, title: "Preview...")
        let img = CGRect(x: win.minX + 55, y: win.minY + 58, width: 610, height: 380)
        roundedRect(img, radius: 8, color: NSColor(calibratedRed: 0.95, green: 0.97, blue: 0.98, alpha: 1), stroke: .separatorColor)
        drawText("Quarterly Launch Plan", in: CGRect(x: img.minX + 50, y: img.maxY - 95, width: 520, height: 36), attributes: attrs(size: 30, weight: .bold))
        drawText("Copied image text is recognized by OCR and becomes searchable in Clipwell.", in: CGRect(x: img.minX + 52, y: img.maxY - 142, width: 500, height: 42), attributes: attrs(size: 16, color: .secondaryLabelColor))
        roundedRect(CGRect(x: img.minX + 52, y: img.minY + 90, width: 170, height: 80), radius: 8, color: .systemBlue.withAlphaComponent(0.14))
        roundedRect(CGRect(x: img.minX + 245, y: img.minY + 90, width: 170, height: 80), radius: 8, color: .systemGreen.withAlphaComponent(0.14))
        roundedRect(CGRect(x: img.minX + 438, y: img.minY + 90, width: 120, height: 80), radius: 8, color: .systemOrange.withAlphaComponent(0.14))
        drawText("Design", in: CGRect(x: img.minX + 92, y: img.minY + 122, width: 120, height: 20), attributes: attrs(size: 16, weight: .semibold))
        drawText("Review", in: CGRect(x: img.minX + 290, y: img.minY + 122, width: 120, height: 20), attributes: attrs(size: 16, weight: .semibold))
        drawText("Ship", in: CGRect(x: img.minX + 480, y: img.minY + 122, width: 80, height: 20), attributes: attrs(size: 16, weight: .semibold))
        drawText("Close", in: CGRect(x: win.maxX - 80, y: win.minY + 22, width: 50, height: 16), attributes: attrs(size: 13, color: .secondaryLabelColor))
    }
}

let rendered: [(Shot, NSImage)] = [
    (shots[0], drawPickerScreenshot()),
    (shots[1], drawContextScreenshot()),
    (shots[2], drawSettingsScreenshot(tab: "General")),
    (shots[3], drawSettingsScreenshot(tab: "Privacy")),
    (shots[4], drawSettingsScreenshot(tab: "Storage")),
    (shots[5], drawSettingsScreenshot(tab: "About")),
    (shots[6], drawImagePreviewScreenshot())
]

for (shot, image) in rendered {
    try saveImage(image, to: screenshotsURL.appendingPathComponent(shot.filename))
}

struct ManualPage {
    let title: String
    let sections: [(String, [String])]
    let image: Shot?
}

let pages: [ManualPage] = [
    ManualPage(title: "Clipwell User Manual", sections: [
        ("Version 1.2", [
            "Clipwell is a fast, native macOS clipboard manager. It lives in the menu bar, records recent clipboard items, and lets you search and reuse text, images, and file references.",
            "This manual explains installation, daily use, search, actions, settings, privacy controls, keyboard shortcuts, OCR, and troubleshooting."
        ]),
        ("Requirements", [
            "macOS 14 Sonoma or later.",
            "Accessibility permission is optional and only required for auto-paste."
        ])
    ], image: shots[0]),
    ManualPage(title: "Getting Started", sections: [
        ("Install and Launch", [
            "Open Clipwell.app from the distribution folder or build it with ./scripts/build-app.sh and open dist/Clipwell.app.",
            "After launch, Clipwell appears in the macOS menu bar. Click the menu bar icon to open the picker, or use Cmd-Shift-V."
        ]),
        ("First Copies", [
            "Copy text, images, or files as usual. Clipwell stores each item locally and adds it to the searchable history.",
            "Pinned entries stay available even when unpinned history is cleaned up or truncated by the maximum history limit."
        ])
    ], image: shots[0]),
    ManualPage(title: "The Clipboard Picker", sections: [
        ("Search and Navigate", [
            "Type in the search field to filter history. Search includes normal text, file names, URL text, and recognized OCR text from images.",
            "Use the Up and Down arrow keys to change the selected row, Return to choose it, Escape to close the picker, and Delete to remove the selected entry."
        ]),
        ("Sort and Group", [
            "Use the sort menu to order items by Newest, Oldest, Type, or App.",
            "Use the group menu to group items by Date, Type, or App, or keep the list ungrouped."
        ])
    ], image: shots[0]),
    ManualPage(title: "Using History Items", sections: [
        ("Paste", [
            "Click an item or press Return while it is selected. If auto-paste is disabled, Clipwell restores the item to the system clipboard. If auto-paste is enabled and Accessibility permission is granted, Clipwell also performs the paste keystroke."
        ]),
        ("Plain Text", [
            "Hold Option while clicking or confirming an item to paste plain text. This is useful when you want to remove formatting from copied rich text.",
            "For image items with OCR text, plain-text paste can paste the recognized text."
        ]),
        ("Context Menu", [
            "Right-click a row for additional actions: Paste, Paste as Plain Text, Edit, Preview, Pin or Unpin, and Delete.",
            "Edit is available for text items. Preview is available for image items."
        ])
    ], image: shots[1]),
    ManualPage(title: "Images, Files, URLs, and OCR", sections: [
        ("Images", [
            "Copied images are stored with thumbnails for the picker. Open Preview from the row context menu to inspect the full image.",
            "Clipwell runs OCR on copied images in the background. Recognized text becomes searchable and can be pasted as plain text."
        ]),
        ("Files", [
            "When you copy files in Finder, Clipwell stores file references and displays file names in history."
        ]),
        ("URLs and Code", [
            "URL items are detected automatically and can show URL metadata when available.",
            "Code-like text is displayed with a monospaced preview and a Code badge."
        ])
    ], image: shots[6]),
    ManualPage(title: "General Settings", sections: [
        ("Behavior", [
            "Launch at login starts Clipwell automatically after you sign in.",
            "Auto-paste on selection pastes the selected item immediately. This requires Accessibility permission.",
            "Pause clipboard monitoring temporarily stops Clipwell from recording new clipboard changes."
        ]),
        ("History", [
            "Keep up to a configured number of items, from 10 to 2000.",
            "Duplicate handling can keep all copies, collapse identical consecutive copies, or deduplicate globally."
        ]),
        ("Shortcuts", [
            "Open clipboard picker: Cmd-Shift-V.",
            "Paste as plain text: hold Option while selecting."
        ])
    ], image: shots[2]),
    ManualPage(title: "Privacy Settings", sections: [
        ("Ignored Apps", [
            "Use Privacy settings to exclude apps from clipboard recording. This is useful for password managers, banking apps, private notes, or any app whose clipboard content should not be stored.",
            "Add a currently running app from the menu, filter the list, or enter a Bundle ID such as com.apple.Safari."
        ]),
        ("Local Data", [
            "Clipwell stores clipboard history locally on this Mac. It does not upload clipboard content, send analytics, or contact external services for clipboard history."
        ])
    ], image: shots[3]),
    ManualPage(title: "Storage, Language, and About", sections: [
        ("Storage", [
            "The Storage tab shows total entries, pinned entries, and stored image count.",
            "Clear Unpinned History removes normal history while keeping pinned entries. Clear All History removes everything."
        ]),
        ("Language", [
            "Choose System, English, Deutsch, Polski, or Francais. System follows your macOS language when supported and falls back to English."
        ]),
        ("About", [
            "The About tab includes app information, security notes, and a built-in guide explaining what Clipwell does."
        ])
    ], image: shots[4]),
    ManualPage(title: "Troubleshooting", sections: [
        ("Auto-paste Does Not Work", [
            "Open Settings > General and check the Accessibility status. Click Open Settings and allow the currently running Clipwell binary in System Settings > Privacy & Security > Accessibility.",
            "If you use different debug or release builds, remove old Clipwell entries and allow the current one."
        ]),
        ("No New Items Appear", [
            "Make sure Pause clipboard monitoring is off.",
            "Check Privacy settings to confirm the source app is not ignored.",
            "Quit and relaunch Clipwell if macOS pasteboard monitoring appears stale."
        ]),
        ("History Cleanup", [
            "Pinned entries are intended for items you want to preserve. Use Clear Unpinned History for routine cleanup without losing pinned items."
        ])
    ], image: shots[5])
]

let mediaBox = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
guard let consumer = CGDataConsumer(url: pdfURL as CFURL),
      let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
    fatalError("Could not create PDF context")
}

func drawPDFImage(_ image: NSImage, in rect: CGRect) {
    guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
    context.saveGState()
    context.draw(cg, in: rect)
    context.restoreGState()
}

for (pageIndex, page) in pages.enumerated() {
    context.beginPDFPage([kCGPDFContextMediaBox as String: mediaBox] as CFDictionary)
    let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsContext

    NSColor.white.setFill()
    mediaBox.fill()
    var y = mediaBox.maxY - 64
    let margin: CGFloat = 56
    let width = mediaBox.width - margin * 2

    drawText(page.title, in: CGRect(x: margin, y: y - 34, width: width, height: 40), attributes: attrs(size: pageIndex == 0 ? 30 : 24, weight: .bold))
    y -= pageIndex == 0 ? 64 : 54

    if let shot = page.image, let image = rendered.first(where: { $0.0.filename == shot.filename })?.1 {
        let imageHeight: CGFloat = pageIndex == 0 ? 250 : 220
        let imageRect = CGRect(x: margin, y: y - imageHeight, width: width, height: imageHeight)
        roundedRect(imageRect.insetBy(dx: -1, dy: -1), radius: 8, color: .white, stroke: .separatorColor)
        drawPDFImage(image, in: imageRect)
        y -= imageHeight + 13
        drawText(shot.caption, in: CGRect(x: margin, y: y - 28, width: width, height: 30), attributes: attrs(size: 9.5, color: .secondaryLabelColor))
        y -= 45
    }

    for (heading, bullets) in page.sections {
        drawText(heading, in: CGRect(x: margin, y: y - 20, width: width, height: 22), attributes: attrs(size: 15, weight: .semibold))
        y -= 29
        for bullet in bullets {
            let bulletText = "• " + bullet
            let h = measureText(bulletText, width: width - 10, attributes: attrs(size: 11.2))
            drawText(bulletText, in: CGRect(x: margin + 10, y: y - h, width: width - 10, height: h + 4), attributes: attrs(size: 11.2))
            y -= h + 10
        }
        y -= 8
    }

    drawText("Clipwell User Manual | Page \(pageIndex + 1)", in: CGRect(x: margin, y: 28, width: width, height: 14), attributes: attrs(size: 9, color: .tertiaryLabelColor))

    NSGraphicsContext.restoreGraphicsState()
    context.endPDFPage()
}

context.closePDF()
print("Created \(pdfURL.path)")
print("Created screenshots in \(screenshotsURL.path)")
