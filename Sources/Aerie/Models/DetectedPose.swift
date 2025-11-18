import Foundation

/// A complete detected human pose with all joints
///
/// Represents a single person's skeleton detected by the pose estimation system.
/// Contains all 13 tracked joints with their 3D positions and confidence scores.
///
/// Example JSON:
/// ```json
/// {
///   "personId": "person-001",
///   "joints": [
///     {
///       "type": "head",
///       "position": [0.0, 1.7, -2.0],
///       "confidence": 0.98
///     },
///     {
///       "type": "leftShoulder",
///       "position": [-0.2, 1.5, -2.0],
///       "confidence": 0.95
///     }
///   ],
///   "sourceDevice": "iPhone-ABC123",
///   "confidence": 0.92
/// }
/// ```
struct DetectedPose: Codable {
    /// Unique identifier for this person
    /// Used to track individuals across frames
    let personId: String

    /// Array of all detected joints for this person
    /// Should contain up to 13 joints (one for each JointType)
    let joints: [Joint]

    /// Device ID that originally captured the frame where this pose was detected
    /// Used for attribution and debugging
    let sourceDevice: String

    /// Overall pose confidence (0.0 to 1.0)
    /// Typically the average of all joint confidences
    let confidence: Float
}
