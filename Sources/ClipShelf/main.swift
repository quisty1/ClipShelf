import AppKit
import ClipShelfCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: AppController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = ProcessInfo.processInfo.arguments
        let verification = args.contains("--verify-ui")
        let directory = verification
            ? URL(fileURLWithPath: ProcessInfo.processInfo.environment["CLIPSHELF_VERIFY_DIR"] ?? NSTemporaryDirectory() + "ClipShelf-UI-Verification")
            : FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ClipShelf", isDirectory: true)
        let defaults = verification ? UserDefaults(suiteName: "app.clipshelf.verification")! : .standard
        if verification && args.contains("--reset-preferences") { defaults.removePersistentDomain(forName: "app.clipshelf.verification") }
        let preferences = Preferences(defaults: defaults)
        if verification {
            if args.contains("--light") { preferences.theme = .light }
            if args.contains("--dark") { preferences.theme = .dark }
            if args.contains("--system") { preferences.theme = .system }
            if args.contains("--english") { preferences.language = .english }
            if args.contains("--russian") { preferences.language = .russian }
            preferences.completedOnboarding = !args.contains("--onboarding")
        }
        NSApp.appearance = preferences.theme.appearance
        do {
            if !verification, NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "app.clipshelf.mac").filter({ $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }).isEmpty == false {
                NSApp.terminate(nil); return
            }
            let app = try AppController(directory: directory, preferences: preferences)
            app.isVerificationMode = verification
            controller = app
            if verification && !args.contains("--empty") && app.repository.entries.isEmpty {
                let collection = try app.repository.createCollection("Работа")
                let snippet = try app.repository.saveSnippet(title: "Ответ на письмо", text: "Здравствуйте!\n\nСпасибо за ваше сообщение. Вернусь с ответом в течение дня.\n\nХорошего дня!")
                try app.repository.toggleFavorite(snippet)
                try app.repository.toggleCollection(collection.id, for: snippet)
                _ = try app.repository.capture(ClipPayload(text: "https://developer.apple.com"), sourceName: "Safari", sourceID: "com.apple.Safari")
                _ = try app.repository.capture(ClipPayload(text: "Идеи для проекта\n• Собрать референсы\n• Подготовить прототип\n• Обсудить с командой"), sourceName: "Заметки", sourceID: "com.apple.Notes")
                let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 600, pixelsHigh: 400, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                if let bitmap {
                    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
                    NSColor(srgbRed: 0.19, green: 0.53, blue: 0.46, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: 600, height: 400).fill()
                    NSColor.white.withAlphaComponent(0.3).setFill(); NSBezierPath(ovalIn: NSRect(x: 300, y: 70, width: 280, height: 280)).fill()
                    NSColor.white.withAlphaComponent(0.7).setFill(); NSBezierPath(roundedRect: NSRect(x: 70, y: 80, width: 240, height: 240), xRadius: 45, yRadius: 45).fill()
                    NSGraphicsContext.restoreGraphicsState()
                    if let png = bitmap.representation(using: .png, properties: [:]) { _ = try app.repository.capture(ClipPayload(png: png), sourceName: "Предпросмотр", sourceID: "com.apple.Preview") }
                }
                if args.contains("--long") {
                    _ = try app.repository.capture(ClipPayload(text: String(repeating: "Длинный текст для проверки предпросмотра.\n", count: 600)), sourceName: "Тест")
                }
            }
            if verification && args.contains("--protected-only") { try app.repository.clear() }
            app.start()
            if verification { app.show() }
        } catch {
            let strings = Localizer(language: preferences.language)
            let alert = NSAlert(); alert.messageText = strings("Could Not Open ClipShelf")
            alert.informativeText = strings("History is unchanged. %@\nData folder: %@", InterfaceMessage(error: error).text(strings: strings), directory.path)
            alert.addButton(withTitle: strings("Done"))
            alert.alertStyle = .critical; alert.runModal(); NSApp.terminate(nil)
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { controller?.show(); return true }
    func applicationWillTerminate(_ notification: Notification) { controller?.stop() }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
