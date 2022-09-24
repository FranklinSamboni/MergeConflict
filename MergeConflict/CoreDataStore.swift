//
//  CoreDataStore.swift
//  MergeConflict
//
//  Created by Franklin Samboni Castillo on 23/09/22.
//

import Foundation
import CoreData

class CoreDataStore {
    static let modelName = "Chat"

    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext

    init(storeURL: URL) throws {
        container = try Self.loadContainer(storeURL: storeURL, modelName: Self.modelName)
        context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    func createNewThread(with identifier: String,
                         updatedDate: Date = Date()) throws -> ChatThread {
        var thread: ChatThread!
        var generatedError: Error?

        context.performAndWait {
            do {
                thread = ChatThread(context: context)
                thread.threadID = identifier
                thread.updatedDate = updatedDate
                try context.save()

            } catch let error {
                generatedError = error
            }
        }

        if let error = generatedError {
            throw error
        }

        return thread
    }

    func fetchThread(threadID: String) throws -> ChatThread? {
        var thread: ChatThread?
        var generatedError: Error?

        context.performAndWait {
            do {
                thread = try ChatThread.fetchThread(with: threadID, in: context)
            } catch {
                generatedError = error
            }
        }

        if let error = generatedError {
            throw error
        }
        return thread
    }

    func updateThread(thread: ChatThread,
                      unread: Bool) throws {
        var generatedError: Error?
        context.performAndWait {
            do {
                thread.updatedDate = Date()
                thread.unread = unread as NSNumber
                try context.save()
            } catch {
                generatedError = error
            }
        }

        if let error = generatedError {
            throw error
        }
    }
}

extension CoreDataStore {

    static func loadContainer(storeURL: URL, modelName: String) throws -> NSPersistentContainer {
        let modelURL = Bundle(for: Self.self).url(forResource: modelName, withExtension: "momd")!
        let model = NSManagedObjectModel(contentsOf: modelURL)!

        let description = NSPersistentStoreDescription(url: storeURL)
        let container = NSPersistentContainer(name: modelName, managedObjectModel: model)
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { (desc, err) in
            loadError = err
            if let err = err {
                print(err)            }
        }

        try loadError.map { throw $0 }

        return container
    }

}
