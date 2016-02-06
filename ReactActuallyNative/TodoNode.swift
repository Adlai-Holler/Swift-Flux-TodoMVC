//
//  TodoNode.swift
//  ReactActuallyNative
//
//  Created by Adlai Holler on 2/6/16.
//  Copyright © 2016 Adlai Holler. All rights reserved.
//

import UIKit
import AsyncDisplayKit
import ReactiveCocoa
import Result

final class TodoNode: ASCellNode {
    let textNode = ASTextNode()
    let item: AnyProperty<TodoItem>
    private let deinitDisposable = CompositeDisposable()

    init(item: AnyProperty<TodoItem>) {
        self.item = item
        super.init()
        textNode.layerBacked = true
        textNode.opaque = true
        textNode.backgroundColor = UIColor.whiteColor()
        addSubnode(textNode)

        deinitDisposable += item.producer.startWithNext { [weak self] in self?.itemDidChange($0) }
    }

    deinit {
        deinitDisposable.dispose()
    }

    private func itemDidChange(item: TodoItem) {
        let newTitle = NSAttributedString(string: item.title ?? "(Untitled)")
        if newTitle != textNode.attributedString {
            textNode.attributedString = newTitle
            dispatch_async(dispatch_get_main_queue()) {
                self.setNeedsLayout()
            }
        }
    }

    override func layoutSpecThatFits(constrainedSize: ASSizeRange) -> ASLayoutSpec {
        return ASInsetLayoutSpec(insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16), child: textNode)
    }
}
