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

    // MARK: - Message Building

    /// Builds a formatted log message from this LogEntry
    func buildMessage(configuration: LoggerConfiguration) -> String {
        let requestIdPrefix = String(requestId.prefix(8))
        let timestampString = formatTimestamp(timestamp)

        switch type {
        case let .request(method, url):
            var message = "[REQUEST] [\(requestIdPrefix)]"
            let titles = ["Method", "URL", "Timestamp"]
            let maxTitleLength = calculateMaxTitleLength(for: titles)

            message += format(title: "Method", text: method, maxTitleLength: maxTitleLength)
            message += format(title: "URL", text: url, maxTitleLength: maxTitleLength)
            message += format(title: "Timestamp", text: timestampString, maxTitleLength: maxTitleLength)

            // Mutual
            message += formatHeaders(maxTitleLength: maxTitleLength)

            // GraphQL-specific
            message += formatGraphQLRequestInfo(maxTitleLength: maxTitleLength, configuration: configuration)

            // REST-specific
            message += formatBody(configuration: configuration)

            return message

        case let .response(method, url, statusCode):
            var message = "[RESPONSE] [\(requestIdPrefix)]"
            var titles = ["Method", "URL", "Timestamp"]
            if statusCode != nil { titles.append("Status Code") }
            if duration != nil { titles.append("Duration") }

            let maxTitleLength = calculateMaxTitleLength(for: titles)
            message += format(title: "Method", text: method, maxTitleLength: maxTitleLength)
            message += format(title: "URL", text: url, maxTitleLength: maxTitleLength)

            if let statusCode {
                message += format(title: "Status Code", text: "\(statusCode)", maxTitleLength: maxTitleLength)
            }

            message += format(title: "Timestamp", text: timestampString, maxTitleLength: maxTitleLength)

            if let duration {
                message += format(title: "Duration", text: "\(String(format: "%.2f", duration * 1000))ms", maxTitleLength: maxTitleLength)
            }

            message += formatHeaders(maxTitleLength: maxTitleLength)
            message += formatBody(configuration: configuration)

            return message

        case let .error(method, url, error):
            var message = "[ERROR] [\(requestIdPrefix)]"
            let titles = ["Method", "URL", "ERROR", "Timestamp"]
            let maxTitleLength = calculateMaxTitleLength(for: titles)

            message += format(title: "Method", text: method, maxTitleLength: maxTitleLength)
            message += format(title: "URL", text: url, maxTitleLength: maxTitleLength)
            message += format(title: "ERROR", text: error, maxTitleLength: maxTitleLength)
            message += format(title: "Timestamp", text: timestampString, maxTitleLength: maxTitleLength)

            message += formatBody(configuration: configuration)

            return message
        }
    }

    // MARK: - Mutual Formatting Helpers

    private func calculateMaxTitleLength(for titles: [String]) -> Int {
        var allTitles = titles
        if let headers, !headers.isEmpty {
            allTitles.append(contentsOf: headers.keys)
        }
        if operationName != nil {
            allTitles.append("Operation")
        }
        return allTitles.map { $0.count }.max() ?? 0
    }

    private func format(title: String, text: String, maxTitleLength: Int) -> String {
        let padding = String(repeating: " ", count: max(1, maxTitleLength - title.count))
        return "\n\t\(title)\(padding)\(text)"
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    private func formatHeaders(maxTitleLength: Int) -> String {
        guard let headers, !headers.isEmpty else { return "" }

        var message = "\nHeaders:"
        // Sort headers by key to ensure consistent ordering
        let sortedHeaders = headers.sorted { $0.key < $1.key }
        for (key, value) in sortedHeaders {
            message += format(title: key, text: value, maxTitleLength: maxTitleLength)
        }
        return message
    }

    // MARK: - REST Formatting

    private func formatBody(configuration: LoggerConfiguration) -> String {
        guard let body, let bodyString = configuration.dataDecoder(body) else { return "" }

        switch type {
        case .request:
            return "\n\tBody:\n \(bodyString)"
        case .response:
            return "\nBody:\n \(bodyString)"
        case .error:
            return "\nData: \(bodyString)"
        }
    }

    // MARK: - GraphQL Formatting

    private func formatGraphQLRequestInfo(maxTitleLength: Int, configuration: LoggerConfiguration) -> String {
        var message = ""
        if let operationName {
            message += format(title: "Operation", text: operationName, maxTitleLength: maxTitleLength)
        }

        if let query {
            message += "\nQuery:"
            message += formatGraphQLQuery(query)
        }

        if let variables, !variables.isEmpty {
            message += "\nVariables:"
            message += formatGraphQLVariables(variables, configuration: configuration)
        }
        return message
    }

    /// Formats GraphQL query with proper indentation and syntax highlighting
    private func formatGraphQLQuery(_ query: String) -> String {
        // Remove __typename as it's noise in logs
        let cleanedQuery = query.replacingOccurrences(of: "__typename ", with: "")

        var formatted = "\n\t"
        var indentLevel = 0
        var currentLine = ""
        var insideParentheses = false
        var parenthesesDepth = 0
        var isFirstLine = true
        var previousWasClosingBrace = false

        for char in cleanedQuery {
            switch char {
            case "(":
                currentLine += String(char)
                insideParentheses = true
                parenthesesDepth += 1

            case ")":
                currentLine += String(char)
                parenthesesDepth -= 1
                if parenthesesDepth == 0 {
                    insideParentheses = false
                }

            case "{":
                // Add opening brace on same line
                currentLine += " {"

                let trimmed = currentLine.trimmingCharacters(in: .whitespaces)

                if indentLevel == 0 {
                    if isFirstLine {
                        // Query: - no indent
                        formatted += trimmed
                        isFirstLine = false
                    } else {
                        // query or fragment - one tab
                        if previousWasClosingBrace {
                            formatted += "\n"
                        }
                        formatted += "\n\t" + trimmed
                    }
                } else {
                    // Nested content
                    let indent = String(repeating: "  ", count: indentLevel + 1)
                    formatted += "\n\t" + indent + trimmed
                }

                currentLine = ""
                indentLevel += 1
                previousWasClosingBrace = false

            case "}":
                // Flush any remaining content on current line
                if !currentLine.trimmingCharacters(in: .whitespaces).isEmpty {
                    let indent = String(repeating: "  ", count: indentLevel + 1)
                    formatted += "\n\t" + indent + currentLine.trimmingCharacters(in: .whitespaces)
                    currentLine = ""
                }

                indentLevel = max(0, indentLevel - 1)

                if indentLevel == 0 {
                    formatted += "\n\t}"
                } else {
                    let indent = String(repeating: "  ", count: indentLevel + 1)
                    formatted += "\n\t" + indent + "}"
                }
                previousWasClosingBrace = true

            case " ", "\n", "\t":
                if insideParentheses {
                    // Keep spaces inside parentheses
                    currentLine += String(char)
                } else if !currentLine.trimmingCharacters(in: .whitespaces).isEmpty {
                    // Check if we're building a query/fragment declaration
                    let trimmed = currentLine.trimmingCharacters(in: .whitespaces)
                    if indentLevel == 0 && (trimmed == "query" || trimmed == "fragment" || trimmed == "Query:" || trimmed.hasPrefix("query ") || trimmed.hasPrefix("fragment ")) {
                        // Keep building the line for query/fragment declaration
                        currentLine += " "
                    } else {
                        // New field - flush current line
                        let indent = String(repeating: "  ", count: indentLevel + 1)
                        formatted += "\n\t" + indent + trimmed
                        currentLine = ""
                        previousWasClosingBrace = false
                    }
                }

            default:
                currentLine += String(char)
            }
        }

        // Add any remaining content
        if !currentLine.trimmingCharacters(in: .whitespaces).isEmpty {
            let indent = String(repeating: "  ", count: indentLevel + 1)
            formatted += "\n\t" + indent + currentLine.trimmingCharacters(in: .whitespaces)
        }

        return formatted
    }


    /// Formats GraphQL variables with pretty-printed JSON
    private func formatGraphQLVariables(_ variables: [String: any Sendable], configuration: LoggerConfiguration) -> String {
        let mappedVariables = variables.mapValues { $0 as Any }
        let cleanedVariables = cleanGraphQLVariables(mappedVariables)

        if JSONSerialization.isValidJSONObject(cleanedVariables),
           let variablesData = try? JSONSerialization.data(withJSONObject: cleanedVariables, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: variablesData, encoding: .utf8) {

            // Add proper indentation to each line of JSON
            let lines = jsonString.components(separatedBy: .newlines)
            var formatted = ""
            for line in lines {
                formatted += "\n\t\(line)"
            }
            return formatted
        } else {
            // Fallback to description if JSON serialization fails
            return "\n\t\(String(describing: variables))"
        }
    }

    private func cleanGraphQLValue(_ value: Any) -> Any {
        let mirror = Mirror(reflecting: value)

        // Handle GraphQLNullable
        if String(describing: mirror.subjectType).starts(with: "GraphQLNullable") {
            guard let (_, unwrappedValue) = mirror.children.first else { return NSNull() }
            return cleanGraphQLValue(unwrappedValue)
        }

        // Handle standard Swift Optionals
        if mirror.displayStyle == .optional {
            guard let (_, unwrappedValue) = mirror.children.first else { return NSNull() }
            return cleanGraphQLValue(unwrappedValue)
        }

        // Heuristic for Apollo input objects
        if mirror.displayStyle == .struct, let data = mirror.descendant("__data", "data") {
            if let dict = data as? [String: Any] {
                return cleanGraphQLVariables(dict)
            }
        }

        if let dict = value as? [String: Any] {
            return cleanGraphQLVariables(dict)
        }

        if let array = value as? [Any] {
            return array.map { cleanGraphQLValue($0) }
        }

        return value
    }

    private func cleanGraphQLVariables(_ variables: [String: Any]) -> [String: Any] {
        return variables.mapValues { cleanGraphQLValue($0) }
    }
}
