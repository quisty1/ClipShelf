import Foundation
import CoreData
import Observation

@MainActor @Observable public final class ClipRepository {
    public private(set) var entries: [ClipEntry] = []
    public private(set) var collections: [ClipCollection] = []
    @ObservationIgnored private let coordinator: NSPersistentStoreCoordinator
    @ObservationIgnored private let context: NSManagedObjectContext
    public let directory: URL
    public var imageDirectory: URL { directory.appendingPathComponent("Images", isDirectory: true) }

    public init(directory: URL, inMemory: Bool = false) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("Images"), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription(); entity.name = "LibraryRecord"; entity.managedObjectClassName = "NSManagedObject"
        let id = NSAttributeDescription(); id.name = "id"; id.attributeType = .UUIDAttributeType; id.isOptional = false
        let data = NSAttributeDescription(); data.name = "snapshot"; data.attributeType = .binaryDataAttributeType; data.isOptional = false
        entity.properties = [id, data]; entity.uniquenessConstraints = [["id"]]; model.entities = [entity]
        coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: inMemory ? NSInMemoryStoreType : NSSQLiteStoreType, configurationName: nil,
            at: inMemory ? nil : directory.appendingPathComponent("history.sqlite"), options: nil)
        context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try reload()
        try removeOrphanImages()
    }

    private struct LibrarySnapshot: Codable {
        var entries: [EntrySnapshot]
        var collections: [CollectionSnapshot]
    }
    private func reload() throws {
        let records = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "LibraryRecord"))
        guard let data = records.first?.value(forKey: "snapshot") as? Data else { return }
        let library = try JSONDecoder().decode(LibrarySnapshot.self, from: data)
        entries = library.entries.map { $0.materialize() }.sorted { $0.lastCopiedAt > $1.lastCopiedAt }
        collections = library.collections.map { $0.materialize() }
    }
    private func commit() throws {
        do {
            let data = try JSONEncoder().encode(LibrarySnapshot(entries: entries.map(EntrySnapshot.init), collections: collections.map(CollectionSnapshot.init)))
            let records = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "LibraryRecord"))
            let record = records.first ?? NSEntityDescription.insertNewObject(forEntityName: "LibraryRecord", into: context)
            if record.value(forKey: "id") == nil { record.setValue(UUID(), forKey: "id") }
            record.setValue(data, forKey: "snapshot")
            try context.save()
            entries.sort { $0.lastCopiedAt > $1.lastCopiedAt }
        } catch { context.rollback(); try? reload(); throw error }
    }

    @discardableResult public func capture(_ payload: ClipPayload, sourceName: String = "", sourceID: String = "", at: Date = Date()) throws -> ClipEntry {
        let fingerprint = payload.fingerprint
        if let existing = entries.first(where: { !$0.isSnippet && $0.fingerprint == fingerprint }) {
            existing.lastCopiedAt = at; existing.sourceName = sourceName; existing.sourceID = sourceID
            try commit(); return existing
        }
        let filename = payload.png == nil ? nil : UUID().uuidString + ".png"
        if let filename, let png = payload.png {
            let url = imageDirectory.appendingPathComponent(filename)
            try png.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
        let entry = ClipEntry(payload: payload, imageName: filename, sourceName: sourceName, sourceID: sourceID, at: at)
        entries.append(entry)
        do { try commit() }
        catch {
            if let filename { try? FileManager.default.removeItem(at: imageDirectory.appendingPathComponent(filename)) }
            throw error
        }
        return entry
    }

    public func search(_ query: String, kind: ClipKind? = nil) -> [ClipEntry] {
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        return entries.filter { entry in
            (kind == nil || entry.kind == kind) && terms.allSatisfy { term in
                [entry.title, entry.text ?? "", entry.sourceName].contains {
                    $0.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                }
            }
        }
    }

    public func imageURL(for entry: ClipEntry) -> URL? { entry.imageName.map { imageDirectory.appendingPathComponent($0) } }
    public func payload(for entry: ClipEntry) throws -> ClipPayload {
        ClipPayload(text: entry.text, rtf: entry.rtf, html: entry.html, png: try imageURL(for: entry).map { try Data(contentsOf: $0) })
    }
    public func toggleFavorite(_ entry: ClipEntry) throws { entry.isFavorite.toggle(); try commit() }
    public func toggleCollection(_ id: UUID, for entry: ClipEntry) throws {
        guard collections.contains(where: { $0.id == id }) else { return }
        if entry.collectionIDs.contains(id) { entry.collectionIDs.removeAll { $0 == id } }
        else { entry.collectionIDs.append(id) }
        try commit()
    }
    @discardableResult public func createCollection(_ name: String) throws -> ClipCollection {
        let collection = ClipCollection(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        collections.append(collection); try commit(); return collection
    }
    public func renameCollection(_ collection: ClipCollection, to name: String) throws {
        collection.name = name.trimmingCharacters(in: .whitespacesAndNewlines); try commit()
    }
    public func deleteCollection(_ collection: ClipCollection) throws {
        let id = collection.id
        for entry in entries { entry.collectionIDs.removeAll { $0 == id } }
        collections.removeAll { $0.id == collection.id }; try commit()
    }
    public func edit(_ entry: ClipEntry, title: String, text: String, snippet: Bool) throws {
        if entry.text != text {
            entry.text = text; entry.rtf = nil; entry.html = nil
            entry.fingerprint = ClipPayload(text: text).fingerprint
            entry.kindRaw = ClipPayload(text: text).kind.rawValue
        }
        entry.title = title.trimmingCharacters(in: .whitespacesAndNewlines); entry.isSnippet = snippet
        try commit()
    }
    @discardableResult public func saveSnippet(title: String, text: String) throws -> ClipEntry {
        let entry = ClipEntry(payload: ClipPayload(text: text), imageName: nil, sourceName: "Шаблон", sourceID: "", at: Date())
        entry.title = title.trimmingCharacters(in: .whitespacesAndNewlines); entry.isSnippet = true
        entries.append(entry); try commit(); return entry
    }
    public func delete(_ entry: ClipEntry) throws { try deleteEntries([entry]) }
    private func deleteEntries(_ victims: [ClipEntry]) throws {
        let files = victims.compactMap { imageURL(for: $0) }
        let ids = Set(victims.map(\.id))
        entries.removeAll { ids.contains($0.id) }
        try commit()
        let used = Set(entries.compactMap(\.imageName))
        for file in files where !used.contains(file.lastPathComponent) {
            if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
        }
    }
    public func clear(includeProtected: Bool = false) throws {
        try deleteEntries(entries.filter { includeProtected || !$0.isProtected })
    }
    public func prune(limit: Int, days: Int, now: Date = Date()) throws {
        let cutoff = now.addingTimeInterval(-Double(max(1, days)) * 86400)
        var kept = 0
        let victims = entries.filter { entry in
            guard !entry.isProtected else { return false }
            if entry.lastCopiedAt < cutoff { return true }
            kept += 1; return kept > max(1, limit)
        }
        if !victims.isEmpty { try deleteEntries(victims) }
    }
    private func removeOrphanImages() throws {
        let used = Set(entries.compactMap(\.imageName))
        for file in try FileManager.default.contentsOfDirectory(at: imageDirectory, includingPropertiesForKeys: nil)
        where file.pathExtension == "png" && !used.contains(file.lastPathComponent) {
            try FileManager.default.removeItem(at: file)
        }
    }
}
