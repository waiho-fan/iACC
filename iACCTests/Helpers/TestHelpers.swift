//	
// Copyright © Essential Developer. All rights reserved.
//

import Foundation

@MainActor
func until(_ predicate: @escaping @autoclosure @MainActor () async throws -> Bool, timeout: TimeInterval = 0.5) async throws {
    let startTime = Date()

    while try await !predicate() {
        if Date().timeIntervalSince(startTime) > timeout {
            throw Timeout()
        }

        await Task.yield()
    }
}

@MainActor @discardableResult
func existence<T>(of value: @escaping @autoclosure @MainActor () async throws -> T?, timeout: TimeInterval = 0.5) async throws -> T {
    let startTime = Date()

    while true {
        if let value = try await value() {
            return value
        }
        
        if Date().timeIntervalSince(startTime) > timeout {
            throw Timeout()
        }

        await Task.yield()
    }
}
