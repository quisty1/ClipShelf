import Foundation

@MainActor private var failures = 0
@MainActor func expect(_ value: @autoclosure () throws -> Bool, file: StaticString = #filePath, line: UInt = #line) {
    do { if try !value() { failures += 1; print("FAIL \(file):\(line)") } }
    catch { failures += 1; print("FAIL \(file):\(line): \(error)") }
}
struct RequiredValueMissing: Error {}
func require<T>(_ value: T?) throws -> T {
    guard let value else { throw RequiredValueMissing() }; return value
}

@main struct TestRunner {
    @MainActor static func main() {
        let p = PayloadTests(); let r = RepositoryTests(); let b = PasteboardTests()
        let tests: [(String, () throws -> Void)] = [
            ("source-transition privacy", p.sourceTransitionsDiscardAmbiguousCopies),
            ("first-save failure recovery", r.firstSaveFailureLeavesNoGhostOrBrokenImageReference),
            ("HTML-only capture", b.htmlOnlyCaptureHasSearchableTextAndKeepsOriginalHTML),
            ("format identity", p.formatsArePartOfIdentity),
            ("URL classification", p.classifiesOnlyCompleteWebURLs),
            ("text transforms", p.transformationsPreserveSource),
            ("capture privacy policy", p.policyDiscardsPausedExcludedAndSensitiveCopies),
            ("change cursor", p.countsPreventDuplicateOwnAndPausedEvents),
            ("dedup and search", r.duplicatesMoveToTopAndSearchIncludesTitle),
            ("collection deletion", r.deletingCollectionKeepsEntries),
            ("protected retention", r.retentionProtectsFavoritesSnippetsAndCollections),
            ("image ownership", r.imageDeletionCleansFileAndRoundTripsPayload),
            ("persistent restart", r.persistentStoreRestoresRichContentAndCollections),
            ("independent snippets and full clear", r.snippetsRemainIndependentAndEditsDoNotChangeHistory),
            ("1000-entry search and retention", r.thousandEntrySearchAndRetention),
            ("rich pasteboard write", b.writesRichFormatsAndOwnMarkerWithoutRecapture),
            ("external pasteboard read", b.readsExternalRichTextAndRejectsSensitiveAndFileItems),
            ("image and plain paste", b.imageRoundTripAndPlainTransformation)
        ]
        for (name, test) in tests {
            let before = failures
            do { try test() } catch { failures += 1; print("FAIL \(name): \(error)") }
            if before == failures { print("PASS \(name)") }
        }
        print("\(tests.count) checks, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}
