//
//  BackendStore.swift
//  ReactActuallyNative
//
//  Created by Adlai Holler on 2/7/16.
//  Copyright © 2016 Adlai Holler. All rights reserved.
//

import Foundation

/// A simulation of the database on the server.
/// This must only be accessed by `APIService.swift`.
final class BackendStore {
    static let shared = BackendStore()
    
    var todos: [TodoItem] = []
}
