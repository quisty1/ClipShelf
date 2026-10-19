import Foundation
import CoreData

@MainActor public protocol SnapshotStorage: AnyObject {
    func load() throws -> Data?
    func save(_ snapshot: Data) throws
}

@MainActor final class CoreDataSnapshotStorage: SnapshotStorage {
    private let coordinator: NSPersistentStoreCoordinator
    private let context: NSManagedObjectContext
    init(directory: URL, inMemory: Bool) throws {
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
    }
    func load() throws -> Data? {
        try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "LibraryRecord")).first?.value(forKey: "snapshot") as? Data
    }
    func save(_ snapshot: Data) throws {
        do {
            let records = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "LibraryRecord"))
            let record = records.first ?? NSEntityDescription.insertNewObject(forEntityName: "LibraryRecord", into: context)
            if record.value(forKey: "id") == nil { record.setValue(UUID(), forKey: "id") }
            record.setValue(snapshot, forKey: "snapshot")
            try context.save()
        } catch { context.rollback(); throw error }
    }
}
