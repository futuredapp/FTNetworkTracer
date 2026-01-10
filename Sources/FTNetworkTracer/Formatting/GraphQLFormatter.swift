import Foundation

/// Utilities for formatting GraphQL queries and variables.
///
/// This enum provides static methods for formatting GraphQL content for
/// human-readable output. Use these directly when you need to format
/// just the GraphQL-specific parts of a request.
///
/// ## Example Usage
///
/// ```swift
/// let query = """
///     query GetUser($id: ID!) {
///         user(id: $id) { name email }
///     }
///     """
///
/// let formatted = GraphQLFormatter.formatQuery(query)
/// // Output is properly indented with each field on its own line
///
/// let variables = ["id": "user-123", "limit": 10]
/// let formattedVars = GraphQLFormatter.formatVariables(variables)
/// // Output is pretty-printed JSON
/// ```
public enum GraphQLFormatter {
    /// Formats a GraphQL query with proper indentation.
    ///
    /// The formatting rules are:
    /// - `query` and `fragment` declarations are indented with one tab
    /// - Field followed by `{` is kept on the same line (e.g., `userInterests {`)
    /// - Nested content is indented with spaces
    /// - `__typename` fields are removed as noise
    ///
    /// - Parameter query: The raw GraphQL query string
    /// - Returns: Formatted query with proper indentation
    public static func formatQuery(_ query: String) -> String { // swiftlint:disable:this cyclomatic_complexity function_body_length
        // Remove __typename as it's noise in logs
        let cleanedQuery = query.replacingOccurrences(of: "__typename ", with: "")

        var formatted = "\n\t"
        var indentLevel = 0
        var currentLine = ""
        var insideParentheses = false
        var parenthesesDepth = 0
        var isFirstLine = true
        var previousWasClosingBrace = false
        var pendingField = ""

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
                if !pendingField.isEmpty {
                    // We have a pending field, merge it with {
                    currentLine = pendingField + " {"
                    pendingField = ""
                } else if !currentLine.isEmpty {
                    currentLine += " {"
                } else {
                    currentLine = "{"
                }

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
                // Flush pending field if any
                if !pendingField.isEmpty {
                    let indent = String(repeating: "  ", count: indentLevel + 1)
                    formatted += "\n\t" + indent + pendingField
                    pendingField = ""
                }

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
                        // Flush previous pending field if any (it wasn't followed by {)
                        if !pendingField.isEmpty {
                            let indent = String(repeating: "  ", count: indentLevel + 1)
                            formatted += "\n\t" + indent + pendingField
                        }
                        // Store current field as pending
                        pendingField = trimmed
                        currentLine = ""
                        previousWasClosingBrace = false
                    }
                }

            default:
                // If we have a pending field and new content starts, flush it
                if !pendingField.isEmpty {
                    let indent = String(repeating: "  ", count: indentLevel + 1)
                    formatted += "\n\t" + indent + pendingField
                    pendingField = ""
                }
                currentLine += String(char)
            }
        }

        // Add any remaining content
        if !pendingField.isEmpty {
            let indent = String(repeating: "  ", count: indentLevel + 1)
            formatted += "\n\t" + indent + pendingField
        }
        if !currentLine.trimmingCharacters(in: .whitespaces).isEmpty {
            let indent = String(repeating: "  ", count: indentLevel + 1)
            formatted += "\n\t" + indent + currentLine.trimmingCharacters(in: .whitespaces)
        }

        return formatted
    }

    /// Formats GraphQL variables as pretty-printed JSON.
    ///
    /// Variables are cleaned to handle special types like `GraphQLNullable`
    /// and Apollo input objects before serialization.
    ///
    /// - Parameter variables: Dictionary of GraphQL variables
    /// - Returns: Formatted JSON string with proper indentation
    public static func formatVariables(_ variables: [String: any Sendable]) -> String {
        let mappedVariables = variables.mapValues { $0 as Any }
        let cleanedVariables = cleanVariables(mappedVariables)

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

    // MARK: - Private Helpers

    private static func cleanValue(_ value: Any) -> Any {
        let mirror = Mirror(reflecting: value)

        // Handle GraphQLNullable
        if String(describing: mirror.subjectType).starts(with: "GraphQLNullable") {
            guard let (_, unwrappedValue) = mirror.children.first else {
                return NSNull()
            }
            return cleanValue(unwrappedValue)
        }

        // Handle standard Swift Optionals
        if mirror.displayStyle == .optional {
            guard let (_, unwrappedValue) = mirror.children.first else {
                return NSNull()
            }
            return cleanValue(unwrappedValue)
        }

        // Heuristic for Apollo input objects
        if mirror.displayStyle == .struct, let data = mirror.descendant("__data", "data") {
            if let dict = data as? [String: Any] {
                return cleanVariables(dict)
            }
        }

        if let dict = value as? [String: Any] {
            return cleanVariables(dict)
        }

        if let array = value as? [Any] {
            return array.map { cleanValue($0) }
        }

        return value
    }

    private static func cleanVariables(_ variables: [String: Any]) -> [String: Any] {
        variables.mapValues { cleanValue($0) }
    }
}
