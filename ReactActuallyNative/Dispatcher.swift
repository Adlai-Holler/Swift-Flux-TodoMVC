//
//  Dispatcher.swift
//  ReactActuallyNative
//
//  Created by Adlai Holler on 2/6/16.
//  Copyright © 2016 Adlai Holler. All rights reserved.
//

import Foundation

typealias DispatchToken = Int

let dispatcher = Dispatcher<TodoAction>()

private final class DispatchObserver<Payload> {
    let token: DispatchToken
    var handled = false
    var pending = false
    let body: (Payload -> Void)

    init(token: DispatchToken, body: (Payload) -> Void) {
        self.token = token
        self.body = body
    }
}

final class Dispatcher<Payload> {
    private var observers: [DispatchToken: DispatchObserver<Payload>] = [:]
    private(set) var isDispatching = false
    private var maxToken = 0
    private var pendingPayload: Payload?

    let queue = dispatch_queue_create("Dispatcher.queue", DISPATCH_QUEUE_SERIAL)

    func register(callback: (Payload) -> Void) -> DispatchToken {
        var token: DispatchToken!
        dispatch_sync(queue) {
            token = self.maxToken + 1
            let observer = DispatchObserver(token: token, body: callback)
            self.observers[token] = observer
            self.maxToken = token
        }
        return token
    }

    func unregister(token: DispatchToken) {
        dispatch_async(queue) {
            let observer = self.observers.removeValueForKey(token)
            assert(observer != nil, "Dispatcher.unregister(...): `\(token)` does not map to a registered callback.")
        }
    }

    func dispatch(payload: Payload) {
        dispatch_async(queue) {
            self.startDispatching(payload)
            for observer in self.observers.values where !observer.pending {
                observer.body(payload)
            }
            self.stopDispatching()
        }
    }

    func waitFor(tokens: [DispatchToken]) {
        assert(isDispatching, "Dispatcher.waitFor(...): Must be invoked while dispatching.")
        for token in tokens {
            guard let observer = observers[token] else {
                assertionFailure("Dispatcher.waitFor(...): `\(token)` does not map to a registered callback.")
                continue
            }

            if observer.pending {
                assert(observer.handled, "Dispatcher.waitFor(...): Circular dependency detected while waiting for `\(token)`.")
                continue
            }

            invokeCallback(observer)
        }
    }

    private func invokeCallback(observer: DispatchObserver<Payload>) {
        guard let payload = pendingPayload else {
            assertionFailure()
            return
        }

        observer.pending = true
        observer.body(payload)
        observer.handled = true
    }

    private func startDispatching(payload: Payload) {
        for observer in observers.values {
            observer.pending = false
            observer.handled = false
        }
        pendingPayload = payload
        isDispatching = true
    }

    private func stopDispatching() {
        pendingPayload = nil
        isDispatching = false
    }
}
