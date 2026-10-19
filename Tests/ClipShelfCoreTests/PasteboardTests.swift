import AppKit
import ClipShelfCore

@MainActor struct PasteboardTests {
    func htmlOnlyCaptureHasSearchableTextAndKeepsOriginalHTML() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let html = Data("<p>Hello &amp; мир</p><p>Second &#128512;</p><script>secret()</script><img src='https://example.invalid/no-fetch'>".utf8)
        board.setData(html, forType: .html)
        let payload = try require(PasteboardCodec.read(from: board))
        expect(payload.text?.contains("Hello & мир") == true)
        expect(payload.text?.contains("Second 😀") == true)
        expect(payload.text?.contains("secret") == false)
        expect(payload.html == html)
    }
    func writesRichFormatsAndOwnMarkerWithoutRecapture() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let payload = ClipPayload(text: "hello", rtf: Data([1, 2]), html: Data("<b>hello</b>".utf8))
        try PasteboardCodec.write(payload, to: board)
        expect(board.string(forType: .string) == "hello")
        expect(board.data(forType: .rtf) == Data([1, 2]))
        expect(board.types?.contains(NSPasteboard.PasteboardType(CapturePolicy.ownType)) == true)
        expect(try PasteboardCodec.read(from: board) == nil)
    }

    func readsExternalRichTextAndRejectsSensitiveAndFileItems() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.clearContents(); board.setString("Привет", forType: .string)
        let read = try require(PasteboardCodec.read(from: board))
        expect(read.text == "Привет")
        board.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        expect(try PasteboardCodec.read(from: board) == nil)
        board.clearContents(); board.setString("file:///tmp/private.txt", forType: .fileURL)
        board.setString("private.txt", forType: .string)
        expect(try PasteboardCodec.read(from: board) == nil)
    }

    func imageRoundTripAndPlainTransformation() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let bitmap = try require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let png = try require(bitmap.representation(using: .png, properties: [:]))
        board.clearContents(); board.setData(png, forType: .png)
        expect(try PasteboardCodec.read(from: board)?.png != nil)
        try PasteboardCodec.write(ClipPayload(text: "  hello  ", rtf: Data([1])), to: board, transform: .trim)
        expect(board.string(forType: .string) == "hello")
        expect(board.data(forType: .rtf) == nil)
    }
}
