//
//  MergeConflictTests.swift
//  MergeConflictTests
//
//  Created by Franklin Samboni Castillo on 23/09/22.
//

import XCTest
@testable import MergeConflict

class MergeConflictTests: XCTestCase {

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: storeURL())
        super.tearDown()
    }
    
    func test_thatThereIsNotAMergeConflictAndLoseData_WhenSomeProcessKeepsCoreDataObjectsInMemoryToUseLater() {
        do {
            let storeURL = try storeURL()
            let appStore = try CoreDataStore(storeURL: storeURL)
            let extStore = try CoreDataStore(storeURL: storeURL)
            
            let threadID = "a threadID"
            let _ = try appStore.createNewThread(with: threadID) // Fill cache
            
            // App fetch an object and keep in memory
            let inMemoryThread = try appStore.fetchThread(threadID: threadID)
            
            let extHandler = MessageHandler(store: extStore)
            try extHandler.handleNewMessage(threadID: threadID, "Any message")
            try extHandler.userReadChat(threadID: threadID)
            
            if let inMemoryThread = inMemoryThread {
                try appStore.updateThread(thread: inMemoryThread, unread: true)
            }
            
            let thread = try extStore.fetchThread(threadID: threadID)
            XCTAssertEqual(thread?.unread, true, "Thread should be unread")
        } catch {
            XCTFail("\(error.localizedDescription) \((error as NSError).userInfo)")
        }
    }

    func test_thatThereIsNotAMergeConflict_whenTwoProcessTryToSaveAsyncrounsAtAlmostTheSameTime() {
        do {
            let storeURL = try storeURL()
            let appStore = try CoreDataStore(storeURL: storeURL)
            let extStore = try CoreDataStore(storeURL: storeURL)

            let handlerApp = MessageHandler(store: appStore)
            let handlerExt = MessageHandler(store: extStore)

            let threadID = "a threadID"
            let _ = try appStore.createNewThread(with: threadID) // Fill cache

            let appQueue = DispatchQueue(label: "MainApp")
            let extQueue = DispatchQueue(label: "Extension")
            
            let exp = expectation(description: "wait for queues")
            exp.expectedFulfillmentCount = 2
            appQueue.async {
                do {
                    try handlerApp.handleNewMessage(threadID: threadID, "Any message")
                } catch {
                    XCTFail("\(error.localizedDescription) \((error as NSError).userInfo)")
                }
                exp.fulfill()
            }
            
            extQueue.async {
                do {
                    try handlerExt.handleNewMessage(threadID: threadID, "Any message")
                } catch {
                    XCTFail("\(error.localizedDescription) \((error as NSError).userInfo)")
                }
                exp.fulfill()
            }
            wait(for: [exp], timeout: 1)

            let thread = try extStore.fetchThread(threadID: threadID)
            XCTAssertEqual(thread?.unread, true)
        } catch {
            XCTFail("\(error.localizedDescription) \((error as NSError).userInfo)")
        }
    }

    func test_thatThereIsNotMergeConflict_WhenProcessesSaveChangesSequentiallyf() {
        do {
            let storeURL = try storeURL()
            let appStore = try CoreDataStore(storeURL: storeURL)
            let extStore = try CoreDataStore(storeURL: storeURL)
            
            let appHandler = MessageHandler(store: appStore)
            let extHandler = MessageHandler(store: extStore)
            
            let threadID = "a threadID"
            let _ = try appStore.createNewThread(with: threadID) // Fill cache
            
            try extHandler.handleNewMessage(threadID: threadID, "Any message")
            
            try appHandler.userReadChat(threadID: threadID)
            try appHandler.handleNewMessage(threadID: threadID, "Any message")
            try appHandler.userReadChat(threadID: threadID)
            
            try extHandler.handleNewMessage(threadID: threadID, "Any message")
            
            let thread = try extStore.fetchThread(threadID: threadID)
            XCTAssertEqual(thread?.unread, true, "Thread should be unread")
        } catch {
            XCTFail("\(error.localizedDescription) \((error as NSError).userInfo)")
        }
    }
    
    // MARK: HELPERS
    private func storeURL() throws -> URL {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return url.appendingPathComponent("db.sqlite")
        } else {
            throw NSError(domain: "Error loading URL", code: 0)
        }
    }
}

