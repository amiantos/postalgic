import Foundation
import UIKit

/// A non-SwiftData abstraction of an Embed used during post creation
struct EmbedDraft {
    var url: String
    var type: EmbedType
    var position: EmbedPosition
    var title: String?
    var embedDescription: String?
    var imageUrl: String?
    var imageData: Data?
    
    init(
        url: String = "",
        type: EmbedType = .youtube,
        position: EmbedPosition = .below,
        title: String? = nil,
        embedDescription: String? = nil,
        imageUrl: String? = nil,
        imageData: Data? = nil
    ) {
        self.url = url
        self.type = type
        self.position = position
        self.title = title
        self.embedDescription = embedDescription
        self.imageUrl = imageUrl
        self.imageData = imageData
    }
    
    /// Convert from a SwiftData Embed to an EmbedDraft
    static func fromEmbed(_ embed: Embed) -> EmbedDraft {
        return EmbedDraft(
            url: embed.url,
            type: embed.embedType,
            position: embed.embedPosition,
            title: embed.title,
            embedDescription: embed.embedDescription,
            imageUrl: embed.imageUrl,
            imageData: embed.imageData
        )
    }
    
    /// Convert this draft to a persistent Embed object
    func toEmbed() -> Embed {
        let embed = Embed(
            url: url,
            type: type,
            position: position,
            title: title,
            embedDescription: embedDescription,
            imageUrl: imageUrl,
            imageData: imageData
        )
        return embed
    }
}