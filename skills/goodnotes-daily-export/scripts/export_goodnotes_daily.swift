#!/usr/bin/env swift
import Foundation
import PDFKit
import AppKit

struct Config {
    var sourceRoot = ""
    var outputRoot = ""
    var targetDate: String? = nil
    var verbose = false
}

func parseArgs() -> Config {
    var config = Config()
    let args = CommandLine.arguments
    var i = 1
    while i < args.count {
        switch args[i] {
        case "--source":
            i += 1
            if i < args.count {
                config.sourceRoot = NSString(string: args[i]).expandingTildeInPath
            }
        case "--output":
            i += 1
            if i < args.count {
                config.outputRoot = NSString(string: args[i]).expandingTildeInPath
            }
        case "--date":
            i += 1
            if i < args.count { config.targetDate = args[i] }
        case "--verbose":
            config.verbose = true
        default:
            break
        }
        i += 1
    }
    return config
}

let config = parseArgs()
guard !config.sourceRoot.isEmpty, !config.outputRoot.isEmpty else {
    fputs("Usage: export_goodnotes_daily.swift --source <dir> --output <dir> [--date YYYY-MM-DD] [--verbose]\n", stderr)
    exit(2)
}

let fm = FileManager.default
let iso = ISO8601DateFormatter()
let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "yyyy-MM-dd"
dateFormatter.timeZone = TimeZone.current

let targetDayString: String = config.targetDate ?? {
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    return dateFormatter.string(from: yesterday)
}()

guard let targetDay = dateFormatter.date(from: targetDayString) else {
    fputs("Invalid --date. Use yyyy-MM-dd\n", stderr)
    exit(2)
}

func ensureDir(_ path: String) throws {
    try fm.createDirectory(atPath: path, withIntermediateDirectories: true)
}

func relativePath(from base: String, to target: String) -> String {
    let baseParts = URL(fileURLWithPath: base, isDirectory: true).standardized.pathComponents
    let targetParts = URL(fileURLWithPath: target).standardized.pathComponents
    var i = 0
    while i < min(baseParts.count, targetParts.count), baseParts[i] == targetParts[i] {
        i += 1
    }
    let up = Array(repeating: "..", count: max(0, baseParts.count - i))
    return (up + Array(targetParts[i...])).joined(separator: "/")
}

func shell(_ executable: String, _ args: [String]) -> (Int32, String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = args
    let output = Pipe()
    process.standardOutput = output
    process.standardError = output
    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return (127, "Failed to run \(executable): \(error)")
    }
    let data = output.fileHandleForReading.readDataToEndOfFile()
    return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
}

