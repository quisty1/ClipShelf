import AppKit
import ClipShelfCore

@main struct WindowChecks {
    @MainActor static func main() throws {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let suite = "ClipShelfWindowChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            for window in application.windows { window.orderOut(nil) }
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        let prefs = Preferences(defaults: defaults)
        let controller = try AppController(directory: directory, preferences: prefs)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Before recording", forType: .string)
        let monitor = ClipboardMonitor(repository: controller.repository, preferences: prefs, board: board)
        prefs.completedOnboarding = true
        monitor.capturePending()
        guard controller.repository.entries.isEmpty else { print("FAIL imported existing clipboard"); exit(1) }
        board.clearContents()
        board.setString("macOS clipboard check", forType: .string)
        monitor.capturePending()
        guard controller.repository.entries.count == 1,
              controller.repository.entries.first?.text == "macOS clipboard check",
              monitor.status == "Recording history" else {
            print("FAIL clipboard capture or recording status: \(monitor.status)"); exit(1)
        }
        prefs.paused = true
        board.clearContents()
        board.setString("Paused clipboard", forType: .string)
        monitor.capturePending()
        prefs.paused = false
        monitor.capturePending()
        guard controller.repository.entries.count == 1 else { print("FAIL imported paused clipboard"); exit(1) }
        print("PASS clipboard recording, status, existing and paused content exclusion")
        let image = ClipEntry(payload: ClipPayload(png: Data([1])), imageName: nil, sourceName: "", sourceID: "", at: Date())
        controller.expand(image)
        controller.expand(image)
        let previews = application.windows.filter { $0.title == "Image" }
        guard previews.count == 2 else { print("FAIL: expected two open preview windows, got \(previews.count)"); exit(1) }
        prefs.language = .russian
        guard previews.allSatisfy({ $0.title == "Изображение" }) else {
            print("FAIL: earlier preview title not translated: \(previews.map(\.title))"); exit(1)
        }
        prefs.theme = .light
        guard application.appearance?.name == .aqua else { print("FAIL light appearance"); exit(1) }
        prefs.theme = .dark
        guard application.appearance?.name == .darkAqua else { print("FAIL dark appearance"); exit(1) }
        prefs.theme = .system
        guard application.appearance == nil else { print("FAIL system appearance override remains"); exit(1) }
        guard application.mainMenu?.items.last?.title == "Правка" else { print("FAIL translated native menu"); exit(1) }
        print("PASS multiple preview titles, live appearance mappings, native menus")
    }
}
