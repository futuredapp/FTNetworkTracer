import Foundation

/// Configuration for analytics functionality.
///
/// This struct defines the privacy level and exceptions for masking sensitive data
/// in analytics. It allows you to specify which headers, URL query parameters,
/// and body/variable parameters should not be masked.
public struct AnalyticsConfiguration: Sendable {
    /// The privacy level for data masking.
    public let privacy: AnalyticsPrivacy

    /// Whether to mask literal values in GraphQL queries (default: true for security).
    public let maskQueryLiterals: Bool

    private let unmaskedHeaders: Set<String>
    private let unmaskedUrlQueries: Set<String>
    private let unmaskedBodyParams: Set<String>

    /// Initializes a new analytics configuration.
    ///
    /// - Parameters:
    ///   - privacy: The privacy level for data masking.
    ///   - maskQueryLiterals: Whether to mask literal values in GraphQL queries (default: true).
    ///   - unmaskedHeaders: A set of header keys that should not be masked.
    ///   - unmaskedUrlQueries: A set of URL query parameter keys that should not be masked.
    ///   - unmaskedBodyParams: A set of body/variable parameter keys that should not be masked.
    public init(
        privacy: AnalyticsPrivacy,
        maskQueryLiterals: Bool = true,
        unmaskedHeaders: Set<String> = [],
        unmaskedUrlQueries: Set<String> = [],
        unmaskedBodyParams: Set<String> = []
    ) {
        self.privacy = privacy
        self.maskQueryLiterals = maskQueryLiterals
        self.unmaskedHeaders = unmaskedHeaders
        self.unmaskedUrlQueries = unmaskedUrlQueries
        self.unmaskedBodyParams = unmaskedBodyParams
    }

    /// Default analytics configuration with sensitive privacy
    public static let `default` = AnalyticsConfiguration(privacy: .sensitive)

    // MARK: - Internal Masking Methods

    func maskUrl(_ url: String?) -> String? {
        guard let url else {
            return nil
        }

        switch privacy {
        case .none:
            return url
        case .private:
            return maskPrivateUrlQueries(url)
        case .sensitive:
            return maskSensitiveUrlQueries(url)
        }
    }

    private func maskPrivateUrlQueries(_ url: String) -> String {
        guard let urlComponents = URLComponents(string: url),
              let queryItems = urlComponents.queryItems else {
            return url
        }

        let maskedQueryItems = queryItems.map { item -> URLQueryItem in
            if unmaskedUrlQueries.contains(item.name.lowercased()) {
                return item
            }
            return URLQueryItem(name: item.name, value: "***")
        }

        var maskedComponents = urlComponents
        maskedComponents.queryItems = maskedQueryItems
        return maskedComponents.url?.absoluteString ?? url
    }

    private func maskSensitiveUrlQueries(_ url: String) -> String {
        guard let urlComponents = URLComponents(string: url) else {
            return url
        }

        var maskedComponents = urlComponents
        maskedComponents.query = nil

        return maskedComponents.url?.absoluteString ?? url
    }

    func maskHeaders(_ headers: [String: String]?) -> [String: String]? {
        guard let headers else {
            return nil
        }

        switch privacy {
        case .none:
            return headers
        case .private:
            var maskedHeaders: [String: String] = [:]
            for (key, value) in headers {
                if unmaskedHeaders.contains(key.lowercased()) {
                    maskedHeaders[key] = value
                } else {
                    maskedHeaders[key] = "***"
                }
            }
            return maskedHeaders
        case .sensitive:
            return headers.mapValues { _ in "***" }
        }
    }

    func maskBody(_ body: Data?) -> Data? {
        guard let body else {
            return nil
        }

        switch privacy {
        case .none:
            return body
        case .private:
            return maskPrivateBodyParams(body)
        case .sensitive:
            return nil
        }
    }

