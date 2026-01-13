import Foundation

/// Formats ``NetworkTraceEntry`` into human-readable strings.
///
/// This is the main formatting API for network tracing. Use it to generate
/// console-friendly output from network trace entries.
///
/// ## Example Usage
///
/// ```swift
/// let entry = NetworkTraceEntry(
///     type: .request(method: "GET", url: "https://api.example.com/users"),
///     headers: ["Authorization": "Bearer token"],
///     requestId: UUID().uuidString
/// )
///
/// // Format with default configuration
/// let output = NetworkTraceFormatter.format(entry)
///
/// // Format with custom configuration
/// let compact = NetworkTraceFormatter.format(entry, configuration: .compact)
/// ```
public enum NetworkTraceFormatter {
    /// Formats an entry with the default configuration.
    ///
    /// - Parameter entry: The network trace entry to format
    /// - Returns: Human-readable formatted string
    public static func format(_ entry: NetworkTraceEntry) -> String {
        format(entry, configuration: .default)
    }

    /// Formats an entry with a custom configuration.
    ///
    /// - Parameters:
    ///   - entry: The network trace entry to format
    ///   - configuration: The formatting configuration to use
    /// - Returns: Human-readable formatted string
    public static func format(
        _ entry: NetworkTraceEntry,
        configuration: FormatterConfiguration
    ) -> String {
        switch entry.type {
        case let .request(method, url):
            return formatRequest(
                entry: entry,
                method: method,
                url: url,
                configuration: configuration
            )

        case let .response(method, url, statusCode):
            return formatResponse(
                entry: entry,
                method: method,
                url: url,
                statusCode: statusCode,
                configuration: configuration
            )

        case let .error(method, url, error):
            return formatError(
                entry: entry,
                method: method,
                url: url,
                error: error,
                configuration: configuration
            )
        }
    }

    // MARK: - Private Formatters

    private static func formatRequest(
        entry: NetworkTraceEntry,
        method: String,
        url: String,
        configuration: FormatterConfiguration
    ) -> String {
        let requestIdPrefix = String(entry.requestId.prefix(8))
        let timestampString = formatTimestamp(entry.timestamp)

        var titles = ["Method", "URL", "Timestamp"]
        if configuration.includeHeaders, let headers = entry.headers, !headers.isEmpty {
            titles.append(contentsOf: headers.keys)
        }
        if entry.operationName != nil {
            titles.append("Operation")
        }
        let maxTitleLength = titles.map { $0.count }.max() ?? 0

        var message = "[REQUEST] [\(requestIdPrefix)]"
        message += format(title: "Method", text: method, maxTitleLength: maxTitleLength)
        message += format(title: "URL", text: url, maxTitleLength: maxTitleLength)
        message += format(title: "Timestamp", text: timestampString, maxTitleLength: maxTitleLength)

        if configuration.includeHeaders {
            message += formatHeaders(entry.headers, maxTitleLength: maxTitleLength)
        }

        // GraphQL-specific
        message += formatGraphQLInfo(entry, maxTitleLength: maxTitleLength)

        // REST body
        if configuration.includeBody {
            message += formatBody(entry.body, configuration: configuration, label: "Body")
        }

        return message
    }

    private static func formatResponse(
        entry: NetworkTraceEntry,
        method: String,
        url: String,
        statusCode: Int?,
        configuration: FormatterConfiguration
    ) -> String {
        let requestIdPrefix = String(entry.requestId.prefix(8))
        let timestampString = formatTimestamp(entry.timestamp)

        var titles = ["Method", "URL", "Timestamp"]
        if statusCode != nil { titles.append("Status Code") }
        if entry.duration != nil { titles.append("Duration") }
        if configuration.includeHeaders, let headers = entry.headers, !headers.isEmpty {
            titles.append(contentsOf: headers.keys)
        }
        let maxTitleLength = titles.map { $0.count }.max() ?? 0

        var message = "[RESPONSE] [\(requestIdPrefix)]"
        message += format(title: "Method", text: method, maxTitleLength: maxTitleLength)
        message += format(title: "URL", text: url, maxTitleLength: maxTitleLength)

        if let statusCode {
            message += format(title: "Status Code", text: "\(statusCode)", maxTitleLength: maxTitleLength)
        }

        message += format(title: "Timestamp", text: timestampString, maxTitleLength: maxTitleLength)

        if let duration = entry.duration {
            message += format(title: "Duration", text: "\(String(format: "%.2f", duration * 1_000))ms", maxTitleLength: maxTitleLength)
        }

        if configuration.includeHeaders {
            message += formatHeaders(entry.headers, maxTitleLength: maxTitleLength)
        }

        if configuration.includeBody {
            message += formatBody(entry.body, configuration: configuration, label: "Body")
        }

        return message
    }

    private static func formatError(
        entry: NetworkTraceEntry,
        method: String,
        url: String,
        error: String,
        configuration: FormatterConfiguration
    ) -> String {
        let requestIdPrefix = String(entry.requestId.prefix(8))
        let timestampString = formatTimestamp(entry.timestamp)

        let titles = ["Method", "URL", "ERROR", "Timestamp"]
        let maxTitleLength = titles.map { $0.count }.max() ?? 0

        var message = "[ERROR] [\(requestIdPrefix)]"
        message += format(title: "Method", text: method, maxTitleLength: maxTitleLength)
        message += format(title: "URL", text: url, maxTitleLength: maxTitleLength)
        message += format(title: "ERROR", text: error, maxTitleLength: maxTitleLength)
        message += format(title: "Timestamp", text: timestampString, maxTitleLength: maxTitleLength)

        if configuration.includeBody {
            message += formatBody(entry.body, configuration: configuration, label: "Data")
        }

        return message
    }

    // MARK: - Formatting Helpers

    private static func format(title: String, text: String, maxTitleLength: Int) -> String {
        let padding = String(repeating: " ", count: max(1, maxTitleLength - title.count))
        return "\n\t\(title)\(padding)\(text)"
    }

    private static func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    private static func formatHeaders(_ headers: [String: String]?, maxTitleLength: Int) -> String {
        guard let headers, !headers.isEmpty else {
            return ""
        }

        var message = "\nHeaders:"
        let sortedHeaders = headers.sorted { $0.key < $1.key }
        for (key, value) in sortedHeaders {
            message += format(title: key, text: value, maxTitleLength: maxTitleLength)
        }
        return message
    }

    private static func formatGraphQLInfo(_ entry: NetworkTraceEntry, maxTitleLength: Int) -> String {
        var message = ""

        if let operationName = entry.operationName {
            message += format(title: "Operation", text: operationName, maxTitleLength: maxTitleLength)
        }

        if let query = entry.query {
            message += "\nQuery:"
            message += GraphQLFormatter.formatQuery(query)
        }

        if let variables = entry.variables, !variables.isEmpty {
            message += "\nVariables:"
            message += GraphQLFormatter.formatVariables(variables)
        }

        return message
    }

    private static func formatBody(
        _ body: Data?,
        configuration: FormatterConfiguration,
        label: String
    ) -> String {
        guard let body, let bodyString = configuration.dataDecoder(body) else {
            return ""
        }

        var output = bodyString
        if let maxLength = configuration.maxBodyLength, output.count > maxLength {
            output = String(output.prefix(maxLength)) + "... (truncated)"
        }

        return "\n\(label):\n \(output)"
    }
}
