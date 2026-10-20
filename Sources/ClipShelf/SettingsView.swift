import SwiftUI
import ClipShelfCore
import AppKit
import Carbon
import UniformTypeIdentifiers
import ServiceManagement

struct SettingsView: View {
    @Environment(\.appLanguage) private var language
    private var strings: Localizer { Localizer(language: language) }
    @Bindable var app: AppController
    @Environment(\.dismiss) private var dismiss
    @State private var loginEnabled = false
    @State private var clearConfirmation = false
    @State private var clearEverything = false
    @State private var error: InterfaceMessage?
    @State private var accessibility = AXIsProcessTrusted()

    var body: some View {
        @Bindable var prefs = app.preferences
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) { Text(strings("Settings")).font(.title2.bold()); Text(strings("ClipShelf · everything stays on your Mac")).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button(strings("Done")) { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(24)
            Divider()
            Form {
                Section(strings("Appearance")) {
                    Picker(strings("Language"), selection: $prefs.language) {
                        ForEach(AppLanguage.allCases, id: \.self) { Text($0.nativeName).tag($0) }
                    }
                    Picker(strings("Theme"), selection: $prefs.theme) {
                        ForEach(AppTheme.allCases, id: \.self) { Text($0.label(strings: strings)).tag($0) }
                    }
                }
                Section(strings("General")) {
                    Toggle(strings("Pause History Recording"), isOn: Binding(get: { prefs.paused }, set: { app.monitor.ignoreCurrent(); prefs.paused = $0 }))
                    HStack { Text(strings("Open ClipShelf")); Spacer(); ShortcutRecorder(shortcut: prefs.shortcut, strings: strings, changed: app.setShortcut).frame(width: 150, height: 28) }
                    Toggle(strings("Launch at Login"), isOn: Binding(get: { loginEnabled }, set: { enabled in
                        do { try prefs.setLaunchAtLogin(enabled); loginEnabled = prefs.launchAtLogin }
                        catch { self.error = InterfaceMessage(error: error); loginEnabled = prefs.launchAtLogin }
                    }))
                    if SMAppService.mainApp.status == .requiresApproval { Text(strings("Approve launch at login in System Settings → General → Login Items.")).font(.caption).foregroundStyle(.secondary) }
                }
                Section(strings("History")) {
                    Picker(strings("Maximum Regular Items"), selection: $prefs.historyLimit) {
                        ForEach([100, 500, 1000, 3000, 10000], id: \.self) { Text($0.formatted()).tag($0) }
                    }
                    Picker(strings("Keep Regular Items"), selection: $prefs.retentionDays) {
                        ForEach([1, 7, 30, 90, 365], id: \.self) { Text(strings("%ld days", $0)).tag($0) }
                    }
                    Text(strings("Favorites, snippets, and items in collections are never removed automatically. Images: up to 20 MB; text and formatting: up to 5 MB per format.")).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(strings("Clear Regular History…")) { clearEverything = false; clearConfirmation = true }
                            .disabled(!app.repository.entries.contains { !$0.isProtected })
                        Spacer()
                        Button(strings("Delete All Items…"), role: .destructive) { clearEverything = true; clearConfirmation = true }
                    }
                }
                Section(strings("Permissions")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(strings("Clipboard Reading"))
                            Text(app.monitor.status).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if #available(macOS 15.4, *) {
                            Button(strings("Request Access")) { app.monitor.requestAccess() }
                            Button(strings("macOS Settings")) { app.openClipboardSettings() }
                        }
                    }
                    HStack {
                        VStack(alignment: .leading) { Text(strings("Automatic Paste")); Text(accessibility ? strings("Access granted — press Enter to paste") : strings("macOS has not allowed automatic paste yet")).font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Button(strings("Set Up Pasting…")) { app.requestAccessibility() }
                    }
                    if !accessibility {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(strings("1. Click “Set Up Pasting” to open System Settings."))
                            Text(strings("2. Enable ClipShelf under “%@”.", app.automationSettingsName))
                            Text(strings("If the switch is already on, permission may belong to an older build. Select ClipShelf, click “−”, then “+”, and add the current app again."))
                            Button(strings("Show Current App in Finder")) { app.revealApplication() }
                        }.font(.caption).foregroundStyle(.secondary)
                    }
                    if #available(macOS 15.4, *) {
                        Text(strings("For background history, choose “Always Allow” for clipboard reading. If denied, the app will not ask again automatically.")).font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text(strings("Clipboard reading does not require additional permission on this version of macOS.")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section(strings("Excluded Apps")) {
                    ForEach(prefs.exclusions, id: \.self) { id in
                        HStack {
                            Text(appName(for: id)).lineLimit(1)
                            Spacer()
                            Button { prefs.exclusions.removeAll { $0 == id } } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain).accessibilityLabel(strings("Remove exclusion %@", id))
                        }
                    }
                    Button(strings("Add App…")) { pickExcludedApplication() }
                    Text(strings("Items marked as confidential are skipped. If an app does not mark them, exclude it here. History is stored locally, without additional encryption.")).font(.caption).foregroundStyle(.secondary)
                }
                if let error { Section { Text(error.text(strings: strings)).foregroundStyle(.red).textSelection(.enabled) } }
            }.formStyle(.grouped)
        }.frame(width: 680, height: 700)
            .onAppear { loginEnabled = prefs.launchAtLogin }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in accessibility = AXIsProcessTrusted(); loginEnabled = prefs.launchAtLogin }
            .onChange(of: prefs.historyLimit) { prune() }
            .onChange(of: prefs.retentionDays) { prune() }
            .alert(clearEverything ? strings("Delete All Items?") : strings("Clear Regular History?"), isPresented: $clearConfirmation) {
                Button(strings("Cancel"), role: .cancel) {}
                Button(strings("Delete"), role: .destructive) { app.perform { try app.repository.clear(includeProtected: clearEverything) } }
            } message: {
                Text(clearEverything ? strings("History, favorites, snippets, and items in collections will be deleted. Collections themselves will remain. This cannot be undone.") : strings("Favorites, snippets, and items in collections will be kept. This cannot be undone."))
            }
    }
    private func prune() { app.perform { try app.repository.prune(limit: app.preferences.historyLimit, days: app.preferences.retentionDays) } }
    private func appName(for id: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)?.deletingPathExtension().lastPathComponent ?? id
    }
    private func pickExcludedApplication() {
        let picker = NSOpenPanel(); picker.allowedContentTypes = [.applicationBundle]; picker.allowsMultipleSelection = true
        picker.directoryURL = URL(fileURLWithPath: "/Applications"); picker.prompt = strings("Exclude")
        if picker.runModal() == .OK {
            let identifiers = picker.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
            app.preferences.exclusions = Array(Set(app.preferences.exclusions + identifiers)).sorted()
            app.monitor.ignoreCurrent()
        }
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    var shortcut: Shortcut
    var strings: Localizer
    var changed: (Shortcut) -> Void
    final class Button: NSButton {
        var changed: ((Shortcut) -> Void)?
        var current = Shortcut()
        var strings = Localizer()
        private var recording = false
        func update(shortcut: Shortcut, strings: Localizer) {
            current = shortcut; self.strings = strings
            title = recording ? strings("Press a shortcut…") : shortcut.label
            setAccessibilityLabel(strings("Change Keyboard Shortcut"))
        }
        override var acceptsFirstResponder: Bool { true }
        override func mouseDown(with event: NSEvent) { recording = true; title = strings("Press a shortcut…"); window?.makeFirstResponder(self) }
        override func resignFirstResponder() -> Bool { recording = false; title = current.label; return true }
        override func keyDown(with event: NSEvent) {
            guard recording else { super.keyDown(with: event); return }
            if event.keyCode == 53 { recording = false; title = current.label; return }
            let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
            guard flags.contains(.command) || flags.contains(.control), let key = event.charactersIgnoringModifiers, !key.isEmpty,
                  !key.unicodeScalars.contains(where: { $0.value >= 0xF700 && $0.value <= 0xF8FF }) else { NSSound.beep(); return }
            var modifiers: UInt32 = 0
            var label = ""
            if flags.contains(.control) { modifiers |= UInt32(controlKey); label += "⌃" }
            if flags.contains(.option) { modifiers |= UInt32(optionKey); label += "⌥" }
            if flags.contains(.shift) { modifiers |= UInt32(shiftKey); label += "⇧" }
            if flags.contains(.command) { modifiers |= UInt32(cmdKey); label += "⌘" }
            label += key.uppercased()
            recording = false
            changed?(Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, label: label))
            title = current.label
        }
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard recording, event.type == .keyDown else { return super.performKeyEquivalent(with: event) }
            keyDown(with: event); return true
        }
    }
    func makeNSView(context: Context) -> Button { let button = Button(); button.bezelStyle = .rounded; button.setAccessibilityLabel(strings("Change Keyboard Shortcut")); return button }
    func updateNSView(_ nsView: Button, context: Context) { nsView.update(shortcut: shortcut, strings: strings); nsView.changed = changed }
}

