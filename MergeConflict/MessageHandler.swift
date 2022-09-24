//
//  MessageHandler.swift
//  MergeConflict
//
//  Created by Franklin Samboni Castillo on 23/09/22.
//

import Foundation

class MessageHandler {

    let store: CoreDataStore
    init(store: CoreDataStore) {
        self.store = store
    }

    func handleNewMessage(threadID: String, _ message: String) throws {
        var thread = try store.fetchThread(threadID: threadID)
        if thread == nil {
            thread = try store.createNewThread(with: threadID)
        }
        //.... Do some other stuffs, like insert the new message.

        // Since there is a new message, mark thread as unread
        if let thread = thread {
            try store.updateThread(thread: thread, unread: true)
        }
        
        // Create notification
        //...
    }

    func userReadChat(threadID: String) throws {
        if let thread = try store.fetchThread(threadID: threadID) {
            try store.updateThread(thread: thread, unread: false)
        }
    }
}
