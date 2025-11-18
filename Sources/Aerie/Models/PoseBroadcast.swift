import Foundation

/// Broadcast message containing all detected poses
///
/// Sent from Aerie server to all connected HawkSight clients.
/// Contains poses from all devices, transformed to the shared world frame.
///
/// Example JSON:
/// ```json
/// {
///   "timestamp": 1704067200.456,
///   "poses": [
///     {
///       "personId": "person-001",
///       "joints": [...],
///       "sourceDevice": "iPhone-ABC123",
///       "confidence": 0.92
///     },
///     {
///       "personId": "person-002",
///       "joints": [...],
///       "sourceDevice": "iPhone-DEF456",
///       "confidence": 0.88
///     }
///   ]
/// }
/// ```
struct PoseBroadcast: Codable {
    /// Unix timestamp (seconds since epoch) when broadcast was created
    let timestamp: Double

    /// Array of all currently detected poses across all devices
    /// Can be empty if no people are currently detected
    /// Typically contains 0-3+ poses depending on the scene
    let poses: [DetectedPose]
}
