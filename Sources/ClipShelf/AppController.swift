import AppKit
import SwiftUI
import ApplicationServices
import ClipShelfCore
import Observation

final class ShelfPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@Observable final class AppController: NSObject {
    let repository: ClipRepository
    let preferences: Preferences
    let monitor: ClipboardMonitor
    var notice: String?
    var showSettings = false
    var showOnboarding = false
    var presentationID = UUID()
    @ObservationIgnored private let hotKey = HotKeyService()
    @ObservationIgnored private var statusItem: NSStatusItem?
    @ObservationIgnored private var panel: ShelfPanel?
    @ObservationIgnored private var target: NSRunningApplication?
    @ObservationIgnored private var pasteTask: Task<Void, Never>?
    @ObservationIgnored private var noticeTask: Task<Void, Never>?
    @ObservationIgnored private var expandedWindow: NSWindow?
    @ObservationIgnored var isVerificationMode = false

    init(directory: URL, preferences: Preferences = Preferences()) throws {
        self.preferences = preferences
        repository = try ClipRepository(directory: directory)
        monitor = ClipboardMonitor(repository: repository, preferences: preferences)
        super.init()
    }
    func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "square.on.square", accessibilityDescription: "ClipShelf — история буфера")
        item.button?.target = self; item.button?.action = #selector(statusClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.toolTip = "ClipShelf · \(preferences.shortcut.label)"
        statusItem = item
        hotKey.onPress = { [weak self] in self?.toggle() }
        if !isVerificationMode {
            do { try hotKey.register(preferences.shortcut) } catch { notify(error.localizedDescription) }
            monitor.start()
        }
        if !preferences.completedOnboarding { show(); showOnboarding = true }
    }
    func stop() { pasteTask?.cancel(); monitor.stop(); hotKey.stop() }
    @objc private func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "Открыть ClipShelf", action: #selector(openFromMenu), keyEquivalent: "").target = self
            menu.addItem(withTitle: preferences.paused ? "Продолжить запись" : "Приостановить запись", action: #selector(pauseFromMenu), keyEquivalent: "").target = self
            menu.addItem(withTitle: "Настройки…", action: #selector(settingsFromMenu), keyEquivalent: "").target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: "Завершить ClipShelf", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            statusItem?.menu = menu; statusItem?.button?.performClick(nil); statusItem?.menu = nil
        } else { toggle() }
    }
    @objc private func openFromMenu() { show() }
    @objc private func pauseFromMenu() { monitor.ignoreCurrent(); preferences.paused.toggle() }
    @objc private func settingsFromMenu() { show(); showSettings = true }
    func toggle() {
        if panel?.isVisible == true && panel?.isKeyWindow == true { hide() } else { show() }
    }
    func show() {
        pasteTask?.cancel()
        if !isVerificationMode { monitor.capturePending() }
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ProcessInfo.processInfo.processIdentifier { target = front }
        if panel == nil {
            let p = ShelfPanel(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 650), styleMask: [.titled, .closable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            p.title = "ClipShelf"; p.titleVisibility = .hidden; p.titlebarAppearsTransparent = true
            p.isReleasedWhenClosed = false; p.isFloatingPanel = true; p.level = .floating
            p.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            p.minSize = NSSize(width: 880, height: 530)
            p.contentView = NSHostingView(rootView: ShelfView(app: self))
            p.setFrameAutosaveName("ClipShelfPanel")
            panel = p
        }
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main,
           let p = panel, !p.isVisible {
            let rect = screen.visibleFrame
            p.setFrameOrigin(NSPoint(x: rect.midX - p.frame.width / 2, y: rect.midY - p.frame.height / 2 + 35))
        }
        presentationID = UUID()
        panel?.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }
    func hide() { panel?.orderOut(nil) }
    func notify(_ message: String) {
        notice = message; noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(7))
            guard !Task.isCancelled else { return }; self?.notice = nil
        }
    }
    func perform(_ operation: () throws -> Void) {
        do { try operation() } catch { notify(error.localizedDescription) }
    }
    func setShortcut(_ value: Shortcut) {
        guard value != preferences.shortcut else { return }
        do { try hotKey.register(value); preferences.shortcut = value; statusItem?.button?.toolTip = "ClipShelf · \(value.label)" }
        catch { notify(error.localizedDescription) }
    }
    var accessibilityAllowed: Bool { AXIsProcessTrusted() }
    var automationSettingsName: String {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
            ? "Device Control and Data Access"
            : "Универсальный доступ / Accessibility"
    }
    private func prepareForExternalSettings() {
        showSettings = false; showOnboarding = false
        panel?.level = .normal
        hide()
    }
    func requestAccessibility() {
        let opened = PermissionHelp.open(
            prepare: prepareForExternalSettings,
            hasAccess: { self.accessibilityAllowed },
            requestAccess: {
                _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
            },
            openSettings: {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        )
        if !opened { show(); notify("Откройте Системные настройки → Privacy & Security → \(automationSettingsName).") }
    }
    func revealApplication() {
        prepareForExternalSettings()
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }
    func openClipboardSettings() {
        prepareForExternalSettings()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Pasteboard")!)
    }
    func use(_ entry: ClipEntry, copyOnly: Bool = false, transform: TextTransform? = nil) {
        do { try PasteboardCodec.write(repository.payload(for: entry), to: .general, transform: transform); monitor.ignoreCurrent() }
        catch { notify(error.localizedDescription); return }
        guard !copyOnly else { hide(); target?.activate(options: []); return }
        guard accessibilityAllowed else {
            notify("Скопировано. Для автовставки откройте настройки ClipShelf → «Настроить вставку». Если ClipShelf уже включён в macOS, удалите старую запись и добавьте приложение заново.")
            return
        }
        guard let destination = target, !destination.isTerminated else {
            notify("Скопировано. Переключитесь в нужное приложение и нажмите ⌘V."); return
        }
        hide()
        pasteTask?.cancel()
        pasteTask = Task { [weak self] in
            guard destination.activate(options: []) else { self?.show(); self?.notify("Скопировано, но переключиться в приложение не удалось."); return }
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(40))
                guard !Task.isCancelled else { return }
                guard !destination.isTerminated else {
                    self?.show(); self?.notify("Скопировано. Приложение закрылось — выберите другое и нажмите ⌘V."); return
                }
                if NSWorkspace.shared.frontmostApplication?.processIdentifier == destination.processIdentifier {
                    // A short focus-settle period; recheck immediately before injecting the event.
                    try? await Task.sleep(for: .milliseconds(60))
                    guard !Task.isCancelled else { return }
                    guard AXIsProcessTrusted(),
                          NSWorkspace.shared.frontmostApplication?.processIdentifier == destination.processIdentifier,
                          let down = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),
                          let up = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) else {
                        self?.show(); self?.notify("Скопировано. Фокус изменился или доступ отозван — вставьте с помощью ⌘V."); return
                    }
                    down.flags = .maskCommand; up.flags = .maskCommand
                    down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap)
                    return
                }
            }
            self?.show(); self?.notify("Скопировано. Приложение не получило фокус — вставьте с помощью ⌘V.")
        }
    }
    func expand(_ entry: ClipEntry) {
        let view = ExpandedPreview(entry: entry, repository: repository)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 580), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = entry.displayTitle; window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view); window.center(); window.makeKeyAndOrderFront(nil)
        expandedWindow = window
    }
}
