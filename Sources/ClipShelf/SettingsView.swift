import SwiftUI
import AppKit
import Carbon
import UniformTypeIdentifiers
import ServiceManagement

struct SettingsView: View {
    @Bindable var app: AppController
    @Environment(\.dismiss) private var dismiss
    @State private var loginEnabled = false
    @State private var clearConfirmation = false
    @State private var clearEverything = false
    @State private var error: String?
    @State private var accessibility = AXIsProcessTrusted()

    var body: some View {
        @Bindable var prefs = app.preferences
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) { Text("Настройки").font(.title2.bold()); Text("ClipShelf · всё остаётся на вашем Mac").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button("Готово") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(24)
            Divider()
            Form {
                Section("Основное") {
                    Toggle("Приостановить запись истории", isOn: Binding(get: { prefs.paused }, set: { app.monitor.ignoreCurrent(); prefs.paused = $0 }))
                    HStack { Text("Открыть ClipShelf"); Spacer(); ShortcutRecorder(shortcut: prefs.shortcut, changed: app.setShortcut).frame(width: 150, height: 28) }
                    Toggle("Запускать при входе в macOS", isOn: Binding(get: { loginEnabled }, set: { enabled in
                        do { try prefs.setLaunchAtLogin(enabled); loginEnabled = prefs.launchAtLogin }
                        catch { self.error = error.localizedDescription; loginEnabled = prefs.launchAtLogin }
                    }))
                    if SMAppService.mainApp.status == .requiresApproval { Text("Подтвердите автозапуск в Системных настройках → Основные → Объекты входа.").font(.caption).foregroundStyle(.secondary) }
                }
                Section("История") {
                    Picker("Максимум обычных записей", selection: $prefs.historyLimit) {
                        ForEach([100, 500, 1000, 3000, 10000], id: \.self) { Text($0.formatted()).tag($0) }
                    }
                    Picker("Хранить обычные записи", selection: $prefs.retentionDays) {
                        ForEach([1, 7, 30, 90, 365], id: \.self) { Text("\($0) дн.").tag($0) }
                    }
                    Text("Избранное, шаблоны и записи в коллекциях не удаляются автоматически. Изображение — до 20 МБ, текст и форматирование — до 5 МБ на формат.").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Очистить обычную историю…") { clearEverything = false; clearConfirmation = true }
                        Spacer()
                        Button("Удалить все записи…", role: .destructive) { clearEverything = true; clearConfirmation = true }
                    }
                }
                Section("Разрешения") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Чтение буфера обмена")
                            Text(app.monitor.status).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Запросить доступ") { app.monitor.requestAccess() }
                        Button("Настройки macOS") { app.openClipboardSettings() }
                    }
                    HStack {
                        VStack(alignment: .leading) { Text("Автоматическая вставка"); Text(accessibility ? "Доступ разрешён — можно вставлять по Enter" : "macOS пока не разрешает автоматическую вставку").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Button("Настроить вставку…") { app.requestAccessibility() }
                    }
                    if !accessibility {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. Нажмите «Настроить вставку» — откроются системные настройки.")
                            Text("2. В разделе «\(app.automationSettingsName)» включите ClipShelf.")
                            Text("Если переключатель уже включён, разрешение могло остаться от старой сборки. Выберите ClipShelf, нажмите «−», затем «+» и добавьте текущее приложение заново.")
                            Button("Показать текущее приложение в Finder") { app.revealApplication() }
                        }.font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Для фоновой истории выберите «Всегда разрешать» в разрешениях на чтение буфера. При отказе приложение не повторяет запросы автоматически.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Не записывать из приложений") {
                    ForEach(prefs.exclusions, id: \.self) { id in
                        HStack {
                            Text(appName(for: id)).lineLimit(1)
                            Spacer()
                            Button { prefs.exclusions.removeAll { $0 == id } } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain).accessibilityLabel("Убрать исключение \(id)")
                        }
                    }
                    Button("Добавить приложение…") { pickExcludedApplication() }
                    Text("Элементы с метками конфиденциальности пропускаются. Если приложение не ставит такую метку, исключите его здесь. История хранится локально, без отдельного шифрования.").font(.caption).foregroundStyle(.secondary)
                }
                if let error { Section { Text(error).foregroundStyle(.red).textSelection(.enabled) } }
            }.formStyle(.grouped)
        }.frame(width: 680, height: 700)
            .onAppear { loginEnabled = prefs.launchAtLogin }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in accessibility = AXIsProcessTrusted(); loginEnabled = prefs.launchAtLogin }
            .onChange(of: prefs.historyLimit) { prune() }
            .onChange(of: prefs.retentionDays) { prune() }
            .alert(clearEverything ? "Удалить все записи?" : "Очистить обычную историю?", isPresented: $clearConfirmation) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) { app.perform { try app.repository.clear(includeProtected: clearEverything) } }
            } message: {
                Text(clearEverything ? "Будут удалены история, избранное и шаблоны, включая записи коллекций. Сами коллекции сохранятся. Это действие нельзя отменить." : "Избранное, шаблоны и записи коллекций сохранятся. Это действие нельзя отменить.")
            }
    }
    private func prune() { app.perform { try app.repository.prune(limit: app.preferences.historyLimit, days: app.preferences.retentionDays) } }
    private func appName(for id: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)?.deletingPathExtension().lastPathComponent ?? id
    }
    private func pickExcludedApplication() {
        let picker = NSOpenPanel(); picker.allowedContentTypes = [.applicationBundle]; picker.allowsMultipleSelection = true
        picker.directoryURL = URL(fileURLWithPath: "/Applications"); picker.prompt = "Исключить"
        if picker.runModal() == .OK {
            let identifiers = picker.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
            app.preferences.exclusions = Array(Set(app.preferences.exclusions + identifiers)).sorted()
            app.monitor.ignoreCurrent()
        }
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    var shortcut: Shortcut
    var changed: (Shortcut) -> Void
    final class Button: NSButton {
        var changed: ((Shortcut) -> Void)?
        var current = Shortcut()
        private var recording = false
        override var acceptsFirstResponder: Bool { true }
        override func mouseDown(with event: NSEvent) { recording = true; title = "Нажмите сочетание…"; window?.makeFirstResponder(self) }
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
    func makeNSView(context: Context) -> Button { let button = Button(); button.bezelStyle = .rounded; button.setAccessibilityLabel("Изменить горячую клавишу"); return button }
    func updateNSView(_ nsView: Button, context: Context) { nsView.current = shortcut; nsView.title = shortcut.label; nsView.changed = changed }
}

struct OnboardingView: View {
    @Bindable var app: AppController
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: "square.on.square.fill").font(.system(size: 46)).foregroundStyle(.tint)
            Text("Скопировали.\nСохранили. Нашли.").font(.system(size: 32, weight: .bold, design: .rounded))
            Text("ClipShelf запоминает текст, ссылки и изображения, пока работает. Откройте историю сочетанием \(app.preferences.shortcut.label) и нажмите Enter для вставки.").font(.body).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                Label("История хранится только на этом Mac", systemImage: "internaldrive")
                Label("Избранное, шаблоны и коллекции всегда под рукой", systemImage: "star")
                Label("Паузу и исключения можно включить в настройках", systemImage: "pause.circle")
            }.font(.callout)
            Divider()
            Text("Разрешите чтение буфера → «Всегда разрешать». Для автоматической вставки нажмите «Настроить вставку» и включите ClipShelf в разделе «\(app.automationSettingsName)». Можно настроить позже — тогда выбранное копируется для вставки через ⌘V.").font(.callout).foregroundStyle(.secondary)
            HStack {
                Button("Разрешить чтение") { app.monitor.requestAccess() }
                Button("Настроить вставку") { app.requestAccessibility() }
            }
            HStack {
                Text("Старое содержимое буфера не импортируется.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Начать") { app.preferences.completedOnboarding = true; app.monitor.ignoreCurrent(); dismiss() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }.padding(36).frame(width: 580)
    }
}
