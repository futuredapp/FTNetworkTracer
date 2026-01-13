import Foundation

/// Configuration for privacy masking.
///
/// This struct defines the privacy level and exceptions for masking sensitive data.
/// Use it with ``MaskingUtilities`` to mask network trace entries.
///
/// ## Example Usage
///
/// ```swift
/// // Default sensitive masking
/// let config = MaskingConfiguration.sensitive
///
/// // Private masking with exceptions
/// let custom = MaskingConfiguration(
///     privacy: .private,
///     unmaskedHeaders: ["Content-Type", "Accept"],
///     unmaskedUrlQueries: ["page", "limit"],
///     unmaskedBodyParams: ["operationType"]
/// )
///
/// // Mask an entry
/// let masked = MaskingUtilities.mask(entry, configuration: config)
/// ```
public struct MaskingConfiguration: Sendable {
    /// The privacy level for data masking.
    public let privacy: MaskingPrivacy

    /// Whether to mask literal values in GraphQL queries (default: true).
    ///
    /// When enabled, string and numeric literals inside query arguments are replaced
    /// with `***` while preserving query structure and variable references.
    public let maskQueryLiterals: Bool

    /// Header keys that should NOT be masked (case-insensitive).
    public let unmaskedHeaders: Set<String>

    /// URL query parameter keys that should NOT be masked (case-insensitive).
    public let unmaskedUrlQueries: Set<String>

    /// Body/variable parameter keys that should NOT be masked (case-insensitive).
    public let unmaskedBodyParams: Set<String>

    /// Creates a new masking configuration.
    ///
    /// - Parameters:
    ///   - privacy: The privacy level for data masking.
    ///   - maskQueryLiterals: Whether to mask literal values in GraphQL queries (default: true).
    ///   - unmaskedHeaders: Header keys that should NOT be masked.
    ///   - unmaskedUrlQueries: URL query parameter keys that should NOT be masked.
    ///   - unmaskedBodyParams: Body/variable parameter keys that should NOT be masked.
    public init(
        privacy: MaskingPrivacy = .private,
        maskQueryLiterals: Bool = true,
        unmaskedHeaders: Set<String> = [],
        unmaskedUrlQueries: Set<String> = [],
        unmaskedBodyParams: Set<String> = []
    ) {
        self.privacy = privacy
        self.maskQueryLiterals = maskQueryLiterals
        self.unmaskedHeaders = Set(unmaskedHeaders.map { $0.lowercased() })
        self.unmaskedUrlQueries = Set(unmaskedUrlQueries.map { $0.lowercased() })
        self.unmaskedBodyParams = Set(unmaskedBodyParams.map { $0.lowercased() })
    }

    // MARK: - Preset Configurations

    /// No masking - all data is preserved.
    ///
    /// Use only for development and debugging.
    public static let none = MaskingConfiguration(privacy: .none)

    /// Private masking with no exceptions.
    ///
    /// Masks sensitive values but preserves structure.
    public static let `private` = MaskingConfiguration(privacy: .private)

    /// Sensitive masking - aggressive data masking.
    ///
    /// Recommended for production environments.
    public static let sensitive = MaskingConfiguration(privacy: .sensitive)
}
