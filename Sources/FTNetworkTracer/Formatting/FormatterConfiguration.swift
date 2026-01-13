import Foundation

/// Configuration for network trace formatting.
///
/// This struct controls how ``NetworkTraceFormatter`` generates output strings.
/// Use the preset configurations (`.default`, `.compact`, `.verbose`) or create
/// a custom configuration for specific needs.
///
/// ## Example Usage
///
/// ```swift
/// // Use default formatting
/// let output = NetworkTraceFormatter.format(entry)
///
/// // Use compact formatting (no headers/body)
/// let compact = NetworkTraceFormatter.format(entry, configuration: .compact)
///
/// // Custom configuration
/// let custom = FormatterConfiguration(
///     includeHeaders: true,
///     includeBody: false,
///     dataDecoder: { String(data: $0, encoding: .utf8) }
/// )
/// let customOutput = NetworkTraceFormatter.format(entry, configuration: custom)
/// ```
public struct FormatterConfiguration: Sendable {
    /// How to decode body data into a string for display.
    ///
    /// The default decoder attempts to pretty-print JSON, falling back to UTF8 string.
    public let dataDecoder: @Sendable (Data) -> String?

    /// Whether to include headers in the formatted output.
    public let includeHeaders: Bool

    /// Whether to include body data in the formatted output.
    public let includeBody: Bool

    /// Maximum number of characters to display for the body (nil = unlimited).
    ///
    /// When set, bodies longer than this limit will be truncated with "... (truncated)".
    public let maxBodyLength: Int?

    /// Creates a new formatter configuration.
    ///
    /// - Parameters:
    ///   - dataDecoder: Closure to decode body data into string. Defaults to pretty JSON with UTF8 fallback.
    ///   - includeHeaders: Whether to include headers in output. Defaults to true.
    ///   - includeBody: Whether to include body in output. Defaults to true.
    ///   - maxBodyLength: Maximum body characters to display. Defaults to nil (unlimited).
    public init(
        dataDecoder: @escaping @Sendable (Data) -> String? = FormatterConfiguration.defaultDataDecoder,
        includeHeaders: Bool = true,
        includeBody: Bool = true,
        maxBodyLength: Int? = nil
    ) {
        self.dataDecoder = dataDecoder
        self.includeHeaders = includeHeaders
        self.includeBody = includeBody
        self.maxBodyLength = maxBodyLength
    }

    // MARK: - Preset Configurations

    /// Default configuration with headers, body, and pretty JSON formatting.
    public static let `default` = FormatterConfiguration()

    /// Compact configuration without headers or body - just the basic request/response info.
    public static let compact = FormatterConfiguration(
        includeHeaders: false,
        includeBody: false
    )

    /// Verbose configuration with unlimited body output.
    public static let verbose = FormatterConfiguration(
        maxBodyLength: nil
    )

    // MARK: - Data Decoders

    /// Default data decoder that tries to format as pretty JSON with UTF8 fallback.
    public static func defaultDataDecoder(_ data: Data) -> String? {
        if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
           let prettyJSON = String(data: prettyData, encoding: .utf8) {
            return prettyJSON
        }
        return String(data: data, encoding: .utf8)
    }

    /// Simple UTF8 decoder without JSON formatting.
    public static func utf8DataDecoder(_ data: Data) -> String? {
        String(data: data, encoding: .utf8)
    }

    /// Decoder that only shows data size, useful for large payloads.
    public static func sizeOnlyDataDecoder(_ data: Data) -> String? {
        "<\(data.count) bytes>"
    }
}
