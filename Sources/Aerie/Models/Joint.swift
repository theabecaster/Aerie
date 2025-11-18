import Foundation

/// Joint type enumeration for human pose skeleton
///
/// Defines the 13 key joints tracked by the pose detection system.
/// Based on standard human pose estimation models (similar to MediaPipe).
enum JointType: String, Codable {
    case head
    case leftShoulder
    case rightShoulder
    case leftElbow
    case rightElbow
    case leftWrist
    case rightWrist
    case leftHip
    case rightHip
    case leftKnee
    case rightKnee
    case leftAnkle
    case rightAnkle
}

/// A single joint in a detected human pose
///
/// Represents a 3D point in world space with associated confidence.
/// Joints are connected to form a complete skeleton.
///
/// Example JSON:
/// ```json
/// {
///   "type": "leftWrist",
///   "position": [1.2, 0.8, -2.5],
///   "confidence": 0.95
/// }
/// ```
struct Joint: Codable {
    /// Type of joint (e.g., leftWrist, rightKnee)
    let type: JointType

    /// 3D position in world coordinates [x, y, z]
    /// Units are meters in the shared world frame
    let position: [Float]

    /// Detection confidence (0.0 to 1.0)
    /// Higher values indicate more reliable detection
    /// Threshold of 0.5 is typically used to filter out low-confidence joints
    let confidence: Float
}
