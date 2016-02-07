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
import pop

final class TodoNode: ASCellNode, ASEditableTextNodeDelegate {
    struct State {
        var item: TodoItem
        var editingTitle: Bool
    }
    private let textNode = ASTextNode()
    private let completeBtnNode = ASButtonNode()
    private let editableTextNode = ASEditableTextNode()

    private let lock = NSLock()
    private var _state: State
    var state: State {
        lock.lock()
        defer { lock.unlock() }
        return _state
    }

    struct Style {
        static let titleAttributes = [
            NSFontAttributeName: UIFont.systemFontOfSize(18, weight: UIFontWeightLight)
        ]
    }

    init(state: State) {
        _state = state
        super.init()
        textNode.layerBacked = true
        addSubnode(textNode)
        addSubnode(completeBtnNode)
        completeBtnNode.setImage(UIImage(named: "selection-on"), forState: .Selected)
        completeBtnNode.setImage(UIImage(named: "selection-off"), forState: .Normal)
        completeBtnNode.hitTestSlop = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)

        completeBtnNode.backgroundColor = UIColor.whiteColor()
        completeBtnNode.addTarget(self, action: "didTapCheckImage", forControlEvents: .TouchUpInside)
        setState(state)
        editableTextNode.returnKeyType = .Done
    }

    // MARK: Action Handling

    @objc private func didTapCheckImage() {
        let item = state.item
        TodoAction.SetCompleted(item.objectID!, !item.completed).dispatch()
    }

    // MARK: State Updating

    func setState(state: State) {
        lock.lock()
        _state = state
        lock.unlock()

        var needsLayout = false
        /// We use a gross hack where we show a " " instead of empty string so that
        /// the node's size will be right. This means your to-dos probably have
        /// a trailing space after them.
        var displayTitle = state.item.title ?? ""
        if displayTitle.isEmpty {
            displayTitle = " "
        }
        let newTitle = NSAttributedString(string: displayTitle, attributes: Style.titleAttributes)
        if newTitle != textNode.attributedString {
            textNode.attributedString = newTitle
            needsLayout = true
        }

        dispatch_async(dispatch_get_main_queue()) {
            self.didSetState_mainThread(state, needsLayout: needsLayout)
        }
    }

    private func didSetState_mainThread(state: State, var needsLayout: Bool) {
        let visible = interfaceState.contains(.Visible)
        let shouldAnimate = visible
            && state.item.completed
            && completeBtnNode.selected == false
        completeBtnNode.selected = state.item.completed

        if shouldAnimate {
            let animation = POPBasicAnimation(propertyNamed: kPOPLayerScaleXY)
            animation.duration = 0.1
            animation.toValue = NSValue(CGPoint: CGPoint(x: 1.1, y: 1.1))
            completeBtnNode.layer.pop_addAnimation(animation, forKey: "completeAnimation1")
            animation.completionBlock = { _ in
                let secondAnimation = POPSpringAnimation(propertyNamed: kPOPLayerScaleXY)
                secondAnimation.springBounciness = 10
                secondAnimation.toValue = NSValue(CGPoint: CGPoint(x: 1, y: 1))
                self.completeBtnNode.layer.pop_addAnimation(secondAnimation, forKey: "completeAnimation2")
            }
        }

        if state.editingTitle && editableTextNode.supernode == nil {
            textNode.removeFromSupernode()
            editableTextNode.attributedText = textNode.attributedString
            editableTextNode.typingAttributes = Style.titleAttributes
            insertSubnode(editableTextNode, atIndex: 0)
            if interfaceState.contains(.InHierarchy) {
                editableTextNode.becomeFirstResponder()
            }
            editableTextNode.selectedRange = NSMakeRange(editableTextNode.attributedText?.length ?? 0, 0)
            editableTextNode.delegate = self
            editableTextNode.flexBasis = ASRelativeDimensionMakeWithPoints(1)
            editableTextNode.flexGrow = true
            needsLayout = true
        } else if !state.editingTitle && textNode.supernode == nil {
            editableTextNode.removeFromSupernode()
            insertSubnode(textNode, atIndex: 0)
            needsLayout = true
        }
        if needsLayout {
            setNeedsLayout()
        }
        if visible {
            recursivelyEnsureDisplaySynchronously(true)
        }
    }

    /// If we just entered the hierarchy and we're editing title, make our editable
    /// title node the first responder.
    override func interfaceStateDidChange(newState: ASInterfaceState, fromState oldState: ASInterfaceState) {
        super.interfaceStateDidChange(newState, fromState: oldState)
        if newState.contains(.InHierarchy) && state.editingTitle && !editableTextNode.isFirstResponder() {
            editableTextNode.becomeFirstResponder()
        }
    }

    // MARK: Layout

    override func layoutSpecThatFits(constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let stack = ASStackLayoutSpec(
            direction: .Horizontal,
            spacing: 0,
            justifyContent: .SpaceBetween,
            alignItems: .Center,
            children: subnodes)
        return ASInsetLayoutSpec(insets: UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16), child: stack)
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
