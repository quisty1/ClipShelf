import AppKit
import SwiftUI
import ClipShelfCore

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue = AppLanguage.english
}
extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}

struct InterfaceRoot<Content: View>: View {
    let preferences: Preferences
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .environment(\.appLanguage, preferences.language)
            .environment(\.locale, preferences.language.locale)
    }
}

extension AppTheme {
    var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
    func label(strings: Localizer) -> String {
        switch self {
        case .system: strings("System")
        case .light: strings("Light")
        case .dark: strings("Dark")
        }
    }
}

/// Keep error identity until presentation so changing language also updates visible errors.
struct InterfaceMessage {
    var key: String?
    var arguments: [String] = []
    var error: (any Error)?

    func text(strings: Localizer) -> String {
        let detail: String
        if let clipboardError = error as? ClipboardError { detail = clipboardError.message(language: strings.language) }
        else if error is ShortcutError { detail = strings("This shortcut is already in use. Choose another one in Settings.") }
        else { detail = error?.localizedDescription ?? "" }
        guard let key else { return detail }
        // Messages use object placeholders only; numeric UI formats are resolved directly.
        let format = strings(key)
        return String(format: format, locale: strings.language.locale, arguments: error == nil ? arguments : [detail])
    }
}
