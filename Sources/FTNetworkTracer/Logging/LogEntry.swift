import Foundation
#if canImport(os.log)
import os.log
#endif
/// Represents a log entry for logging network activity.
///
/// This struct contains all the data needed to log network requests, responses, and errors.
/// It uses ``EntryType`` with associated values to provide type-safe access to basic
/// network information without optionals.
///
/// - Note: For analytics tracking, use ``AnalyticEntry`` instead.
struct LogEntry: NetworkEntry {
    let type: EntryType
    let headers: [String: String]?
    let body: Data?
    let timestamp: Date
    let duration: TimeInterval?
    let requestId: String

    /// Additional context for GraphQL operations
    let operationName: String?
    let query: String?
    let variables: [String: any Sendable]?

    #if canImport(os.log)
    var level: OSLogType {
        switch type {
        case .error:
            return .error
        case let .response(_, _, statusCode):
            guard let statusCode = statusCode else { return .info }
            return statusCode >= 400 ? .error : .info
        case .request:
            return .info
        }
    }
    #endif

    init(
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

    /// Builds a formatted log message from this LogEntry
    func buildMessage(configuration: LoggerConfiguration) -> String {
        let requestIdPrefix = String(requestId.prefix(8))
        let timestampString = formatTimestamp(timestamp)

        switch type {
        case let .request(method, url):
            var message = "[REQUEST] [\(requestIdPrefix)]"

            // Collect all titles for alignment calculation
            var allTitles = ["Method", "URL", "Timestamp"]
            if operationName != nil {
                allTitles.append("Operation")
            }
            if let headers, !headers.isEmpty {
                allTitles.append(contentsOf: headers.keys)
            }

            let maxTitleLength = allTitles.map { $0.count }.max() ?? 0
            message += format(title: "Method", text: method, maxTitleLength: maxTitleLength)
            message += format(title: "URL", text: url, maxTitleLength: maxTitleLength)
            message += format(title: "Timestamp", text: timestampString, maxTitleLength: maxTitleLength)

            if let operationName {
                message += format(title: "Operation", text: operationName, maxTitleLength: maxTitleLength)
            }

            if let headers, !headers.isEmpty {
                message += format(headers: headers, maxTitleLength: maxTitleLength)
            }

            if let query {
                message += "\n\tQuery:\n\(query)"
            }

            if let variables, !variables.isEmpty,
               let variablesData = try? JSONSerialization.data(withJSONObject: variables.mapValues { $0 as Any }, options: [.prettyPrinted]),
               let variablesString = String(data: variablesData, encoding: .utf8) {
                message += "\n\tVariables:\n\(variablesString)"
            }

            if let body, let bodyString = configuration.dataDecoder(body) {
                message += "\n\tBody:\n \(bodyString)"
            }

            return message

        case let .response(method, url, statusCode):
            var message = "[RESPONSE] [\(requestIdPrefix)]"

            // Collect all titles for alignment calculation
            var allTitles = ["Method", "URL", "Timestamp"]
            if statusCode != nil {
                allTitles.append("Status Code")
            }
            if duration != nil {
                allTitles.append("Duration")
            }
            if let headers, !headers.isEmpty {
                allTitles.append(contentsOf: headers.keys)
            }

            let maxTitleLength = allTitles.map { $0.count }.max() ?? 0
            message += format(title: "Method", text: method, maxTitleLength: maxTitleLength)
            message += format(title: "URL", text: url, maxTitleLength: maxTitleLength)

            if let statusCode {
                message += format(title: "Status Code", text: "\(statusCode)", maxTitleLength: maxTitleLength)
            }

            message += format(title: "Timestamp", text: timestampString, maxTitleLength: maxTitleLength)

            if let duration {
                message += format(title: "Duration", text: "\(String(format: "%.2f", duration * 1000))ms", maxTitleLength: maxTitleLength)
            }

            if let headers, !headers.isEmpty {
                message += format(headers: headers, maxTitleLength: maxTitleLength)
            }

            if let body, let bodyString = configuration.dataDecoder(body) {
                message += "\nBody:\n \(bodyString)"
            }

            return message

        case let .error(method, url, error):
            var message = "[ERROR] [\(requestIdPrefix)]"

            // Collect all titles for alignment calculation
            var allTitles = ["Method", "URL", "ERROR", "Timestamp"]
            if let headers, !headers.isEmpty {
                allTitles.append(contentsOf: headers.keys)
            }

            let maxTitleLength = allTitles.map { $0.count }.max() ?? 0
            message += format(title: "Method", text: method, maxTitleLength: maxTitleLength)
            message += format(title: "URL", text: url, maxTitleLength: maxTitleLength)
            message += format(title: "ERROR", text: error, maxTitleLength: maxTitleLength)
            message += format(title: "Timestamp", text: timestampString, maxTitleLength: maxTitleLength)

            if let body, let bodyString = configuration.dataDecoder(body) {
                message += "\nData: \(bodyString)"
            }

            return message
        }
    }

    private func format(headers: [String: String], maxTitleLength: Int) -> String {
        guard !headers.isEmpty else {
            return ""
        }

        var message = "\n\tHeaders:"
        // Sort headers by key to ensure consistent ordering
        let sortedHeaders = headers.sorted { $0.key < $1.key }
        for (key, value) in sortedHeaders {
            message += format(title: key, text: value, maxTitleLength: maxTitleLength)
        }
        return message
    }

    private func format(title: String, text: String, maxTitleLength: Int) -> String {
        let padding = String(repeating: " ", count: max(1, maxTitleLength - title.count))
        return "\n\t\t\(title)\(padding)\(text)"
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}
