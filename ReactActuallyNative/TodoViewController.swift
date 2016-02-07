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
    private var hasTableDataBeenQueried = false
    private let tableDataLock = NSLock()
    init(store: TodoStore) {
        self.store = store
        queue = dispatch_queue_create("TodoViewController Queue", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0))
        super.init(node: ASTableNode(style: .Plain))
        title = "Todo MVC"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "didTapAdd")
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Trash, target: self, action: "didTapClear")
        tableNode.dataSource = self
        tableNode.delegate = self

        /// Async onto our queue so we can wait for this to finish
        /// before our first layout if needed.
        dispatch_async(queue) {
            self.deinitDisposable += store.changes.observeNext { [weak self] event in
                self?.handleStoreChangeWithEvent(event)
            }

            var newState = self.state
            newState.items = store.getAll()
            self.setState(newState)
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
        guard case .Change = event else { return }

        dispatch_async(queue) {
            var newState = self.state
            newState.items = self.store.getAll()
            newState.editingItemID = self.store.editingItemID
            self.setState(newState)
        }
    }

    // MARK: UI Action Observing

    @objc private func didTapAdd() {
        TodoAction.Create("Hello!").dispatch()
    }

    @objc private func didTapClear() {
        TodoAction.DeleteAllCompleted.dispatch()
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

    private func setState(newState: State) {
        state = newState

        tableDataLock.lock()
        let oldData = tableData
        tableDataLock.unlock()
        let newData = renderTableData(nodeCache)

        let diff = oldData.diffNested(newData)
        if diff.isEmpty { return }

        tableDataLock.lock()
        if !hasTableDataBeenQueried {
            self.tableData = newData
            tableDataLock.unlock()
            return
        }
        tableDataLock.unlock()

        dispatch_async(dispatch_get_main_queue()) {
            let tableView = self.tableNode.view
            tableView.beginUpdates()
            self.tableDataLock.lock()
            self.tableData = newData
            self.tableDataLock.unlock()
            diff.applyToTableView(tableView, rowAnimation: .Automatic)
            tableView.endUpdates()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableNode.view.tableFooterView = UIView()
    }

    override func viewWillLayoutSubviews() {
        dispatch_sync(queue, {})
        super.viewWillLayoutSubviews()
    }

    // MARK: Table View Data Source Methods

    func tableViewLockDataSource(tableView: ASTableView) {
        tableDataLock.lock()
        hasTableDataBeenQueried = true
    }

    func tableViewUnlockDataSource(tableView: ASTableView) {
        tableDataLock.unlock()
    }

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

    func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        guard let node = (tableView as? ASTableView)?.nodeForRowAtIndexPath(indexPath) as? TodoNode else {
            return .None
        }

        if node.state.editingTitle {
            return .None
        } else {
            return .Delete
        }
    }

    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        guard let node = (tableView as? ASTableView)?.nodeForRowAtIndexPath(indexPath) as? TodoNode else {
            return
        }
        TodoAction.Delete(node.state.item.objectID!).dispatch()
    }
}
