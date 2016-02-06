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
        flatLaunchTasks
            .observeOn(QueueScheduler.mainQueueScheduler)
            .start(handlePostLaunchTasksEvent)

        return true
    }

    /// This is called on main queue after all post-launch tasks are finished.
    private func handlePostLaunchTasksEvent(event: Event<Void, NSError>) {
        if let error = event.error {
            UIAlertView(title: "Error", message: "There was an error launching the app. You're screwed. Sorry. \(error.domain) \(error.code)", delegate: nil, cancelButtonTitle: "OK").show()
            return
        }
        guard case .Completed = event else { return }

        let todoStore = TodoStore(managedObjectContext: dataStore!.managedObjectContext)
        let todoVC = TodoViewController(store: todoStore)
        let nav = UINavigationController(rootViewController: todoVC)
        let _window = UIWindow(frame: UIScreen.mainScreen().bounds)
        _window.rootViewController = nav
        self.window = _window
        _window.makeKeyAndVisible()
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

