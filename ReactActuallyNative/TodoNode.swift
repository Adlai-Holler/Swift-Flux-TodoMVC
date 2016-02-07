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

final class TodoNode: ASCellNode, ASEditableTextNodeDelegate {
    struct State {
        var item: TodoItem
        var editingTitle: Bool
    }
    let textNode = ASTextNode()
    lazy var editableTextNode = ASEditableTextNode()
    private let lock = NSLock()
    private var _state: State
    var state: State {
        lock.lock()
        defer { lock.unlock() }
        return _state
    }

    init(state: State) {
        _state = state
        super.init()
        textNode.layerBacked = true
        textNode.opaque = true
        textNode.backgroundColor = UIColor.whiteColor()
        addSubnode(textNode)
        setState(state)
    }

    func setState(state: State) {
        lock.lock()
        self._state = state
        lock.unlock()

        let newTitle = NSAttributedString(string: state.item.title ?? "(Untitled)")
        if newTitle != textNode.attributedString {
            textNode.attributedString = newTitle
        }
        dispatch_async(dispatch_get_main_queue()) {
            self.didSetState_mainThread(state)
        }
    }

    private func didSetState_mainThread(state: State) {
        if state.editingTitle && textNode.supernode != nil {
            textNode.removeFromSupernode()
            editableTextNode.attributedText = textNode.attributedString
            addSubnode(editableTextNode)
            editableTextNode.becomeFirstResponder()
            editableTextNode.selectedRange = NSMakeRange(editableTextNode.attributedText!.length, 0)
            editableTextNode.delegate = self
        } else if !state.editingTitle && textNode.supernode == nil {
            editableTextNode.removeFromSupernode()
            addSubnode(textNode)
        }
        setNeedsLayout()
        recursivelyEnsureDisplaySynchronously(true)
    }

    override func layoutSpecThatFits(constrainedSize: ASSizeRange) -> ASLayoutSpec {
        return ASInsetLayoutSpec(insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16), child: subnodes.first!)
    }

    // MARK: Editable Text Node

    /// If they hit newline, reject the edit and end editing.
    func editableTextNode(editableTextNode: ASEditableTextNode, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool {
        if text.rangeOfString("\n") != nil {
            editableTextNode.resignFirstResponder()
            return false
        }
        return true
    }

    func editableTextNodeDidFinishEditing(editableTextNode: ASEditableTextNode) {
        TodoAction.UpdateText(state.item.objectID!, editableTextNode.attributedText?.string ?? "").dispatch()
    }

}