    func maskVariables(_ variables: [String: any Sendable]?) -> [String: any Sendable]? {
        guard let variables else {
            return nil
        }

        switch privacy {
        case .none:
            return variables
        case .private:
            let anyVariables = Dictionary(uniqueKeysWithValues: variables.map { ($0.key, $0.value as Any) })
            return recursivelyMask(anyVariables) as? [String: any Sendable]
        case .sensitive:
            return nil
        }
    }

    private func maskPrivateBodyParams(_ body: Data) -> Data? {
        guard let json = try? JSONSerialization.jsonObject(with: body) else {
            return Data("***".utf8)
        }

        let maskedJson = recursivelyMask(json)

        return try? JSONSerialization.data(withJSONObject: maskedJson)
    }

    private func recursivelyMask(_ data: Any) -> Any {
        if let dictionary = data as? [String: any Sendable] {
            var newDict: [String: Any] = [:]
            for (key, value) in dictionary {
                if unmaskedBodyParams.contains(key.lowercased()) {
                    newDict[key] = value
                } else {
                    newDict[key] = recursivelyMask(value)
                }
            }
            return newDict
        } else if let array = data as? [Any] {
            return array.map { recursivelyMask($0) }
        } else {
            return "***"
        }
    }

    func maskQuery(_ query: String?) -> String? {
        guard let query else {
            return nil
        }

        switch privacy {
        case .none, .private:
            return maskQueryLiterals ? maskQueryLiteralValues(query) : query
        case .sensitive:
            return nil
        }
    }

    private func maskQueryLiteralValues(_ query: String) -> String {
        var result = ""
        var insideString = false
        var insideParentheses = false
        var currentToken = ""
        var escapeNext = false

        for char in query {
            // Handle escape sequences in strings
            if escapeNext {
                if insideString {
                    currentToken.append(char)
                } else {
                    result.append(char)
                }
                escapeNext = false
                continue
            }

            if char == "\\" {
                escapeNext = true
                if insideString {
                    currentToken.append(char)
                } else {
                    result.append(char)
                }
                continue
            }

            switch char {
            case "\"":
                if insideParentheses && !insideString {
                    // Start of string literal in arguments
                    insideString = true
                    currentToken = "\""
                } else if insideString {
                    // End of string literal - mask it
                    insideString = false
                    result.append("\"***\"")
                    currentToken = ""
                } else {
                    result.append(char)
                }

            case "(":
                result.append(currentToken)
                result.append(char)
                currentToken = ""
                insideParentheses = true

            case ")":
                // Flush any pending number literal
                if insideParentheses && !currentToken.isEmpty {
                    if isNumericLiteral(currentToken) {
                        result.append("***")
                    } else {
                        result.append(currentToken)
                    }
                }
                result.append(char)
                currentToken = ""
                insideParentheses = false

            case " ", "\n", "\t", ",", ":":
                if insideString {
                    // Inside string literal - accumulate character
                    currentToken.append(char)
                } else {
                    // Delimiter - check if we have a pending number literal
                    if insideParentheses && !currentToken.isEmpty {
                        if isNumericLiteral(currentToken) {
                            result.append("***")
                        } else {
                            result.append(currentToken)
                        }
                        currentToken = ""
                    }
                    result.append(char)
                }

            default:
                if insideString {
                    // Inside string literal - accumulate but don't output
                    currentToken.append(char)
                } else if insideParentheses {
                    // Might be building a number literal or variable reference
                    currentToken.append(char)
                } else {
                    // Outside arguments - pass through
                    result.append(char)
                }
            }
        }

        // Handle any remaining token
        if !currentToken.isEmpty {
            result.append(currentToken)
        }

        return result
    }

    private func isNumericLiteral(_ token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: .whitespaces)
        // Check if it's a number (int or float) but not a variable reference
        guard !trimmed.isEmpty && !trimmed.hasPrefix("$") else {
            return false
        }
        return Double(trimmed) != nil
    }
}
