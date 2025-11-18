import Foundation

/// Authentication request from HawkSight client to Aerie server
///
/// Sent when a client first connects via WebSocket to establish a session.
/// The server validates the token and creates a session if successful.
///
/// Example JSON:
/// ```json
/// {
///   "deviceId": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
///   "token": "secure-authentication-token",
///   "deviceInfo": {
///     "model": "iPhone 14 Pro",
///     "osVersion": "iOS 17.1",
///     "hasLiDAR": true
///   }
/// }
/// ```
struct AuthRequest: Codable {
    /// Unique identifier for the device (typically UUID)
    /// Used to track and identify specific clients across sessions
    let deviceId: String

    /// Authentication token for server validation
    /// In production, this would be a JWT or similar secure token
    let token: String

    /// Device metadata and capabilities
    let deviceInfo: DeviceInfo
}
