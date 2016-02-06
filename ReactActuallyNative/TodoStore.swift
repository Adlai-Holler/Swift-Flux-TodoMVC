//
//  TodoStore.swift
//  ReactActuallyNative
//
//  Created by Adlai Holler on 2/6/16.
//  Copyright © 2016 Adlai Holler. All rights reserved.
//

import Foundation
import CoreData

final class TodoStore {
    let managedObjectContext: NSManagedObjectContext
    var dispatchToken: DispatchToken!
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        dispatchToken = dispatcher.register { [weak self] action in
            self?.handleAction(action)
        }
    }

    func getAll() -> [TodoItem] {
        let fr = NSFetchRequest(entityName: "TodoItem")
        fr.sortDescriptors = [
            NSSortDescriptor(key: TodoItem.Property.id.rawValue, ascending: true)
        ]
        fr.returnsObjectsAsFaults = false
        var result: [TodoItem]?
        managedObjectContext.performBlockAndWait {
            result = try! (self.managedObjectContext.executeFetchRequest(fr) as! [NSManagedObject]).map(TodoItem.init)
        }
        return result!
    }

    private func handleAction(action: TodoAction) {
        switch action {
        case let .Create(title):
            managedObjectContext.performBlock {
                _ = try? self.managedObjectContext.doWriteTransaction {
                    let item = TodoItem(id: TodoItem.maxId, title: title, completed: false)
                    let obj = NSEntityDescription.insertNewObjectForEntityForName(TodoItem.entityName, inManagedObjectContext: self.managedObjectContext)
                    item.apply(obj)
                }
            }
        case let .UpdateText(objectID, newTitle):
            managedObjectContext.performBlock {
                _ = try? self.managedObjectContext.doWriteTransaction {
                    let object = try self.managedObjectContext.existingObjectWithID(objectID)
                    var item = TodoItem(object: object)
                    item.title = newTitle
                    item.apply(object)
                }
            }
        }
    }

}

extension NSManagedObjectContext {
    func doWriteTransaction(@noescape body: () throws -> Void) throws {
        do {
            assert(!self.hasChanges, "Managed object context must be clean to do a write transaction.")
            try body()
            try obtainPermanentIDsForObjects(Array(insertedObjects))
            try save()
        } catch let e {
            rollback()
            throw e
        }
    }
}
