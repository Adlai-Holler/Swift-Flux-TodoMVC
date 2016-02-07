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
        var items: [TodoItem]
        var editingItemID: NSManagedObjectID?

        static let empty = State(items: [], editingItemID: nil)
    }

    var tableNode: ASTableNode {
        return node as! ASTableNode
    }

    private(set) var state: State = .empty
    let store: TodoStore
    let queue: dispatch_queue_t
    let deinitDisposable = CompositeDisposable()

    private let nodeCache = NSMapTable.strongToWeakObjectsMapTable()
    private var tableData: [BasicSection<ASCellNode>] = []
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
            newState.items = store.getAll()
            self.setState(newState, isInitial: true)

            self.deinitDisposable += store.changes.observeNext { [weak self] event in
                self?.handleStoreChangeWithEvent(event)
            }
        }
    }

    deinit {
        deinitDisposable.dispose()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Model Observing

    private func handleStoreChangeWithEvent(event: TodoStore.Event) {
        guard case let .Change(details) = event else { return }

        let updatedObjectIDs = Set(details.updatedObjects.map { $0.objectID })
        let deletedObjectIDs = Set(details.deletedObjects.map { $0.objectID })
        let insertedObjects = details.insertedObjects
        dispatch_sync(queue) {
            let oldState = self.state
            var newState = oldState
            newState.items = newState.items.filter { !deletedObjectIDs.contains($0.objectID!) }
            for (i, item) in newState.items.enumerate() where updatedObjectIDs.contains(item.objectID!) {
                let object = try! self.store.managedObjectContext.existingObjectWithID(item.objectID!)
                newState.items[i] = TodoItem(object: object)
            }
            newState.items += insertedObjects.flatMap { $0.entity.name == "TodoItem" ? TodoItem(object: $0) : nil }
            newState.items.sortInPlace { $0.id < $1.id }
            newState.editingItemID = self.store.editingItemID
            self.setState(newState)
        }
    }

    // MARK: UI Action Observing

    @objc private func didTapAdd() {
        TodoAction.Create("Hello!").dispatch()
    }

    // MARK: State Updating

    func renderTableData(nodeCache: NodeCache) -> [BasicSection<ASCellNode>] {
        let state = self.state
        let nodes = state.items.map { item -> TodoNode in
            let state = TodoNode.State(item: item, editingTitle: state.editingItemID == item.objectID)
            let node: TodoNode = nodeCache.nodeForKey("Todo Item Node \(item.id)", create: { key in
                TodoNode(state: state)
            })
            node.setState(state)
            return node
        }
        return [ BasicSection(name: "Single Section", items: nodes) ]
    }

    func setState(newState: State, isInitial: Bool = false) {
        dispatch_async(queue) {
            self.state = newState

            let oldData = self.tableData
            self.tableData = self.renderTableData(self.nodeCache)
            if isInitial { return }

            let diff = oldData.diffNested(self.tableData)
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

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return tableData.count
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData[section].items.count
    }

    func tableView(tableView: ASTableView, nodeForRowAtIndexPath indexPath: NSIndexPath) -> ASCellNode {
        return tableData[indexPath]!
    }

    // MARK: Table View Delegate Methods

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        guard let node = (tableView as? ASTableView)?.nodeForRowAtIndexPath(indexPath) as? TodoNode else {
            return
        }

        TodoAction.BeginEditingTitle(node.state.item.objectID!).dispatch()
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}
