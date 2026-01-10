import Foundation

/// Utilities for formatting REST request/response bodies.
///
/// This enum provides static methods for formatting REST body content
/// for human-readable output.
///
/// ## Example Usage
///
/// ```swift
/// let body = jsonData
/// let formatted = RESTFormatter.formatBody(
///     body,
///     decoder: FormatterConfiguration.defaultDataDecoder,
///     label: "Body"
/// )
/// ```
public enum RESTFormatter {
    /// Formats body data using the provided decoder.
    ///
    /// - Parameters:
    ///   - body: The body data to format (nil returns empty string)
    ///   - decoder: Function to decode data into string
    ///   - label: The label to use (e.g., "Body", "Data", "Response")
    /// - Returns: Formatted body string with proper indentation, or empty string if no body
    public static func formatBody(
        _ body: Data?,
        decoder: @Sendable (Data) -> String?,
        label: String
    ) -> String {
        guard let body, let bodyString = decoder(body) else {
            return ""
        }
        return "\n\(label):\n \(bodyString)"
    }
}
