//
//  TodoItem.swift
//  ReactActuallyNative
//
//  Created by Adlai Holler on 2/6/16.
//  Copyright © 2016 Adlai Holler. All rights reserved.
//

import CoreData

typealias TodoItemID = Int64

struct TodoItem {

    static let entityName = "TodoItem"

    enum Property: String {
        case title
        case id
        case completed
        case softDeleted
    }

    var id: TodoItemID
    /// This is nil if the object was not created from an NSManagedObject.
    let objectID: NSManagedObjectID?
    var title: String?
    var completed: Bool
    var softDeleted: Bool

    init(id: TodoItemID, title: String?, completed: Bool) {
        self.id = id
        self.objectID = nil
        self.title = title
        self.completed = completed
        self.softDeleted = false
    }

    init(object: NSManagedObject) {
        assert(object.entity.name == TodoItem.entityName)
        title = object.valueForKey(Property.title.rawValue) as! String?
        completed = object.valueForKey(Property.completed.rawValue) as! Bool
        id = (object.valueForKey(Property.id.rawValue) as! NSNumber).longLongValue
        softDeleted = object.valueForKey(Property.softDeleted.rawValue) as! Bool
        objectID = object.objectID
    }

    func apply(object: NSManagedObject) {
        guard object.entity.name == TodoItem.entityName else {
            assertionFailure()
            return
        }
        let idObj = NSNumber(longLong: id)
        if object.valueForKey(Property.id.rawValue) as! NSNumber? != idObj {
            object.setValue(idObj, forKey: Property.id.rawValue)
        }
        if object.valueForKey(Property.title.rawValue) as! String? != title {
            object.setValue(title, forKey: Property.title.rawValue)
        }
        if object.valueForKey(Property.completed.rawValue) as! Bool != completed {
            object.setValue(completed, forKey: Property.completed.rawValue)
        }
        if object.valueForKey(Property.softDeleted.rawValue) as! Bool != completed {
            object.setValue(completed, forKey: Property.softDeleted.rawValue)
        }
    }
}

extension TodoItem {
    static var maxId: TodoItemID {
        let storedValue = TodoItemID(NSUserDefaults.standardUserDefaults().integerForKey("TodoItemMaxID"))
        return storedValue == 0 ? 1 : storedValue
    }

    static func incrementMaxID() {
        let newValue = maxId + 1
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setInteger(Int(newValue), forKey: "TodoItemMaxID")
        defaults.synchronize()
    }
}