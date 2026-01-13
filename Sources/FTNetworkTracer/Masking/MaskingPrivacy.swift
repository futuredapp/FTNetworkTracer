import Foundation

/// Privacy levels for data masking.
///
/// This enum defines the different levels of privacy for masking sensitive data.
/// Each level determines how aggressively data is masked.
///
/// ## Privacy Levels
///
/// - `none`: No masking applied. Use only for development/debugging.
/// - `private`: Selective masking. Masks sensitive data but allows exceptions.
/// - `sensitive`: Aggressive masking. Masks all user-specific data.
///
/// ## Example Usage
///
/// ```swift
/// // For development
/// let devConfig = MaskingConfiguration(privacy: .none)
///
/// // For production with some exceptions
/// let prodConfig = MaskingConfiguration(
///     privacy: .private,
///     unmaskedHeaders: ["Content-Type"]
/// )
///
/// // For maximum privacy
/// let strictConfig = MaskingConfiguration(privacy: .sensitive)
/// ```
public enum MaskingPrivacy: Sendable {
    /// No privacy masking - all data is preserved.
    ///
    /// Use this only for development and debugging. Never use in production.
    case none

    /// Private masking - sensitive data in headers, URL queries and body is masked.
    ///
    /// Exceptions can be specified via `MaskingConfiguration`.
    case `private`

    /// Sensitive masking - all user-specific data is masked.
    ///
    /// This is the recommended setting for production environments.
    case sensitive
}
