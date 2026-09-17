import AppKit
import Foundation
import PDFKit
import CoreText
import ImageIO
import UniformTypeIdentifiers

private let supportedExtensions: Set<String> = [
    "pdf", "jpg", "jpeg", "png", "webp", "heic", "heif", "tif", "tiff"
]

private enum WatermarkError: LocalizedError {
    case unreadableFile(String)
    case unsupportedFormat(String)
    case outputCreation(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .unreadableFile(let name): return "Impossible de lire \(name)."
        case .unsupportedFormat(let name): return "Format non pris en charge : \(name)."
        case .outputCreation(let name): return "Impossible de créer le fichier de sortie \(name)."
        case .writeFailed(let name): return "Échec de l’écriture de \(name)."
        }
    }
}

final class DropView: NSView {
    var onFilesDropped: (([URL]) -> Void)?
    private let titleLabel = NSTextField(labelWithString: "Glisse tes PDF et images ici")
    private let subtitleLabel = NSTextField(labelWithString: "PDF • JPG • PNG • WebP • HEIC • TIFF")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 1.5
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.45).cgColor

        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.alignment = .center
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center

        addSubview(titleLabel)
        addSubview(subtitleLabel)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        let centerY = bounds.midY
        titleLabel.frame = NSRect(x: 18, y: centerY + 2, width: bounds.width - 36, height: 22)
        subtitleLabel.frame = NSRect(x: 18, y: centerY - 22, width: bounds.width - 36, height: 18)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let canRead = sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: options)
        if canRead {
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
            return .copy
        }
        return []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        restoreAppearance()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { restoreAppearance() }
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let objects = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] else {
            return false
        }
        onFilesDropped?(objects)
        return true
    }

    private func restoreAppearance() {
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.45).cgColor
    }
}

