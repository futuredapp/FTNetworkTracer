import Foundation

/// Utilities for applying privacy masking to network trace data.
///
/// Use these utilities to mask sensitive information before sending
/// network trace data to analytics services.
///
/// ## Example Usage
///
/// ```swift
/// let entry = NetworkTraceEntry(
///     type: .request(method: "POST", url: "https://api.example.com?token=secret"),
///     headers: ["Authorization": "Bearer abc123"],
///     body: jsonData,
///     requestId: UUID().uuidString
/// )
///
/// // Mask the entire entry
/// let masked = MaskingUtilities.mask(entry, configuration: .sensitive)
///
/// // Or mask individual components
/// let maskedURL = MaskingUtilities.maskURL(url, configuration: config)
/// let maskedHeaders = MaskingUtilities.maskHeaders(headers, configuration: config)
/// ```
public enum MaskingUtilities {
    /// The string used to replace masked values.
    public static let maskedValue = "***"

    /// Returns a new entry with masked data based on configuration.
    ///
    /// - Parameters:
    ///   - entry: The original network trace entry
    ///   - configuration: The masking configuration to apply
    /// - Returns: A new entry with masked data
    public static func mask(
        _ entry: NetworkTraceEntry,
        configuration: MaskingConfiguration
    ) -> NetworkTraceEntry {
        let maskedURL = maskURLInEntryType(entry.type, configuration: configuration)

        return NetworkTraceEntry(
            type: maskedURL,
            headers: maskHeaders(entry.headers, configuration: configuration),
            body: maskBody(entry.body, configuration: configuration),
            timestamp: entry.timestamp,
            duration: entry.duration,
            requestId: entry.requestId,
            operationName: entry.operationName,
            query: maskQuery(entry.query, configuration: configuration),
            variables: maskVariables(entry.variables, configuration: configuration)
        )
    }

    // MARK: - Individual Masking Functions

    /// Masks a URL based on configuration.
    ///
    /// - Parameters:
    ///   - url: The URL string to mask
    ///   - configuration: The masking configuration
    /// - Returns: The masked URL string
    public static func maskURL(_ url: String, configuration: MaskingConfiguration) -> String {
        switch configuration.privacy {
        case .none:
            return url
        case .private:
            return maskPrivateUrlQueries(url, configuration: configuration)
        case .sensitive:
            return maskSensitiveUrlQueries(url)
        }
    }

    /// Masks headers based on configuration.
    ///
    /// - Parameters:
    ///   - headers: The headers to mask
    ///   - configuration: The masking configuration
    /// - Returns: The masked headers, or nil if input was nil
    public static func maskHeaders(
        _ headers: [String: String]?,
        configuration: MaskingConfiguration
    ) -> [String: String]? {
        guard let headers else { return nil }

        switch configuration.privacy {
        case .none:
            return headers
        case .private:
            var maskedHeaders: [String: String] = [:]
            for (key, value) in headers {
                if configuration.unmaskedHeaders.contains(key.lowercased()) {
                    maskedHeaders[key] = value
                } else {
                    maskedHeaders[key] = maskedValue
                }
            }
            return maskedHeaders
        case .sensitive:
            return headers.mapValues { _ in maskedValue }
        }
    }

    /// Masks body data based on configuration.
    ///
    /// - Parameters:
    ///   - body: The body data to mask
    ///   - configuration: The masking configuration
    /// - Returns: The masked body data, or nil for sensitive privacy
    public static func maskBody(
        _ body: Data?,
        configuration: MaskingConfiguration
    ) -> Data? {
        guard let body else { return nil }

        switch configuration.privacy {
        case .none:
            return body
        case .private:
            return maskPrivateBodyParams(body, configuration: configuration)
        case .sensitive:
            return nil
        }
    }

    /// Masks GraphQL variables based on configuration.
    ///
    /// - Parameters:
    ///   - variables: The variables to mask
    ///   - configuration: The masking configuration
    /// - Returns: The masked variables, or nil for sensitive privacy
    public static func maskVariables(
        _ variables: [String: any Sendable]?,
        configuration: MaskingConfiguration
    ) -> [String: any Sendable]? {
        guard let variables else { return nil }

        switch configuration.privacy {
        case .none:
            return variables
        case .private:
            let anyVariables = Dictionary(uniqueKeysWithValues: variables.map { ($0.key, $0.value as Any) })
            return recursivelyMask(anyVariables, configuration: configuration) as? [String: any Sendable]
        case .sensitive:
            return nil
        }
    }

    /// Masks a GraphQL query based on configuration.
    ///
    /// - Parameters:
    ///   - query: The GraphQL query string to mask
    ///   - configuration: The masking configuration
    /// - Returns: The masked query, or nil for sensitive privacy
    public static func maskQuery(
        _ query: String?,
        configuration: MaskingConfiguration
    ) -> String? {
        guard let query else { return nil }

        switch configuration.privacy {
        case .none, .private:
            return configuration.maskQueryLiterals ? QueryLiteralMasker(query: query).maskedQuery : query
        case .sensitive:
            return nil
        }
    }

    // MARK: - Private Helpers

    private static func maskURLInEntryType(
        _ type: EntryType,
        configuration: MaskingConfiguration
    ) -> EntryType {
        switch type {
        case let .request(method, url):
            return .request(method: method, url: maskURL(url, configuration: configuration))
        case let .response(method, url, statusCode):
            return .response(method: method, url: maskURL(url, configuration: configuration), statusCode: statusCode)
        case let .error(method, url, error):
            return .error(method: method, url: maskURL(url, configuration: configuration), error: error)
        }
    }

    private static func maskPrivateUrlQueries(_ url: String, configuration: MaskingConfiguration) -> String {
        guard let urlComponents = URLComponents(string: url),
              let queryItems = urlComponents.queryItems else {
            return url
        }

        let maskedQueryItems = queryItems.map { item -> URLQueryItem in
            if configuration.unmaskedUrlQueries.contains(item.name.lowercased()) {
                return item
            }
            return URLQueryItem(name: item.name, value: maskedValue)
        }

        var maskedComponents = urlComponents
        maskedComponents.queryItems = maskedQueryItems
        return maskedComponents.url?.absoluteString ?? url
    }

    private static func maskSensitiveUrlQueries(_ url: String) -> String {
        guard let urlComponents = URLComponents(string: url) else {
            return url
        }

        var maskedComponents = urlComponents
        maskedComponents.query = nil

        return maskedComponents.url?.absoluteString ?? url
    }

    private static func maskPrivateBodyParams(_ body: Data, configuration: MaskingConfiguration) -> Data? {
        guard let json = try? JSONSerialization.jsonObject(with: body) else {
            return Data(maskedValue.utf8)
        }

        let maskedJson = recursivelyMask(json, configuration: configuration)

        return try? JSONSerialization.data(withJSONObject: maskedJson)
    }

    private static func recursivelyMask(_ data: Any, configuration: MaskingConfiguration) -> Any {
        if let dictionary = data as? [String: any Sendable] {
            var newDict: [String: Any] = [:]
            for (key, value) in dictionary {
                if configuration.unmaskedBodyParams.contains(key.lowercased()) {
                    newDict[key] = value
                } else {
                    newDict[key] = recursivelyMask(value, configuration: configuration)
                }
            }
            return newDict
        } else if let array = data as? [Any] {
            return array.map { recursivelyMask($0, configuration: configuration) }
        } else {
            return maskedValue
        }
    }
}