func normalizeText(_ text: String) -> String {
    text.replacingOccurrences(of: "\u{0}", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func looksUsable(_ text: String) -> Bool {
    let t = normalizeText(text)
    if t.isEmpty { return false }
    if t.count >= 180 { return true }

    let meaningful = t.unicodeScalars.filter {
        CharacterSet.alphanumerics.contains($0) ||
        ($0.value >= 0x4E00 && $0.value <= 0x9FFF)
    }.count
    let punctuation = t.filter { "。！？；：，,.!?;:".contains($0) }.count
    let lines = t.split(separator: "\n")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
    let longLines = lines.filter { $0.count >= 8 }.count

    return (meaningful >= 60 && longLines >= 2) ||
           (meaningful >= 40 && punctuation >= 1 && longLines >= 1)
}

func renderPage(_ page: PDFPage, scale: CGFloat = 2.0) -> Data? {
    let bounds = page.bounds(for: .mediaBox)
    guard bounds.width > 0, bounds.height > 0 else { return nil }

    let size = NSSize(width: bounds.width * scale, height: bounds.height * scale)
    let image = NSImage(size: size)
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return nil
    }
    NSColor.white.setFill()
    context.fill(CGRect(origin: .zero, size: size))
    context.saveGState()
    context.scaleBy(x: scale, y: scale)
    page.draw(with: .mediaBox, to: context)
    context.restoreGState()
    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
    return bitmap.representation(using: .png, properties: [:])
}

func timestamp(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    formatter.timeZone = TimeZone.current
    return formatter.string(from: date)
}

func copyAndPrunePDF(_ source: String) throws -> String {
    let url = URL(fileURLWithPath: source)
    let attrs = try fm.attributesOfItem(atPath: source)
    let modified = (attrs[.modificationDate] as? Date) ?? Date()
    let base = url.deletingPathExtension().lastPathComponent
    let ext = url.pathExtension
    let name = "\(base)--\(timestamp(modified)).\(ext)"
    let destination = (config.outputRoot as NSString).appendingPathComponent(name)

    if !fm.fileExists(atPath: destination) {
        try Data(contentsOf: url, options: .mappedIfSafe)
            .write(to: URL(fileURLWithPath: destination))
    }

    let snapshots = try fm.contentsOfDirectory(atPath: config.outputRoot)
        .filter { $0.hasPrefix(base + "--") && $0.hasSuffix("." + ext) }
        .sorted(by: >)

    for extra in snapshots.dropFirst(2) {
        let path = (config.outputRoot as NSString).appendingPathComponent(extra)
        try fm.removeItem(atPath: path)
    }
    return destination
}

func markdown(for pdfPath: String) throws -> (String, [String]) {
    let url = URL(fileURLWithPath: pdfPath)
    guard let document = PDFDocument(url: url) else {
        throw NSError(
            domain: "goodnotes-daily-export",
            code: 10,
            userInfo: [NSLocalizedDescriptionKey: "Cannot open PDF: \(pdfPath)"]
        )
    }

    let base = url.deletingPathExtension().lastPathComponent
    let assetDir = (config.outputRoot as NSString)
        .appendingPathComponent("assets/\(base)")
    try ensureDir(assetDir)

    let attrs = try fm.attributesOfItem(atPath: pdfPath)
    let modified = (attrs[.modificationDate] as? Date).map { iso.string(from: $0) } ?? ""

    var lines = ["# \(base)", "", "- Source PDF: `\(pdfPath)`", "- Page count: \(document.pageCount)"]
    if !modified.isEmpty { lines.append("- Modified: \(modified)") }
    lines.append("")
    var assets: [String] = []

    for index in 0..<document.pageCount {
        guard let page = document.page(at: index) else { continue }
        let text = normalizeText(page.string ?? "")
        lines += ["## Page \(index + 1)", ""]

        if text.isEmpty {
            lines += ["_No extractable text found on this page._", ""]
        } else {
            lines += ["```text", text, "```", ""]
        }

        if !looksUsable(text), let png = renderPage(page) {
            let filename = String(format: "page-%03d.png", index + 1)
            let imagePath = (assetDir as NSString).appendingPathComponent(filename)
            try png.write(to: URL(fileURLWithPath: imagePath))
            assets.append(imagePath)
            lines += ["![\(base) page \(index + 1)](\(relativePath(from: config.outputRoot, to: imagePath)))", ""]
        }
    }

    return (lines.joined(separator: "\n"), assets)
}

guard fm.fileExists(atPath: config.sourceRoot) else {
    fputs("Source directory does not exist: \(config.sourceRoot)\n", stderr)
    exit(3)
}

try ensureDir(config.outputRoot)
try ensureDir((config.outputRoot as NSString).appendingPathComponent("assets"))

var pdfs: [String] = []
let enumerator = fm.enumerator(atPath: config.sourceRoot)
while let item = enumerator?.nextObject() as? String {
    guard item.lowercased().hasSuffix(".pdf") else { continue }
    let fullPath = (config.sourceRoot as NSString).appendingPathComponent(item)
    guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
          let modified = attrs[.modificationDate] as? Date,
          Calendar.current.isDate(modified, inSameDayAs: targetDay) else { continue }
    pdfs.append(fullPath)
}

pdfs.sort()
print("TARGET_DATE \(targetDayString)")
print("FOUND \(pdfs.count) PDF(s)")

for pdf in pdfs {
    do {
        if config.verbose { print("PROCESS \(pdf)") }
        let snapshot = try copyAndPrunePDF(pdf)
        let result = try markdown(for: pdf)
        let base = URL(fileURLWithPath: pdf).deletingPathExtension().lastPathComponent
        let mdPath = (config.outputRoot as NSString).appendingPathComponent(base + ".md")
        let newPath = mdPath + ".new"
        let diffPath = (config.outputRoot as NSString).appendingPathComponent(base + ".diff")

        try result.0.write(toFile: newPath, atomically: true, encoding: .utf8)
        if fm.fileExists(atPath: mdPath) {
            let (status, diff) = shell("/usr/bin/diff", ["-u", mdPath, newPath])
            try (status == 0 ? "" : diff)
                .write(toFile: diffPath, atomically: true, encoding: .utf8)
            try fm.removeItem(atPath: mdPath)
        }
        try fm.moveItem(atPath: newPath, toPath: mdPath)

        print("WROTE_PDF_VERSION \(snapshot)")
        print("WROTE_MD \(mdPath)")
        if fm.fileExists(atPath: diffPath) { print("WROTE_DIFF \(diffPath)") }
        for asset in result.1 { print("WROTE_ASSET \(asset)") }
    } catch {
        fputs("ERROR \(pdf): \(error)\n", stderr)
    }
}
