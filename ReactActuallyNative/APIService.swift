//
//  Backend.swift
//  ReactActuallyNative
//
//  Created by Adlai Holler on 2/7/16.
//  Copyright © 2016 Adlai Holler. All rights reserved.
//

import ReactiveCocoa
import Result

final class APIService {

    enum Error: ErrorType {
        case Any
    }

    static let shared = APIService()

    var errorProbabilityPercent: UInt32 = 40
    var delay: NSTimeInterval = 2.0
    private let queue = ProducerQueue(name: "Backend.queue")
    private let callbackScheduler = QueueScheduler(qos: QOS_CLASS_DEFAULT, name: "Backend Callback")
    private let networkActivityCount = Atomic(0)

    func getAllTodos() -> SignalProducer<[TodoItem], Error> {
        return backendCallWithSuccess {
            BackendStore.shared.todos
        }
    }

    func create(temporaryID: TodoItemID) -> SignalProducer<TodoItem, Error> {
        assert(temporaryID < 0, "Temporary TodoItemIDs are expected to be negative.")
        return backendCallWithSuccess {
            let new = TodoItem(id: -temporaryID, title: nil, completed: false)
            BackendStore.shared.todos.append(new)
            return new
        }
    }

    func markCompleted(itemID: TodoItemID) -> SignalProducer<Void, Error> {
        return backendCallWithSuccess {
            for (i, todo) in BackendStore.shared.todos.enumerate() where todo.id == itemID {
                BackendStore.shared.todos[i].completed = true
            }
        }
    }

    func delete(itemID: TodoItemID) -> SignalProducer<Void, Error> {
        return backendCallWithSuccess {
            for (i, todo) in BackendStore.shared.todos.enumerate() where todo.id == itemID {
                BackendStore.shared.todos.removeAtIndex(i)
                break
            }
        }
    }

    func deleteCompleted() -> SignalProducer<Void, Error> {
        return backendCallWithSuccess {
            for (i, todo) in BackendStore.shared.todos.enumerate().reverse() where todo.completed {
                BackendStore.shared.todos.removeAtIndex(i)
            }
        }
    }

    func updateTitle(itemID: TodoItemID, newTitle: String) -> SignalProducer<TodoItem?, Error> {
        return backendCallWithSuccess {
            for (i, todo) in BackendStore.shared.todos.enumerate().reverse() where todo.id == itemID {
                BackendStore.shared.todos[i].title = newTitle
                let todo = BackendStore.shared.todos[i]
                return todo
            }
            return nil
        }
    }

    private func backendCallWithSuccess<Value>(body: () -> Value) -> SignalProducer<Value, Error> {
        let error = shouldError()
        let finishDate = NSDate(timeIntervalSinceNow: delay)
        return SignalProducer { observer, disposable in
                disposable += self.callbackScheduler.scheduleAfter(finishDate) {
                    if error {
                        observer.sendFailed(.Any)
                    } else {
                        observer.sendNext(body())
                        observer.sendCompleted()
                    }
                }
            }
            .startOnQueue(queue)
            .on(started: {
                    if self.networkActivityCount.modify ({ $0 + 1 }) == 0 {
                        dispatch_async(dispatch_get_main_queue()) {
                            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
                        }
                    }
                }, terminated: {
                    if self.networkActivityCount.modify ({ $0 - 1 }) == 1 {
                        dispatch_async(dispatch_get_main_queue()) {
                            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                        }
                    }
            })
    }

    private func shouldError() -> Bool {
        return arc4random_uniform(100) < errorProbabilityPercent
    }
}
