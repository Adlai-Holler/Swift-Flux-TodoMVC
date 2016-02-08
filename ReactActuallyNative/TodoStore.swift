//
//  TodoStore.swift
//  ReactActuallyNative
//
//  Created by Adlai Holler on 2/6/16.
//  Copyright © 2016 Adlai Holler. All rights reserved.
//

import Foundation
import CoreData
import ReactiveCocoa
import enum Result.NoError

final class TodoStore {
    enum Event {
        case Change(modelChange: ManagedObjectContextChange?, errorMessage: String?)
    }

    private let changeObserver: Observer<Event, NoError>

    let changes: Signal<Event, NoError>
    let managedObjectContext: NSManagedObjectContext
    var dispatchToken: DispatchToken!
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        (changes, changeObserver) = Signal<Event, NoError>.pipe()
        dispatchToken = dispatcher.register { [weak self] action in
            self?.handleAction(action)
        }
    }

    deinit {
        dispatcher.unregister(dispatchToken)
    }

    var editingItemID: NSManagedObjectID?

    func getAll() -> [TodoItem] {
        let fr = NSFetchRequest(entityName: "TodoItem")
        fr.returnsObjectsAsFaults = false
        var result: [TodoItem]?
        managedObjectContext.performBlockAndWait {
            result = try! (self.managedObjectContext.executeFetchRequest(fr) as! [NSManagedObject]).map(TodoItem.init)
        }
        return result!.sort { abs($0.id) < abs($1.id) }
    }

    private func handleAction(action: TodoAction) {
        switch action {
        case let .BeginEditingTitle(objectID):
            self.editingItemID = objectID
            changeObserver.sendNext(.Change(modelChange: ManagedObjectContextChange(), errorMessage: nil))
        case .Create:
            managedObjectContext.performBlock {
                let temporaryID = -TodoItem.maxId
                TodoItem.incrementMaxID()
                let changeOrNil = try? self.managedObjectContext.doWriteTransaction {
                    let item = TodoItem(id: temporaryID, title: nil, completed: false)
                    let obj = NSEntityDescription.insertNewObjectForEntityForName(TodoItem.entityName, inManagedObjectContext: self.managedObjectContext)
                    item.apply(obj)
                    try self.managedObjectContext.obtainPermanentIDsForObjects([obj])
                    self.editingItemID = obj.objectID
                }
                guard let change = changeOrNil else { return }

                self.changeObserver.sendNext(.Change(modelChange: change, errorMessage: nil))
                APIService.shared
                    .create(temporaryID)
                    .start { event in
                        if let value = event.value {
                            TodoAction.APICreateSucceeded(temporaryID: temporaryID, item: value).dispatch()
                        } else if let error = event.error {
                            TodoAction.APICreateFailed(temporaryID: temporaryID, error: error).dispatch()
                        }
                }
            }
        case let .UpdateText(objectID, newTitle):
            managedObjectContext.performBlock {
                let changeOrNil = try? self.managedObjectContext.doWriteTransaction {
                    guard let object = try? self.managedObjectContext.existingObjectWithID(objectID) else { return }
                    var item = TodoItem(object: object)
                    item.title = newTitle
                    item.apply(object)
                    if objectID == self.editingItemID {
                        self.editingItemID = nil
                    }
                }
                if let change = changeOrNil {
                    self.changeObserver.sendNext(.Change(modelChange: change, errorMessage: nil))
                }
            }
        case let .Delete(objectID):
            managedObjectContext.performBlock {
                let changeOrNil = try? self.managedObjectContext.doWriteTransaction {
                    if self.editingItemID == objectID {
                        self.editingItemID = nil
                    }
                    guard let object = try? self.managedObjectContext.existingObjectWithID(objectID) else { return }

                    self.managedObjectContext.deleteObject(object)
                }
                if let change = changeOrNil {
                    self.changeObserver.sendNext(.Change(modelChange: change, errorMessage: nil))
                }
            }
        case let .SetCompleted(objectID, completed):
            managedObjectContext.performBlock {
                let changeOrNil = try? self.managedObjectContext.doWriteTransaction {
                    let object = try self.managedObjectContext.existingObjectWithID(objectID)
                    var item = TodoItem(object: object)
                    item.completed = completed
                    item.apply(object)
                }
                if let change = changeOrNil {
                    self.changeObserver.sendNext(.Change(modelChange: change, errorMessage: nil))
                }
            }
        case .DeleteAllCompleted:
            managedObjectContext.performBlock {
                let changeOrNil = try? self.managedObjectContext.doWriteTransaction {
                    for (var item) in self.getAll() where item.completed {
                        guard let object = try? self.managedObjectContext.existingObjectWithID(item.objectID!) else { continue }

                        item.softDeleted = true
                        item.apply(object)
                    }
                }
                if let change = changeOrNil {
                    self.changeObserver.sendNext(.Change(modelChange: change, errorMessage: nil))
                }
            }
        case let .APICreateSucceeded(temporaryID, newItem):
            managedObjectContext.performBlock {
                let changeOrNil = try? self.managedObjectContext.doWriteTransaction {
                    for (var item) in self.getAll() where item.id == temporaryID {
                        guard let obj = try? self.managedObjectContext.existingObjectWithID(item.objectID!) else { continue }
                        item.id = newItem.id
                        item.apply(obj)
                        return
                    }
                }
                guard let change = changeOrNil else { return }

                self.changeObserver.sendNext(.Change(modelChange: change, errorMessage: nil))
            }
        case let .APICreateFailed(temporaryID, _):
            managedObjectContext.performBlock {
                let changeOrNil = try? self.managedObjectContext.doWriteTransaction {
                    for item in self.getAll() where item.id == temporaryID {
                        guard let object = try? self.managedObjectContext.existingObjectWithID(item.objectID!) else { return }
                        self.managedObjectContext.deleteObject(object)
                        return
                    }
                }
                if let change = changeOrNil {
                    self.changeObserver.sendNext(.Change(modelChange: change, errorMessage: nil))
                }
            }
        }
    }

}

extension NSManagedObjectContext {
    /// Throws if error, returns nil if no model change is necessary, returns change if one occurred.
    func doWriteTransaction(@noescape body: () throws -> Void) throws -> ManagedObjectContextChange? {
        do {
            assert(!hasChanges, "Managed object context must be clean to do a write transaction.")
            try body()
            try obtainPermanentIDsForObjects(Array(insertedObjects))
            var change: ManagedObjectContextChange?
            if hasChanges {
                NSNotificationCenter.defaultCenter()
                    .rac_notifications(NSManagedObjectContextDidSaveNotification, object: self)
                    .take(1)
                    .startWithNext { change = ManagedObjectContextChange(notification: $0) }
                try save()
                return change!
            } else {
                return nil
            }
        } catch let e as NSError {
            NSLog("Error during write transaction: %@", e)
            rollback()
            throw e
        }
    }
}
