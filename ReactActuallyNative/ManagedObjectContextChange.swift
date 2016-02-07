//
//  ManagedObjectContextChange.swift
//  ReactActuallyNative
//
//  Created by Adlai Holler on 2/6/16.
//  Copyright © 2016 Adlai Holler. All rights reserved.
//

import CoreData

struct ManagedObjectContextChange {
    var insertedObjects: Set<NSManagedObject>
    var updatedObjects: Set<NSManagedObject>
    var deletedObjects: Set<NSManagedObject>

    init(notification: NSNotification) {
        updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as! Set<NSManagedObject>? ?? []
        deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as! Set<NSManagedObject>? ?? []
        insertedObjects = notification.userInfo?[NSInsertedObjectsKey] as! Set<NSManagedObject>? ?? []
    }

    init() {
        insertedObjects = []
        deletedObjects = []
        updatedObjects = []
    }
}
