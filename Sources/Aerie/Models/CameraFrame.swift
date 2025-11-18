import Foundation

/// Camera frame data captured by HawkSight client
///
/// Contains the image data, device pose, and camera parameters needed
/// for pose detection and coordinate transformation.
///
/// Example JSON:
/// ```json
/// {
///   "frameId": "frame-12345-67890",
///   "timestamp": 1704067200.123,
///   "imageData": "/9j/4AAQSkZJRgABAQAA...",
///   "devicePose": [
///     [1.0, 0.0, 0.0, 0.0],
///     [0.0, 1.0, 0.0, 0.0],
///     [0.0, 0.0, 1.0, 0.0],
///     [0.0, 0.0, 0.0, 1.0]
///   ],
///   "intrinsics": {
///     "fx": 1234.5,
///     "fy": 1234.5,
///     "cx": 640.0,
///     "cy": 360.0,
///     "width": 1280,
///     "height": 720
///   }
/// }
/// ```
struct CameraFrame: Codable {
    /// Unique identifier for this frame
    /// Used for tracking and debugging
    let frameId: String

    /// Unix timestamp (seconds since epoch) when frame was captured
    let timestamp: Double

    /// Base64-encoded JPEG image data
    /// Decoded on server for pose detection
    let imageData: String

    /// 4x4 transformation matrix representing device pose in world coordinates
    /// Row-major nested array format: [[Float]]
    /// Represents the device's position and orientation in ARKit world space
    let devicePose: [[Float]]

    /// Camera intrinsic parameters for this frame
    /// Used to project detected 3D poses onto the 2D image
    let intrinsics: CameraIntrinsics
}
