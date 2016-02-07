//
//  AppDelegate.swift
//  ReactActuallyNative
//
//  Created by Adlai Holler on 2/6/16.
//  Copyright © 2016 Adlai Holler. All rights reserved.
//

import UIKit
import CoreData
import ReactiveCocoa
import Result

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    /// The file URL for the sqlite database.
    private static let dataStoreURL: NSURL = {
        let documentsDirectoryURL = try! NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
        return documentsDirectoryURL.URLByAppendingPathComponent("database.sqlite")
    }()

    var window: UIWindow?
    var dataStore: CoreDataStore?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        let setupStore = SignalProducer<Void, NSError>.attempt {
            do {
                self.dataStore = try CoreDataStore(model: NSManagedObjectModel.mergedModelFromBundles(nil)!, persistentStoreURL: AppDelegate.dataStoreURL)
                return Result(value: ())
            } catch let error as NSError {
                return Result(error: error)
            }
        }
            .startOn(QueueScheduler())
        let launchTasks = SignalProducer<SignalProducer<Void, NSError>, NSError>(values: [setupStore])

        let flatLaunchTasks: SignalProducer<Void, NSError> = launchTasks.flatten(.Merge)

        // We intentionally BLOCK while the launch tasks run so that the
        // launch UI transition is clean.
        let result = flatLaunchTasks.wait()
        if let error = result.error {
            UIAlertView(title: "Error", message: "There was an error launching the app. You're screwed. Sorry. \(error.domain) \(error.code)", delegate: nil, cancelButtonTitle: "OK").show()
            return false
        }

        let todoStore = TodoStore(managedObjectContext: dataStore!.managedObjectContext)
        let todoVC = TodoViewController(store: todoStore)
        let nav = UINavigationController(rootViewController: todoVC)
        let _window = UIWindow(frame: UIScreen.mainScreen().bounds)
        _window.rootViewController = nav
        self.window = _window
        _window.makeKeyAndVisible()
        return true
    }

}

