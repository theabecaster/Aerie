import Foundation
#if canImport(simd)
import simd
#endif

/// 4x4 transformation matrix for pose representation
///
/// Wraps a transformation matrix in a Codable-compatible format.
/// Used to represent device poses, coordinate transforms, etc.
///
/// The matrix is stored as a row-major nested array:
/// ```
/// [
///   [m00, m01, m02, m03],
///   [m10, m11, m12, m13],
///   [m20, m21, m22, m23],
///   [m30, m31, m32, m33]
/// ]
/// ```
///
/// Example JSON:
/// ```json
/// {
///   "matrix": [
///     [1.0, 0.0, 0.0, 0.0],
///     [0.0, 1.0, 0.0, 0.0],
///     [0.0, 0.0, 1.0, 0.0],
///     [0.0, 0.0, 0.0, 1.0]
///   ]
/// }
/// ```
struct PoseMatrix: Codable {
    /// 4x4 transformation matrix as nested array
    /// Row-major format: matrix[row][column]
    let matrix: [[Float]]

    /// Initialize from nested array
    init(matrix: [[Float]]) {
        self.matrix = matrix
    }

    #if canImport(simd)
    /// Initialize from simd_float4x4 (ARKit/SceneKit format)
    init(from simdMatrix: simd_float4x4) {
        self.matrix = [
            [simdMatrix.columns.0.x, simdMatrix.columns.0.y, simdMatrix.columns.0.z, simdMatrix.columns.0.w],
            [simdMatrix.columns.1.x, simdMatrix.columns.1.y, simdMatrix.columns.1.z, simdMatrix.columns.1.w],
            [simdMatrix.columns.2.x, simdMatrix.columns.2.y, simdMatrix.columns.2.z, simdMatrix.columns.2.w],
            [simdMatrix.columns.3.x, simdMatrix.columns.3.y, simdMatrix.columns.3.z, simdMatrix.columns.3.w]
        ]
    }

    /// Convert to simd_float4x4 (ARKit/SceneKit format)
    func toSimd() -> simd_float4x4 {
        return simd_float4x4(
            SIMD4<Float>(matrix[0][0], matrix[0][1], matrix[0][2], matrix[0][3]),
            SIMD4<Float>(matrix[1][0], matrix[1][1], matrix[1][2], matrix[1][3]),
            SIMD4<Float>(matrix[2][0], matrix[2][1], matrix[2][2], matrix[2][3]),
            SIMD4<Float>(matrix[3][0], matrix[3][1], matrix[3][2], matrix[3][3])
        )
    }
    #endif
}
