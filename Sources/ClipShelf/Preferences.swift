import AppKit
import Carbon
import Observation
import ServiceManagement

struct Shortcut: Codable, Equatable {
    var keyCode: UInt32 = UInt32(kVK_ANSI_V)
    var modifiers: UInt32 = UInt32(cmdKey | shiftKey)
    var label = "⇧⌘V"
}

@Observable final class Preferences {
    @ObservationIgnored private let defaults: UserDefaults
    var paused: Bool { didSet { defaults.set(paused, forKey: "paused") } }
    var completedOnboarding: Bool { didSet { defaults.set(completedOnboarding, forKey: "onboarded") } }
    var historyLimit: Int { didSet { defaults.set(historyLimit, forKey: "limit") } }
    var retentionDays: Int { didSet { defaults.set(retentionDays, forKey: "days") } }
    var exclusions: [String] { didSet { defaults.set(exclusions, forKey: "exclusions") } }
    var shortcut: Shortcut { didSet { if let data = try? JSONEncoder().encode(shortcut) { defaults.set(data, forKey: "shortcut") } } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        paused = defaults.bool(forKey: "paused")
        completedOnboarding = defaults.bool(forKey: "onboarded")
        historyLimit = max(100, defaults.object(forKey: "limit") as? Int ?? 1000)
        retentionDays = max(1, defaults.object(forKey: "days") as? Int ?? 30)
        exclusions = defaults.stringArray(forKey: "exclusions") ?? []
        shortcut = defaults.data(forKey: "shortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? Shortcut()
    }
    var launchAtLogin: Bool { SMAppService.mainApp.status == .enabled }
    func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }
}

nonisolated private func hotKeyHandler(_ next: EventHandlerCallRef?, _ event: EventRef?, _ context: UnsafeMutableRawPointer?) -> OSStatus {
    guard let context else { return OSStatus(eventNotHandledErr) }
    // Carbon dispatches application event handlers on the main event loop.
    let address = UInt(bitPattern: context)
    return MainActor.assumeIsolated {
        Unmanaged<HotKeyService>.fromOpaque(UnsafeMutableRawPointer(bitPattern: address)!).takeUnretainedValue().onPress?()
        return noErr
    }
}

final class HotKeyService {
    var onPress: (() -> Void)?
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func register(_ shortcut: Shortcut) throws {
        // Register the replacement before releasing the old shortcut.
        var replacement: EventHotKeyRef?
        let result = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers,
            EventHotKeyID(signature: 0x434C4950, id: 1), GetApplicationEventTarget(), 0, &replacement)
        guard result == noErr else { throw ShortcutError.unavailable }
        if let reference { UnregisterEventHotKey(reference) }
        reference = replacement
    }
    func stop() {
        if let reference { UnregisterEventHotKey(reference); self.reference = nil }
        if let handler { RemoveEventHandler(handler); self.handler = nil }
    }
}
enum ShortcutError: LocalizedError {
    case unavailable
    var errorDescription: String? { "Это сочетание уже занято. Выберите другое в настройках." }
}
