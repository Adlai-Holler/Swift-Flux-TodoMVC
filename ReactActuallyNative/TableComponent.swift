//
//  TableComponent.swift
//  ReactActuallyNative
//
//  Created by Adlai Holler on 2/6/16.
//  Copyright © 2016 Adlai Holler. All rights reserved.
//


import AsyncDisplayKit
import ArrayDiff

protocol NodeCache {
    func nodeForKey<Node: ASCellNode>(key: String, create: (String) -> Node) -> Node
    func existingNodeForKey<Node: ASCellNode>(key: String) -> Node?
}

extension NSMapTable: NodeCache {
    func nodeForKey<Node : ASCellNode>(key: String, create: (String) -> Node) -> Node {
        if let existing = self.existingNodeForKey(key) as? Node {
            return existing
        }
        let new = create(key)
        setObject(new, forKey: key)
        return new
    }

    func existingNodeForKey<Node : ASCellNode>(key: String) -> Node? {
        return objectForKey(key) as! Node?
    }
}

protocol TableComponent {
    func renderTableData<Section: SectionType>(nodeCache: NodeCache) -> [Section]
}
