import Foundation

/// Common protocol for log and analytic entries.
///
/// This protocol providing a common interface for accessing network activity data.
public protocol NetworkEntry: Sendable {
    /// The type of network entry (request, response, or error).
    var type: EntryType { get }

    /// The network headers associated with the entry.
    var headers: [String: String]? { get }

    /// The body data of the network request or response.
    var body: Data? { get }

    /// The timestamp when the entry was created.
    var timestamp: Date { get }

    /// The duration of the network activity, if applicable.
    var duration: TimeInterval? { get }

    /// A unique identifier for the network request.
    var requestId: String { get }
}

extension NetworkEntry {
    /// The HTTP method of the network request.
    public var method: String {
        switch type {
        case let .request(method, _), let .response(method, _, _), let .error(method, _, _):
            return method
        }
    }

    /// The URL of the network request.
    public var url: String {
        switch type {
        case let .request(_, url), let .response(_, url, _), let .error(_, url, _):
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
}
