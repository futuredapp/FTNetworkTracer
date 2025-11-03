import Foundation

/// Data structure for analytics tracking.
///
/// This struct contains network activity data that has been privacy-masked based on
/// the configured ``AnalyticsConfiguration``. It uses ``EntryType`` with associated values
/// to provide type-safe access to basic network information without optionals.
///
/// - Note: This struct is used by ``AnalyticsProtocol`` implementations for tracking
/// network activity. For logging purposes, use ``LogEntry`` instead.
public struct AnalyticEntry: Sendable {
    public let type: EntryType
    public let headers: [String: String]?
    public let body: Data?
    public let timestamp: Date
    public let duration: TimeInterval?
    public let requestId: String

    /// Additional context for GraphQL operations
    public let operationName: String?
    public let variables: [String: any Sendable]?

    public init(
        type: EntryType,
        headers: [String: String]? = nil,
        body: Data? = nil,
        timestamp: Date = Date(),
        duration: TimeInterval? = nil,
        requestId: String = UUID().uuidString,
        operationName: String? = nil,
        variables: [String: any Sendable]? = nil,
        configuration: AnalyticsConfiguration = AnalyticsConfiguration.default
    ) {
        // Create masked type with masked URL
        let maskedType: EntryType
        switch type {
        case let .request(method, url):
            maskedType = .request(method: method, url: configuration.maskUrl(url) ?? url)
        case let .response(method, url, statusCode):
            maskedType = .response(method: method, url: configuration.maskUrl(url) ?? url, statusCode: statusCode)
        case let .error(method, url, error):
            maskedType = .error(method: method, url: configuration.maskUrl(url) ?? url, error: error)
        }

        self.type = maskedType
        self.headers = configuration.maskHeaders(headers)
        self.body = configuration.maskBody(body)
        self.timestamp = timestamp
        self.duration = duration
        self.requestId = requestId
        self.operationName = operationName
        self.variables = configuration.maskVariables(variables)
    }

    /// Convenience computed properties for accessing associated values
    public var method: String {
        switch type {
        case let .request(method, _), let .response(method, _, _), let .error(method, _, _):
            return method
        }
    }

    public var url: String {
        switch type {
        case let .request(_, url), let .response(_, url, _), let .error(_, url, _):
            return url
        }
    }

    public var statusCode: Int? {
        switch type {
        case let .response(_, _, statusCode):
            return statusCode
        case .request, .error:
            return nil
        }
    }

    public var error: String? {
        switch type {
        case let .error(_, _, error):
            return error
        case .request, .response:
            return nil
        }
    }
}
