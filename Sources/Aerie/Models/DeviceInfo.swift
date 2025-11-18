import Foundation

/// Device metadata for client identification
///
/// Contains hardware and software information about the HawkSight client device.
/// This information is used for capability detection and debugging.
///
/// Example JSON:
/// ```json
/// {
///   "model": "iPhone 14 Pro",
///   "osVersion": "iOS 17.1",
///   "hasLiDAR": true
/// }
/// ```
struct DeviceInfo: Codable {
    /// Device model name (e.g., "iPhone 14 Pro", "iPhone 15 Pro Max")
    let model: String

    /// Operating system version (e.g., "iOS 17.1", "iOS 18.0")
    let osVersion: String

    /// Whether the device has LiDAR capabilities
    /// Required for depth sensing and accurate spatial mapping
    let hasLiDAR: Bool
}
