//
//  Utils.swift
//  Postalgic
//
//  Created by Brad Root on 4/24/25.
//

import Foundation

struct Utils {
    static func extractYouTubeId(from url: String) -> String? {
        let patterns = [
            // youtu.be URLs
            "youtu\\.be\\/([a-zA-Z0-9_-]{11})",
            // youtube.com/watch?v= URLs
            "youtube\\.com\\/watch\\?v=([a-zA-Z0-9_-]{11})",
            // youtube.com/embed/ URLs
            "youtube\\.com\\/embed\\/([a-zA-Z0-9_-]{11})",
            "youtube\\.com\\/live\\/([a-zA-Z0-9_-]{11})"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
               let range = Range(match.range(at: 1), in: url) {
                return String(url[range])
            }
        }
        
        return nil
    }
}