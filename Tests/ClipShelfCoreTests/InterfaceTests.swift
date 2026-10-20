import Foundation
import ClipShelfCore

@MainActor struct InterfaceTests {
    func settingsDefaultPersistAndRecoverFromInvalidValues() throws {
        let suite = "ClipShelfChecks.\(UUID().uuidString)"
        let defaults = try require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["ru"], forKey: "AppleLanguages")
        let settings = InterfacePreferences(defaults: defaults)
        expect(settings.language == .english)
        expect(settings.theme == .system)
        settings.language = .russian
        settings.theme = .dark
        let restored = InterfacePreferences(defaults: defaults)
        expect(restored.language == .russian)
        expect(restored.theme == .dark)
        restored.theme = .light
        expect(InterfacePreferences(defaults: defaults).theme == .light)
        restored.theme = .system
        expect(InterfacePreferences(defaults: defaults).theme == .system)
        defaults.set("invalid", forKey: "language")
        defaults.set("invalid", forKey: "theme")
        expect(InterfacePreferences(defaults: defaults).language == .english)
        expect(InterfacePreferences(defaults: defaults).theme == .system)
    }

    func translationsCoverBothLanguagesAndFormatArguments() {
        let en = Localizer.translations(for: .english)
        let ru = Localizer.translations(for: .russian)
        expect(!en.isEmpty)
        expect(Set(en.keys) == Set(ru.keys))
        expect(en.values.allSatisfy { !$0.isEmpty })
        expect(ru.values.allSatisfy { !$0.isEmpty })
        let english = Localizer(language: .english)
        let russian = Localizer(language: .russian)
        expect(english("History") == "History")
        expect(russian("History") == "История")
        expect(english("%ld days", 30) == "30 days")
        expect(russian("%ld days", 30) == "30 дн.")
        expect(russian("Remove exclusion %@", "org.editor") == "Убрать исключение org.editor")
        expect(ClipboardError.writeFailed.message(language: .russian).contains("буфер"))
    }

    func presentationTranslatesWithoutChangingSavedContent() {
        let entry = ClipEntry(payload: ClipPayload(png: Data([1])), imageName: "image.png", sourceName: "", sourceID: "", at: Date())
        expect(entry.displayTitle(language: .english) == "Image")
        expect(entry.displayTitle(language: .russian) == "Изображение")
        entry.title = "Мой заголовок"
        expect(entry.displayTitle(language: .english) == "Мой заголовок")
        expect(entry.title == "Мой заголовок")
        expect(ClipKind.link.label(language: .russian) == "Ссылки")
        expect(TextTransform.plain.label(language: .english) == "Plain Text")
    }
}
