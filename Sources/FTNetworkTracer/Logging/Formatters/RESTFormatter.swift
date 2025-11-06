//
//  RESTFormatter.swift
//  FTNetworkTracer
//
//  Created by Simon Sestak on 04/11/2025.
//

import Foundation

/// Utility for formatting REST request/response bodies for logging
enum RESTFormatter {
    /// Formats body data using the provided decoder
    ///
    /// - Parameters:
    ///   - body: The body data to format
    ///   - decoder: Function to decode data into string
    ///   - type: The type of entry (request/response/error) to determine prefix
    /// - Returns: Formatted body string with proper indentation, or empty string if no body
    static func formatBody(_ body: Data?, decoder: @Sendable (Data) -> String?, type: EntryType) -> String {
        guard let body, let bodyString = decoder(body) else {
            return ""
        }

        switch type {
        case .request:
            return "\n\tBody:\n \(bodyString)"
        case .response:
            return "\nBody:\n \(bodyString)"
        case .error:
            return "\nData: \(bodyString)"
        }
    }
}
