import Foundation

/// Explicit language selection also works for AppKit strings and core presentation.
/// It never changes AppleLanguages or the user's stored clipboard content.
public struct Localizer: Sendable {
    public let language: AppLanguage
    public init(language: AppLanguage = .english) { self.language = language }

    private static let resourceBundle: Bundle = {
        // SwiftPM's generated accessor checks the app root, while a signed macOS app
        // keeps resources in Contents/Resources. Prefer that portable bundle first.
        if let url = Bundle.main.url(forResource: "ClipShelf_ClipShelfCore", withExtension: "bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return Bundle.module
    }()

    private static let tables: [AppLanguage: [String: String]] = Dictionary(uniqueKeysWithValues: AppLanguage.allCases.map { language in
        guard let url = resourceBundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: language.rawValue),
              let data = try? Data(contentsOf: url),
              let table = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else {
            preconditionFailure("Missing localization resources for \(language.rawValue)")
        }
        return (language, table)
    })

    public static func translations(for language: AppLanguage) -> [String: String] { tables[language] ?? [:] }

    public func callAsFunction(_ key: String, _ arguments: any CVarArg...) -> String {
        let value = Self.tables[language]?[key] ?? Self.tables[.english]?[key] ?? key
        guard !arguments.isEmpty else { return value }
        return String(format: value, locale: language.locale, arguments: arguments)
    }
}
