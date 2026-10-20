import Foundation
import Observation

public enum AppLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case russian = "ru"

    public var nativeName: String { self == .english ? "English" : "Русский" }
    public var locale: Locale { Locale(identifier: rawValue) }
}

public enum AppTheme: String, CaseIterable, Sendable {
    case system, light, dark
}

@MainActor @Observable public final class InterfacePreferences {
    @ObservationIgnored private let defaults: UserDefaults
    public var language: AppLanguage { didSet { defaults.set(language.rawValue, forKey: "language") } }
    public var theme: AppTheme { didSet { defaults.set(theme.rawValue, forKey: "theme") } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = defaults.string(forKey: "language").flatMap(AppLanguage.init(rawValue:)) ?? .english
        theme = defaults.string(forKey: "theme").flatMap(AppTheme.init(rawValue:)) ?? .system
    }
}
