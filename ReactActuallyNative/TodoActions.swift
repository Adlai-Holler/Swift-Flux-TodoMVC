//
//  Actions.swift
//  ReactActuallyNative
//
//  Created by Adlai Holler on 2/6/16.
//  Copyright © 2016 Adlai Holler. All rights reserved.
//

import Foundation
import CoreData

enum TodoAction {
    case Create(String)
    case BeginEditingTitle(NSManagedObjectID)
    case UpdateText(NSManagedObjectID, String)

    func dispatch() {
        dispatcher.dispatch(self)
    }
}