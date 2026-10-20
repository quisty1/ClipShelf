import AppKit
import Observation
import ClipShelfCore

@Observable final class ClipboardMonitor {
    private var statusKey = "Recording has not started"
    var status: String { Localizer(language: preferences.language)(statusKey) }
    var canRead: Bool {
        if #available(macOS 15.4, *) { return board.accessBehavior == .alwaysAllow }
        // Earlier macOS versions do not have per-app clipboard permissions.
        return true
    }
    var errorMessage: InterfaceMessage?
    @ObservationIgnored private let repository: ClipRepository
    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var cursor: CaptureCursor
    @ObservationIgnored private var lastPrune = Date.distantPast
    @ObservationIgnored private let board: NSPasteboard
    @ObservationIgnored private var activationObserver: (any NSObjectProtocol)?

    init(repository: ClipRepository, preferences: Preferences, board: NSPasteboard = .general) {
        self.repository = repository; self.preferences = preferences; self.board = board
        cursor = CaptureCursor(initialCount: board.changeCount, sourceID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    }
    func start() {
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                // Pasteboard does not expose its writer. Never attribute a pending copy
                // to the next application, especially when leaving an excluded app.
                self.cursor.sourceChanged(NSWorkspace.shared.frontmostApplication?.bundleIdentifier, currentCount: self.board.changeCount)
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }
    func stop() {
        timer?.invalidate(); timer = nil
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver); self.activationObserver = nil }
    }
    func requestAccess() {
        // This is exclusively a button action; never ask from the polling timer.
        _ = board.pasteboardItems
        cursor.ignoreThrough(board.changeCount)
        updateStatus()
    }
    func ignoreCurrent() { cursor.ignoreThrough(board.changeCount) }
    func capturePending() { tick() }
    private func updateStatus() {
        if preferences.paused { statusKey = "Recording paused" }
        else if !preferences.completedOnboarding { statusKey = "Finish setup" }
        else if #available(macOS 15.4, *), board.accessBehavior == .alwaysDeny { statusKey = "Clipboard reading is denied in macOS" }
        else if !canRead { statusKey = "Allow clipboard reading at all times to record history" }
        else { statusKey = "Recording history" }
    }
    private func tick() {
        updateStatus()
        let source = NSWorkspace.shared.frontmostApplication
        let changed = cursor.consume(board.changeCount, sourceID: source?.bundleIdentifier)
        guard preferences.completedOnboarding, !preferences.paused else { return }
        if Date().timeIntervalSince(lastPrune) > 60 {
            lastPrune = Date()
            do { try repository.prune(limit: preferences.historyLimit, days: preferences.retentionDays) }
            catch { errorMessage = InterfaceMessage(key: "Could not clear history: %@", error: error) }
        }
        guard changed, canRead else { return }
        guard source?.bundleIdentifier != Bundle.main.bundleIdentifier,
              CapturePolicy.allows(paused: false, source: source?.bundleIdentifier, excluded: Set(preferences.exclusions), types: []) else { return }
        let count = board.changeCount
        do {
            guard let payload = try PasteboardCodec.read(from: board), board.changeCount == count else { return }
            try repository.capture(payload, sourceName: source?.localizedName ?? "", sourceID: source?.bundleIdentifier ?? "")
            try repository.prune(limit: preferences.historyLimit, days: preferences.retentionDays)
        } catch { errorMessage = InterfaceMessage(error: error) }
    }
}
