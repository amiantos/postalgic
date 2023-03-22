//
//  PostBlock+CoreDataProperties.swift
//  Postalgic
//
//  Created by Brad Root on 3/21/23.
//
//

import Foundation
import CoreData


extension PostBlock {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PostBlock> {
        return NSFetchRequest<PostBlock>(entityName: "PostBlock")
    }

    @NSManaged public var content: String
    @NSManaged public var type: String
    @NSManaged public var displayOrder: Int16
    @NSManaged public var post: Post

}

extension PostBlock : Identifiable {

}