struct OnboardingView: View {
    @Environment(\.appLanguage) private var language
    private var strings: Localizer { Localizer(language: language) }
    @Bindable var app: AppController
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: "square.on.square.fill").font(.system(size: 46)).foregroundStyle(.tint)
            Text(strings("Copied.\nSaved. Found.")).font(.system(size: 32, weight: .bold, design: .rounded))
            Text(strings("ClipShelf remembers text, links, and images while it runs. Open history with %@ and press Enter to paste.", app.preferences.shortcut.label)).font(.body).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                Label(strings("History stays on this Mac"), systemImage: "internaldrive")
                Label(strings("Favorites, snippets, and collections within reach"), systemImage: "star")
                Label(strings("Pause recording and exclude apps in Settings"), systemImage: "pause.circle")
            }.font(.callout)
            Divider()
            if #available(macOS 15.4, *) {
                Text(strings("Allow clipboard reading → “Always Allow”. For automatic paste, click “Set Up Pasting” and enable ClipShelf under “%@”. You can do this later — selected items will be copied for pasting with ⌘V.", app.automationSettingsName)).font(.callout).foregroundStyle(.secondary)
            } else {
                Text(strings("For automatic paste, click “Set Up Pasting” and enable ClipShelf under “%@”. You can do this later — selected items will be copied for pasting with ⌘V.", app.automationSettingsName)).font(.callout).foregroundStyle(.secondary)
            }
            HStack {
                if #available(macOS 15.4, *) {
                    Button(strings("Allow Reading")) { app.monitor.requestAccess() }
                }
                Button(strings("Set Up Pasting")) { app.requestAccessibility() }
            }
            HStack {
                Text(strings("Existing clipboard content is not imported.")).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(strings("Get Started")) { app.preferences.completedOnboarding = true; app.monitor.ignoreCurrent(); dismiss() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }.padding(36).frame(width: 580)
    }
}
