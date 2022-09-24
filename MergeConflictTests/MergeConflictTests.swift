//
//  MergeConflictTests.swift
//  MergeConflictTests
//
//  Created by Franklin Samboni Castillo on 23/09/22.
//

import XCTest
@testable import MergeConflict

class MergeConflictTests: XCTestCase {

    let storeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("db.sqlite")

    override func tearDown() {
        try! FileManager.default.removeItem(at: storeURL)
        super.tearDown()
    }

    func test_thatThereIsNotAMergeConflict_whenTwoProcessTryToSaveAsyncrounsAtAlmostTheSameTime() throws {
        let appStore = try CoreDataStore(storeURL: storeURL)
        let extStore = try CoreDataStore(storeURL: storeURL)

        let appQueue = DispatchQueue(label: "MainApp")
        let extQueue = DispatchQueue(label: "Extension")

        let handlerApp = MessageHandler(store: appStore)
        let handlerExt = MessageHandler(store: extStore)

        let threadID = "a threadID"
        let _ = try appStore.createNewThread(with: threadID) // Fill cache

        let exp = expectation(description: "wait for queues")
        exp.expectedFulfillmentCount = 2
        appQueue.async {
            do {
                try handlerApp.handleNewMessage(threadID: threadID, "Any message")
                exp.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        extQueue.async {
            do {
                try handlerExt.handleNewMessage(threadID: threadID, "Any message")
                exp.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        wait(for: [exp], timeout: 1)

        let thread = try extStore.fetchThread(threadID: threadID)
        XCTAssertEqual(thread?.unread, true)
    }

    // This test is flaky, sometimes passes some times fails
    func test_thatThereIsNotMergeConflict_WhenProcessesSaveChangesAtDifferentTimes() throws {
        let appStore = try CoreDataStore(storeURL: storeURL)
        let extStore = try CoreDataStore(storeURL: storeURL)

        let appQueue = DispatchQueue(label: "MainApp")
        let extQueue = DispatchQueue(label: "Extension")

        let appHandler = MessageHandler(store: appStore)
        let extHandler = MessageHandler(store: extStore)

        let threadID = "a threadID"
        let _ = try appStore.createNewThread(with: threadID) // Fill cache

        extQueue.sync {
            do {
                try extHandler.handleNewMessage(threadID: threadID, "Any message")
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        appQueue.sync {
            do {
                try appHandler.userReadChat(threadID: threadID)
                try appHandler.handleNewMessage(threadID: threadID, "Any message")
                try appHandler.userReadChat(threadID: threadID)
            } catch let error {
                XCTFail(error.localizedDescription)
            }
        }

        extQueue.sync {
            do {
                try extHandler.handleNewMessage(threadID: threadID, "Any message")
            } catch let error {
                XCTFail(error.localizedDescription)
            }
        }

        let thread = try extStore.fetchThread(threadID: threadID)
        XCTAssertEqual(thread?.unread, true, "Thread should be unread")
    }

    func test_thatThereIsNotAMergeConflictAndLoseData_WhenSomeProcessKeepsCoreDataObjectsInMemory() throws {
        let appStore = try CoreDataStore(storeURL: storeURL)
        let extStore = try CoreDataStore(storeURL: storeURL)

        let appQueue = DispatchQueue(label: "MainApp")
        let extQueue = DispatchQueue(label: "Extension")

        let threadID = "a threadID"
        let _ = try appStore.createNewThread(with: threadID) // Fill cache

        var updateObjectLater: (() throws -> Void)!

        // App fetch an object and keep in memory
        appQueue.sync {
            do {
                if let thread = try appStore.fetchThread(threadID: threadID) {
                    updateObjectLater = {
                        try appStore.updateThread(thread: thread, unread: true)
                    }
                }
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        // Extension save new changes
        extQueue.sync {
            do {
                let extHandler = MessageHandler(store: extStore)
                try extHandler.handleNewMessage(threadID: threadID, "Any message")

                try extHandler.userReadChat(threadID: threadID)

            } catch let error {
                XCTFail(error.localizedDescription)
            }
        }

        // App save changes
        appQueue.sync {
            do {
                try updateObjectLater()
            } catch let error {
                XCTFail(error.localizedDescription)
            }
        }

        let thread = try extStore.fetchThread(threadID: threadID)
        XCTAssertEqual(thread?.unread, true, "Thread should be unread")
    }
}

