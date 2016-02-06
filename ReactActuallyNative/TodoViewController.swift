//
//  ViewController.swift
//  ReactActuallyNative
//
//  Created by Adlai Holler on 2/6/16.
//  Copyright © 2016 Adlai Holler. All rights reserved.
//

import UIKit
import CoreData
import AsyncDisplayKit
import ReactiveCocoa
import ArrayDiff

final class TodoViewController: ASViewController, ASTableDelegate, ASTableDataSource {

    struct State {
        var items: [MutableProperty<TodoItem>]

        static let empty = State(items: [])
    }

    var tableNode: ASTableNode {
        return node as! ASTableNode
    }

    private(set) var state: State = .empty
    let store: TodoStore
    let queue: dispatch_queue_t
    let deinitDisposable = CompositeDisposable()

    init(store: TodoStore) {
        self.store = store
        queue = dispatch_queue_create("TodoViewController Queue", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0))
        super.init(node: ASTableNode(style: .Plain))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "didTapAdd")
        tableNode.dataSource = self
        tableNode.delegate = self

        /// Async onto our queue so we can wait for this to finish
        /// before our first layout if needed.
        dispatch_async(queue) {
            var newState = self.state
            newState.items = store.getAll().map(MutableProperty.init)
            self.setState(newState, isInitial: true)

            self.deinitDisposable += NSNotificationCenter.defaultCenter()
                .rac_notifications(NSManagedObjectContextDidSaveNotification, object: store.managedObjectContext)
                .startWithNext { [weak self] in self?.handleContextDidSaveWithNotification($0) }
        }
    }

    deinit {
        deinitDisposable.dispose()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Model Observing

    private func handleContextDidSaveWithNotification(notification: NSNotification) {

        let updatedObjectIDs = (notification.userInfo?[NSUpdatedObjectsKey] as! NSSet?)?.valueForKey("objectID") as! Set<NSManagedObjectID>? ?? []
        let deletedObjectIDs = (notification.userInfo?[NSDeletedObjectsKey] as! NSSet?)?.valueForKey("objectID") as! Set<NSManagedObjectID>? ?? []
        let insertedObjects = notification.userInfo?[NSInsertedObjectsKey] as! Set<NSManagedObject>? ?? []
        dispatch_sync(queue) {
            let oldState = self.state
            var newState = oldState
            newState.items = newState.items.filter { !deletedObjectIDs.contains($0.value.objectID!) }
            for itemProperty in newState.items where updatedObjectIDs.contains(itemProperty.value.objectID!) {
                let object = try! self.store.managedObjectContext.existingObjectWithID(itemProperty.value.objectID!)
                /// Send new value into existing node.
                itemProperty.value = TodoItem(object: object)
            }
            newState.items += insertedObjects.flatMap { $0.entity.name == "TodoItem" ? MutableProperty(TodoItem(object: $0)) : nil }
            newState.items.sortInPlace { $0.value.id < $1.value.id }
            self.setState(newState)
        }
    }

    // MARK: UI Action Observing

    @objc private func didTapAdd() {
        TodoAction.Create("Hello!").dispatch()
    }

    // MARK: State Updating

    func setState(newState: State, isInitial: Bool = false) {
        dispatch_async(queue) {
            let oldState = self.state
            self.state = newState
            if isInitial { return }

            let oldItemIDs = oldState.items.map { $0.value.id }
            let newItemIDs = newState.items.map { $0.value.id }
            let diff = [
                    BasicSection(name: "Single Section", items: oldItemIDs)
                ].diffNested([
                    BasicSection(name: "Single Section", items: newItemIDs)
                ])
            guard !diff.isEmpty else { return }

            dispatch_async(dispatch_get_main_queue()) {
                let tableView = self.tableNode.view
                tableView.beginUpdates()
                diff.applyToTableView(tableView, rowAnimation: .Automatic)
                tableView.endUpdates()
            }
        }
    }

    override func viewWillLayoutSubviews() {
        dispatch_sync(queue, {})
        super.viewWillLayoutSubviews()
    }

    // MARK: Table View Data Source Methods

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return state.items.count
    }

    func tableView(tableView: ASTableView, nodeForRowAtIndexPath indexPath: NSIndexPath) -> ASCellNode {
        let item = state.items[indexPath.row]
        return TodoNode(item: AnyProperty(item))
    }

    // MARK: Table View Delegate Methods

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        guard let node = (tableView as? ASTableView)?.nodeForRowAtIndexPath(indexPath) as? TodoNode else {
            return
        }

        let todoItem = node.item.value
        TodoAction
            .UpdateText(todoItem.objectID!, "\(todoItem.title!)\(todoItem.title!)")
            .dispatch()
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}
