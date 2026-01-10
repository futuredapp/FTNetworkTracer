import Foundation

/// Represents a network trace event (request, response, or error).
///
/// This struct is the core data type for network tracing. It can be used as:
/// - Input for ``NetworkTraceFormatter`` to generate human-readable log output
/// - Input for ``MaskingUtilities`` to create privacy-masked versions for analytics
/// - The `Context` type in `NetworkObserver` implementations
///
/// ## Example Usage
///
/// ```swift
/// // Create a request entry
/// let entry = NetworkTraceEntry(
///     type: .request(method: "GET", url: "https://api.example.com/users"),
///     headers: ["Authorization": "Bearer token"],
///     requestId: UUID().uuidString
/// )
///
/// // Format for console output
/// let formatted = NetworkTraceFormatter.format(entry)
///
/// // Mask for analytics
/// let masked = MaskingUtilities.mask(entry, configuration: .private)
/// ```
public struct NetworkTraceEntry: Sendable {
    /// The type of network entry (request, response, or error).
    public let type: EntryType

    /// The network headers associated with the entry.
    public let headers: [String: String]?

    /// The body data of the network request or response.
    public let body: Data?

    /// The timestamp when the entry was created.
    public let timestamp: Date

    /// The duration of the network activity, if applicable.
    public let duration: TimeInterval?

    /// A unique identifier for the network request.
    public let requestId: String

    // MARK: - GraphQL-specific properties

    /// The GraphQL operation name (nil for REST requests).
    public let operationName: String?

    /// The GraphQL query string (nil for REST requests).
    public let query: String?

    /// The GraphQL variables (nil for REST requests).
    public let variables: [String: any Sendable]?

    /// Creates a new network trace entry.
    ///
    /// - Parameters:
    ///   - type: The type of network entry (request, response, or error)
    ///   - headers: Optional HTTP headers
    ///   - body: Optional request/response body data
    ///   - timestamp: The time when this entry was created (defaults to now)
    ///   - duration: Optional duration of the network operation
    ///   - requestId: Unique identifier for correlating request/response pairs
    ///   - operationName: Optional GraphQL operation name
    ///   - query: Optional GraphQL query string
    ///   - variables: Optional GraphQL variables
    public init(
        type: EntryType,
        headers: [String: String]? = nil,
        body: Data? = nil,
        timestamp: Date = Date(),
        duration: TimeInterval? = nil,
        requestId: String = UUID().uuidString,
        operationName: String? = nil,
        query: String? = nil,
        variables: [String: any Sendable]? = nil
    ) {
        self.type = type
        self.headers = headers
        self.body = body
        self.timestamp = timestamp
        self.duration = duration
        self.requestId = requestId
        self.operationName = operationName
        self.query = query
        self.variables = variables
    }

    // MARK: - Convenience Properties

    /// The HTTP method of the network request.
    public var method: String {
        switch type {
        case let .request(method, _),
             let .response(method, _, _),
             let .error(method, _, _):
            return method
        }
    }

    /// The URL of the network request.
    public var url: String {
        switch type {
        case let .request(_, url),
             let .response(_, url, _),
             let .error(_, url, _):
            return url
        }
    }

    /// The HTTP status code of the network response, if available.
    public var statusCode: Int? {
        switch type {
        case let .response(_, _, statusCode):
            return statusCode
        case .request, .error:
            return nil
        }
    }

    /// The error message, if the entry represents an error.
    public var error: String? {
        switch type {
        case let .error(_, _, error):
            return error
        case .request, .response:
            return nil
        }
    }

    /// Whether this entry represents a GraphQL operation.
    public var isGraphQL: Bool {
        operationName != nil || query != nil || variables != nil
    }
}
