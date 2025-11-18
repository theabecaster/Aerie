import Foundation

/// Authentication response from Aerie server to HawkSight client
///
/// Indicates whether authentication was successful and provides a session ID
/// if successful, or an error message if authentication failed.
///
/// Example JSON (success):
/// ```json
/// {
///   "success": true,
///   "sessionId": "session-abc123-def456",
///   "error": null
/// }
/// ```
///
/// Example JSON (failure):
/// ```json
/// {
///   "success": false,
///   "sessionId": null,
///   "error": "Invalid authentication token"
/// }
/// ```
struct AuthResponse: Codable {
    /// Whether authentication was successful
    let success: Bool

    /// Session identifier for authenticated connection
    /// nil if authentication failed
    let sessionId: String?

    /// Error message if authentication failed
    /// nil if authentication succeeded
    let error: String?
}
