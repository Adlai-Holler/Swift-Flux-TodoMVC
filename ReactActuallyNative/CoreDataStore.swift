//
//  CoreDataStore.swift
//  ReactActuallyNative
//
//  Created by Adlai Holler on 2/6/16.
//  Copyright © 2016 Adlai Holler. All rights reserved.
//

import CoreData

final class CoreDataStore {
    let managedObjectContext: NSManagedObjectContext
    let persistentStoreCoordinator: NSPersistentStoreCoordinator

    init(model: NSManagedObjectModel, persistentStoreURL: NSURL) throws {
        persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        managedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        try persistentStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: persistentStoreURL, options: nil)
        managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
    }
}