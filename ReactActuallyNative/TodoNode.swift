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
    private let imageNode = ASImageNode()
    private lazy var editableTextNode = ASEditableTextNode()
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
        addSubnode(imageNode)
        imageNode.hitTestSlop = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)

        imageNode.backgroundColor = UIColor.whiteColor()
        imageNode.addTarget(self, action: "didTapCheckImage", forControlEvents: .TouchUpInside)
        setState(state)
    }

    // MARK: Action Handling

    @objc private func didTapCheckImage() {
        let item = state.item
        TodoAction.SetCompleted(item.objectID!, !item.completed).dispatch()
    }

    // MARK: State Updating

    private struct StateTransitionInfo {
        var shouldAnimateCheckImage: Bool
    }

    func setState(state: State) {
        lock.lock()
        _state = state
        lock.unlock()

        let newTitle = NSAttributedString(string: state.item.title ?? "(Untitled)", attributes: Style.titleAttributes)
        if newTitle != textNode.attributedString {
            textNode.attributedString = newTitle
        }
        let newImage = UIImage(named: state.item.completed ? "selection-on" : "selection-off")!
        let shouldAnimate = interfaceState.contains(.Visible) && state.item.completed && imageNode.image != newImage
        imageNode.image = newImage
        let transitionInfo = StateTransitionInfo(shouldAnimateCheckImage: shouldAnimate)
        dispatch_async(dispatch_get_main_queue()) {
            self.didSetState_mainThread(state, info: transitionInfo)
        }
    }

    private func didSetState_mainThread(state: State, info: StateTransitionInfo) {
        if info.shouldAnimateCheckImage {
            let animation = POPBasicAnimation(propertyNamed: kPOPLayerScaleXY)
            animation.duration = 0.1
            animation.toValue = NSValue(CGPoint: CGPoint(x: 1.1, y: 1.1))
            imageNode.layer.pop_addAnimation(animation, forKey: "completeAnimation1")
            animation.completionBlock = { _ in
                let secondAnimation = POPSpringAnimation(propertyNamed: kPOPLayerScaleXY)
                secondAnimation.springBounciness = 10
                secondAnimation.toValue = NSValue(CGPoint: CGPoint(x: 1, y: 1))
                self.imageNode.layer.pop_addAnimation(secondAnimation, forKey: "completeAnimation2")
            }
        }

        if state.editingTitle && textNode.supernode != nil {
            textNode.removeFromSupernode()
            editableTextNode.attributedText = textNode.attributedString
            insertSubnode(editableTextNode, atIndex: 0)
            editableTextNode.becomeFirstResponder()
            editableTextNode.selectedRange = NSMakeRange(editableTextNode.attributedText!.length, 0)
            editableTextNode.delegate = self
            editableTextNode.flexBasis = ASRelativeDimensionMakeWithPoints(1)
            editableTextNode.flexGrow = true
        } else if !state.editingTitle && textNode.supernode == nil {
            editableTextNode.removeFromSupernode()
            insertSubnode(textNode, atIndex: 0)
        }
        setNeedsLayout()
        if interfaceState.contains(.Visible) {
            recursivelyEnsureDisplaySynchronously(true)
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
