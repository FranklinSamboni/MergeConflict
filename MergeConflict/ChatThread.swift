//
//  ChatThread.swift
//  MergeConflict
//
//  Created by Franklin Samboni Castillo on 23/09/22.
//

import Foundation
import CoreData

@objc(ChatThread)
public class ChatThread: NSManagedObject {
    @NSManaged public var threadID: String?
    @NSManaged public var unread: NSNumber?
    @NSManaged public var updatedDate: Date?
}

extension ChatThread {
    static func fetchThread(with threadID: String, in context: NSManagedObjectContext) throws -> ChatThread? {
        let entityName = entity().name!
        let request = NSFetchRequest<ChatThread>(entityName: entityName)
        request.predicate = NSPredicate(format: "threadID = %@", argumentArray: [threadID])

        let results = try context.fetch(request)
        return results.first
    }
}