private func writeLaunchLog(_ message: String) {
    let fm = FileManager.default
    let logs = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs", isDirectory: true)
    try? fm.createDirectory(at: logs, withIntermediateDirectories: true)
    let file = logs.appendingPathComponent("FiligraneLocal.log")
    let stamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(stamp)] \(message)\n"
    if let data = line.data(using: .utf8) {
        if fm.fileExists(atPath: file.path), let handle = try? FileHandle(forWritingTo: file) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: file)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private var window: NSWindow!
    private var files: [URL] = []

    private let tableView = NSTableView()
    private let watermarkField = NSTextField()
    private let opacitySlider = NSSlider(value: 0.24, minValue: 0.08, maxValue: 0.60, target: nil, action: nil)
    private let opacityValue = NSTextField(labelWithString: "24 %")
    private let angleSlider = NSSlider(value: -30, minValue: -60, maxValue: 60, target: nil, action: nil)
    private let angleValue = NSTextField(labelWithString: "-30°")
    private let tiledCheckbox = NSButton(checkboxWithTitle: "Répéter le filigrane sur toute la page", target: nil, action: nil)
    private let outputLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "Prêt.")
    private let processButton = NSButton(title: "Créer les copies filigranées", target: nil, action: nil)
    private let progress = NSProgressIndicator()
    private var outputFolder: URL

    override init() {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        self.outputFolder = desktop.appendingPathComponent("Filigrane Local", isDirectory: true)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        writeLaunchLog("applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.regular)
        buildMenu()
        buildWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func buildMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quitter Filigrane Local", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    private func buildWindow() {
        let size = NSSize(width: 760, height: 720)
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Filigrane Local"
        window.isReleasedWhenClosed = false

        guard let content = window.contentView else { return }

        let title = NSTextField(labelWithString: "Filigrane Local")
        title.font = .systemFont(ofSize: 25, weight: .bold)
        title.frame = NSRect(x: 28, y: 667, width: 300, height: 32)
        content.addSubview(title)

        let privacy = NSTextField(labelWithString: "Traitement 100 % local • aucun fichier envoyé sur Internet • originaux préservés")
        privacy.textColor = .secondaryLabelColor
        privacy.font = .systemFont(ofSize: 12)
        privacy.frame = NSRect(x: 28, y: 645, width: 700, height: 18)
        content.addSubview(privacy)

        let drop = DropView(frame: NSRect(x: 28, y: 535, width: 704, height: 92))
        drop.onFilesDropped = { [weak self] urls in self?.addFiles(urls) }
        content.addSubview(drop)

        let addButton = NSButton(title: "Ajouter des fichiers…", target: self, action: #selector(selectFiles))
        addButton.frame = NSRect(x: 28, y: 495, width: 160, height: 30)
        content.addSubview(addButton)

        let removeButton = NSButton(title: "Retirer", target: self, action: #selector(removeSelected))
        removeButton.frame = NSRect(x: 196, y: 495, width: 90, height: 30)
        content.addSubview(removeButton)

        let clearButton = NSButton(title: "Tout vider", target: self, action: #selector(clearFiles))
        clearButton.frame = NSRect(x: 294, y: 495, width: 95, height: 30)
        content.addSubview(clearButton)

        let scroll = NSScrollView(frame: NSRect(x: 28, y: 375, width: 704, height: 112))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file"))
        column.title = "Documents à traiter"
        column.width = 680
        tableView.addTableColumn(column)
        tableView.headerView = NSTableHeaderView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = true
        scroll.documentView = tableView
        content.addSubview(scroll)

        let wmLabel = NSTextField(labelWithString: "Texte du filigrane")
        wmLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        wmLabel.frame = NSRect(x: 28, y: 338, width: 180, height: 20)
        content.addSubview(wmLabel)

        let df = DateFormatter()
        df.locale = Locale(identifier: "fr_FR")
        df.dateFormat = "dd/MM/yyyy"
        watermarkField.stringValue = "DESTINÉ UNIQUEMENT À [AGENCE] — DOSSIER INTÉRIM — \(df.string(from: Date()))"
        watermarkField.placeholderString = "Ex. DESTINÉ UNIQUEMENT À MANPOWER — DOSSIER INTÉRIM — 17/09/2026"
        watermarkField.frame = NSRect(x: 28, y: 304, width: 704, height: 28)
        content.addSubview(watermarkField)

        let opacityLabel = NSTextField(labelWithString: "Opacité")
        opacityLabel.frame = NSRect(x: 28, y: 267, width: 80, height: 20)
        content.addSubview(opacityLabel)
        opacitySlider.frame = NSRect(x: 100, y: 263, width: 215, height: 24)
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged)
        content.addSubview(opacitySlider)
        opacityValue.frame = NSRect(x: 320, y: 267, width: 60, height: 20)
        content.addSubview(opacityValue)

        let angleLabel = NSTextField(labelWithString: "Angle")
        angleLabel.frame = NSRect(x: 400, y: 267, width: 60, height: 20)
        content.addSubview(angleLabel)
        angleSlider.frame = NSRect(x: 455, y: 263, width: 210, height: 24)
        angleSlider.target = self
        angleSlider.action = #selector(angleChanged)
        content.addSubview(angleSlider)
        angleValue.frame = NSRect(x: 670, y: 267, width: 60, height: 20)
        content.addSubview(angleValue)

        tiledCheckbox.state = .on
        tiledCheckbox.frame = NSRect(x: 28, y: 230, width: 300, height: 24)
        content.addSubview(tiledCheckbox)

        let outputTitle = NSTextField(labelWithString: "Dossier de sortie")
        outputTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        outputTitle.frame = NSRect(x: 28, y: 193, width: 130, height: 20)
        content.addSubview(outputTitle)

        outputLabel.stringValue = outputFolder.path
        outputLabel.lineBreakMode = .byTruncatingMiddle
        outputLabel.textColor = .secondaryLabelColor
        outputLabel.frame = NSRect(x: 28, y: 166, width: 555, height: 20)
        content.addSubview(outputLabel)

        let outputButton = NSButton(title: "Choisir…", target: self, action: #selector(selectOutputFolder))
        outputButton.frame = NSRect(x: 610, y: 160, width: 122, height: 30)
        content.addSubview(outputButton)

        processButton.target = self
        processButton.action = #selector(processFiles)
        processButton.keyEquivalent = "\r"
        processButton.frame = NSRect(x: 28, y: 104, width: 704, height: 42)
        processButton.bezelStyle = .rounded
        processButton.font = .systemFont(ofSize: 15, weight: .semibold)
        content.addSubview(processButton)

        progress.style = .spinning
        progress.controlSize = .small
        progress.frame = NSRect(x: 28, y: 64, width: 18, height: 18)
        progress.isDisplayedWhenStopped = false
        content.addSubview(progress)

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.frame = NSRect(x: 54, y: 62, width: 678, height: 22)
        content.addSubview(statusLabel)

        let footnote = NSTextField(labelWithString: "Les images exportées ne recopient pas les métadonnées EXIF/GPS. Les PDF sont recréés avec le filigrane aplati.")
        footnote.textColor = .tertiaryLabelColor
        footnote.font = .systemFont(ofSize: 11)
        footnote.frame = NSRect(x: 28, y: 28, width: 704, height: 18)
        content.addSubview(footnote)

        window.makeKeyAndOrderFront(nil)
    }

    func numberOfRows(in tableView: NSTableView) -> Int { files.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("FileCell")
        let text: NSTextField
        if let existing = tableView.makeView(withIdentifier: id, owner: self) as? NSTextField {
            text = existing
        } else {
            text = NSTextField(labelWithString: "")
            text.identifier = id
            text.lineBreakMode = .byTruncatingMiddle
        }
        text.stringValue = files[row].lastPathComponent
        text.toolTip = files[row].path
        return text
    }

    @objc private func selectFiles() {
        let panel = NSOpenPanel()
        panel.title = "Choisir les documents à filigraner"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.resolvesAliases = true
        panel.allowedContentTypes = supportedExtensions.compactMap { UTType(filenameExtension: $0) }
        if panel.runModal() == .OK { addFiles(panel.urls) }
    }

    private func addFiles(_ urls: [URL]) {
        let valid = urls.filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
        for url in valid where !files.contains(url) { files.append(url) }
        tableView.reloadData()
        statusLabel.stringValue = files.isEmpty ? "Prêt." : "\(files.count) document(s) prêt(s) à être traité(s)."
    }

    @objc private func removeSelected() {
        let indexes = tableView.selectedRowIndexes
        files.remove(atOffsets: indexes)
        tableView.reloadData()
        statusLabel.stringValue = files.isEmpty ? "Prêt." : "\(files.count) document(s) restant(s)."
    }

    @objc private func clearFiles() {
        files.removeAll()
        tableView.reloadData()
        statusLabel.stringValue = "Prêt."
    }

    @objc private func opacityChanged() {
        opacityValue.stringValue = "\(Int((opacitySlider.doubleValue * 100).rounded())) %"
    }

    @objc private func angleChanged() {
        angleValue.stringValue = "\(Int(angleSlider.doubleValue.rounded()))°"
    }

    @objc private func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choisir le dossier de sortie"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            outputFolder = url
            outputLabel.stringValue = url.path
        }
    }

    @objc private func processFiles() {
        guard !files.isEmpty else {
            showAlert(title: "Aucun document", message: "Ajoute au moins un PDF ou une image.")
            return
        }
        let text = watermarkField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            showAlert(title: "Filigrane vide", message: "Saisis le texte à ajouter sur les documents.")
            return
        }

        do {
            try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
        } catch {
            showAlert(title: "Dossier inaccessible", message: error.localizedDescription)
            return
        }

        processButton.isEnabled = false
        progress.startAnimation(nil)
        statusLabel.stringValue = "Traitement en cours…"

        let batch = files
        let folder = outputFolder
        let opacity = CGFloat(opacitySlider.doubleValue)
        let angle = CGFloat(angleSlider.doubleValue)
        let tiled = tiledCheckbox.state == .on

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var successes = 0
            var failures: [String] = []

            for input in batch {
                autoreleasepool {
                    do {
                        if input.pathExtension.lowercased() == "pdf" {
                            let output = self.uniqueOutputURL(for: input, in: folder)
                            try self.processPDF(input: input, output: output, text: text, opacity: opacity, angle: angle, tiled: tiled)
                        } else {
                            let output = self.uniqueOutputURL(for: input, in: folder)
                            _ = try self.processImage(input: input, output: output, text: text, opacity: opacity, angle: angle, tiled: tiled)
                        }
                        successes += 1
                    } catch {
                        failures.append("\(input.lastPathComponent) : \(error.localizedDescription)")
                    }
                }
            }

            DispatchQueue.main.async {
                self.progress.stopAnimation(nil)
                self.processButton.isEnabled = true
                if failures.isEmpty {
                    self.statusLabel.stringValue = "Terminé : \(successes) copie(s) créée(s)."
                    NSWorkspace.shared.open(folder)
                } else {
                    self.statusLabel.stringValue = "Terminé : \(successes) succès, \(failures.count) échec(s)."
                    self.showAlert(title: "Traitement terminé avec des erreurs", message: failures.joined(separator: "\n"))
                }
            }
        }
    }

    private func uniqueOutputURL(for input: URL, in folder: URL, forcedExtension: String? = nil) -> URL {
        let fm = FileManager.default
        let base = input.deletingPathExtension().lastPathComponent + "_filigrane"
        let ext = forcedExtension ?? input.pathExtension.lowercased()
        var candidate = folder.appendingPathComponent(base).appendingPathExtension(ext)
        var index = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base)_\(index)").appendingPathExtension(ext)
            index += 1
        }
        return candidate
    }

    private func processPDF(input: URL, output: URL, text: String, opacity: CGFloat, angle: CGFloat, tiled: Bool) throws {
        guard let document = PDFDocument(url: input), document.pageCount > 0 else {
            throw WatermarkError.unreadableFile(input.lastPathComponent)
        }
        guard let consumer = CGDataConsumer(url: output as CFURL) else {
            throw WatermarkError.outputCreation(output.lastPathComponent)
        }

        var initialBox = document.page(at: 0)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 612, height: 792)
        initialBox.origin = .zero
        guard let context = CGContext(consumer: consumer, mediaBox: &initialBox, nil) else {
            throw WatermarkError.outputCreation(output.lastPathComponent)
        }

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let originalBounds = page.bounds(for: .mediaBox)
            let pageBox = CGRect(origin: .zero, size: originalBounds.size)
            let info: [CFString: Any] = [kCGPDFContextMediaBox: pageBox]
            context.beginPDFPage(info as CFDictionary)

            context.saveGState()
            context.translateBy(x: -originalBounds.minX, y: -originalBounds.minY)
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()

            drawWatermark(in: context, canvasSize: pageBox.size, text: text, opacity: opacity, angleDegrees: angle, tiled: tiled)
            context.endPDFPage()
        }
        context.closePDF()

        guard FileManager.default.fileExists(atPath: output.path) else {
            throw WatermarkError.writeFailed(output.lastPathComponent)
        }
    }

    @discardableResult
    private func processImage(input: URL, output: URL, text: String, opacity: CGFloat, angle: CGFloat, tiled: Bool) throws -> URL {
        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil) else {
            throw WatermarkError.unreadableFile(input.lastPathComponent)
        }

        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = (props?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 4096
        let height = (props?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 4096
        let maxDimension = max(width, height)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw WatermarkError.unreadableFile(input.lastPathComponent)
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw WatermarkError.outputCreation(output.lastPathComponent)
        }

        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.clear(rect)
        context.draw(image, in: rect)
        drawWatermark(in: context, canvasSize: rect.size, text: text, opacity: opacity, angleDegrees: angle, tiled: tiled)

        guard let rendered = context.makeImage() else {
            throw WatermarkError.writeFailed(output.lastPathComponent)
        }

        let ext = output.pathExtension.lowercased()
        let preferredType = UTType(filenameExtension: ext)?.identifier as CFString?
        if let preferredType, writeImage(rendered, to: output, type: preferredType, extension: ext) {
            return output
        }

        let fallback = uniqueOutputURL(for: input, in: output.deletingLastPathComponent(), forcedExtension: "png")
        guard writeImage(rendered, to: fallback, type: UTType.png.identifier as CFString, extension: "png") else {
            throw WatermarkError.writeFailed(output.lastPathComponent)
        }
        return fallback
    }

    private func writeImage(_ image: CGImage, to url: URL, type: CFString, extension ext: String) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type, 1, nil) else { return false }
        var properties: [CFString: Any] = [:]
        if ext == "jpg" || ext == "jpeg" {
            properties[kCGImageDestinationLossyCompressionQuality] = 0.95
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        return CGImageDestinationFinalize(destination)
    }

    private func drawWatermark(in context: CGContext, canvasSize: CGSize, text: String, opacity: CGFloat, angleDegrees: CGFloat, tiled: Bool) {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }

        let shortest = min(canvasSize.width, canvasSize.height)
        var fontSize = max(18, shortest * 0.045)
        if shortest > 1800 { fontSize = max(44, shortest * 0.042) }

        let font = NSFont.boldSystemFont(ofSize: fontSize)
        let color = NSColor(calibratedWhite: 0.18, alpha: opacity)
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        let textWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let diagonal = hypot(canvasSize.width, canvasSize.height)
        let rowSpacing = fontSize * 4.0
        let colSpacing = max(fontSize * 3.0, textWidth * 0.22)

        context.saveGState()
        context.translateBy(x: canvasSize.width / 2, y: canvasSize.height / 2)
        context.rotate(by: angleDegrees * .pi / 180)
        context.textMatrix = .identity

        if tiled {
            var y = -diagonal
            var row = 0
            while y <= diagonal {
                let offset = (row % 2 == 0) ? 0 : (textWidth + colSpacing) / 2
                var x = -diagonal - textWidth + offset
                while x <= diagonal {
                    context.textPosition = CGPoint(x: x, y: y)
                    CTLineDraw(line, context)
                    x += textWidth + colSpacing
                }
                y += rowSpacing
                row += 1
            }
        } else {
            context.textPosition = CGPoint(x: -textWidth / 2, y: -fontSize / 2)
            CTLineDraw(line, context)
        }

        context.restoreGState()
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private extension Array {
    mutating func remove(atOffsets offsets: IndexSet) {
        for index in offsets.sorted(by: >) where indices.contains(index) {
            remove(at: index)
        }
    }
}


writeLaunchLog("process started")
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
writeLaunchLog("entering NSApplication.run()")
app.run()
writeLaunchLog("NSApplication.run() returned")
