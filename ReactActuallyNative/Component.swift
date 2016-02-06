//
//  Component.swift
//  ReactActuallyNative
//
//  Created by Adlai Holler on 2/6/16.
//  Copyright © 2016 Adlai Holler. All rights reserved.
//

import UIKit
import AsyncDisplayKit

protocol Component {
    typealias State

    var state: State { get }
    func render() -> ASDisplayNode
}
