import AppKit

public enum ClipboardError: LocalizedError {
    case tooLarge, unreadableImage, writeFailed
    public var errorDescription: String? {
        switch self {
        case .tooLarge: "Элемент слишком большой. Максимум: 20 МБ для изображения, 5 МБ для текста."
        case .unreadableImage: "Не удалось прочитать изображение."
        case .writeFailed: "Не удалось записать элемент в системный буфер."
        }
    }
}

@MainActor public enum PasteboardCodec {
    public static func read(from board: NSPasteboard) throws -> ClipPayload? {
        let types = Set((board.types ?? []).map(\.rawValue))
        guard CapturePolicy.allows(paused: false, source: nil, excluded: [], types: types),
              !types.contains(NSPasteboard.PasteboardType.fileURL.rawValue) else { return nil }
        if let png = board.data(forType: .png) {
            guard png.count <= 20 * 1024 * 1024 else { throw ClipboardError.tooLarge }
            guard NSBitmapImageRep(data: png) != nil else { throw ClipboardError.unreadableImage }
            return ClipPayload(png: png)
        }
        if let tiff = board.data(forType: .tiff) {
            guard tiff.count <= 20 * 1024 * 1024 else { throw ClipboardError.tooLarge }
            guard let bitmap = NSBitmapImageRep(data: tiff), bitmap.pixelsWide * bitmap.pixelsHigh <= 40_000_000,
                  let png = bitmap.representation(using: .png, properties: [:]), png.count <= 20 * 1024 * 1024 else { throw ClipboardError.unreadableImage }
            return ClipPayload(png: png)
        }
        let rtf = board.data(forType: .rtf)
        let html = board.data(forType: .html)
        guard (rtf?.count ?? 0) <= 5 * 1024 * 1024, (html?.count ?? 0) <= 5 * 1024 * 1024 else { throw ClipboardError.tooLarge }
        var text = board.string(forType: .string) ?? board.string(forType: .URL)
        if text == nil, let rtf {
            text = try? NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil).string
        }
        if text == nil, let html {
            let extracted = HTMLText.extract(html)
            text = extracted.isEmpty ? "HTML-фрагмент" : extracted
        }
        guard let text, !text.isEmpty else { return nil }
        guard text.utf8.count <= 5 * 1024 * 1024 else { throw ClipboardError.tooLarge }
        return ClipPayload(text: text, rtf: rtf, html: html)
    }

    public static func write(_ payload: ClipPayload, to board: NSPasteboard, transform: TextTransform? = nil) throws {
        let item = NSPasteboardItem()
        if let transform, let text = payload.text { item.setString(transform.apply(text), forType: .string) }
        else {
            if let text = payload.text { item.setString(text, forType: .string) }
            if let rtf = payload.rtf { item.setData(rtf, forType: .rtf) }
            if let html = payload.html { item.setData(html, forType: .html) }
            if let png = payload.png { item.setData(png, forType: .png) }
            if payload.kind == .link, let url = payload.text { item.setString(url, forType: .URL) }
        }
        item.setData(Data(), forType: NSPasteboard.PasteboardType(CapturePolicy.ownType))
        board.clearContents()
        guard board.writeObjects([item]) else { throw ClipboardError.writeFailed }
    }
}

private enum HTMLText {
    // Extract a searchable fallback without a web renderer or resource loading.
    // Original HTML is retained verbatim for insertion into rich text editors.
    static func extract(_ data: Data) -> String {
        var text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) ?? ""
        text = text.replacingOccurrences(of: "(?is)<(script|style|head)\\b[^>]*>.*?</\\1\\s*>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?s)<!--.*?-->", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)<\\s*(br\\s*/?|/\\s*(p|div|li|h[1-6]|tr|blockquote))\\s*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "<(?:(?:\"[^\"]*\")|(?:'[^']*')|[^'\">])*>", with: "", options: .regularExpression)
        let named = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ", "mdash": "—", "ndash": "–", "hellip": "…", "copy": "©", "reg": "®"]
        if let expression = try? NSRegularExpression(pattern: "&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);") {
            let original = text as NSString
            let output = NSMutableString(string: text)
            for match in expression.matches(in: text, range: NSRange(location: 0, length: original.length)).reversed() {
                let entity = original.substring(with: match.range(at: 1))
                var replacement = named[entity]
                if entity.hasPrefix("#") {
                    let hex = entity.lowercased().hasPrefix("#x")
                    if let value = UInt32(entity.dropFirst(hex ? 2 : 1), radix: hex ? 16 : 10), let scalar = UnicodeScalar(value) { replacement = String(scalar) }
                }
                if let replacement { output.replaceCharacters(in: match.range, with: replacement) }
            }
            text = output as String
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
