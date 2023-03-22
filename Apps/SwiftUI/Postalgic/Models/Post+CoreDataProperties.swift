//
//  Post+CoreDataProperties.swift
//  Postalgic
//
//  Created by Brad Root on 3/21/23.
//
//

import Foundation
import CoreData


extension Post {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Post> {
        return NSFetchRequest<Post>(entityName: "Post")
    }

    @NSManaged public var slug: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var blocks: NSSet?
    
    public var blocksArray: [PostBlock] {
        let set = blocks as? Set<PostBlock> ?? []
        return set.sorted {
            $0.displayOrder < $1.displayOrder
        }
    }

}

// MARK: Generated accessors for blocks
extension Post {

    @objc(addBlocksObject:)
    @NSManaged public func addToBlocks(_ value: PostBlock)

    @objc(removeBlocksObject:)
    @NSManaged public func removeFromBlocks(_ value: PostBlock)

    @objc(addBlocks:)
    @NSManaged public func addToBlocks(_ values: NSSet)

    @objc(removeBlocks:)
    @NSManaged public func removeFromBlocks(_ values: NSSet)

}

extension Post : Identifiable {

}
