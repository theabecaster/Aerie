import Foundation

/// Camera intrinsic parameters for image projection
///
/// Describes the internal optical characteristics of a camera.
/// Used to project 3D world coordinates onto the 2D image plane.
///
/// The intrinsic matrix is:
/// ```
/// [ fx  0  cx ]
/// [  0 fy  cy ]
/// [  0  0   1 ]
/// ```
///
/// Example JSON:
/// ```json
/// {
///   "fx": 1234.5,
///   "fy": 1234.5,
///   "cx": 640.0,
///   "cy": 360.0,
///   "width": 1280,
///   "height": 720
/// }
/// ```
struct CameraIntrinsics: Codable {
    /// Focal length in pixels along the X axis
    /// Typically similar to fy for most cameras
    let fx: Float

    /// Focal length in pixels along the Y axis
    /// Typically similar to fx for most cameras
    let fy: Float

    /// Principal point X coordinate (optical center X)
    /// Usually near width/2
    let cx: Float

    /// Principal point Y coordinate (optical center Y)
    /// Usually near height/2
    let cy: Float

    /// Image width in pixels
    let width: Int

    /// Image height in pixels
    let height: Int
}
