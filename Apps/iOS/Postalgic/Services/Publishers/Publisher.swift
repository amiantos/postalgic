//
//  Publisher.swift
//  Postalgic
//
//  Created by Brad Root on 4/25/25.
//

import Foundation

/// Protocol that all publishers must conform to
protocol Publisher {
    func publish(directoryURL: URL) async throws -> URL?
    var publisherType: PublisherType { get }
}
