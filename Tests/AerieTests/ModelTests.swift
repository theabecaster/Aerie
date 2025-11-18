import XCTest
@testable import Aerie
#if canImport(simd)
import simd
#endif

/// Comprehensive test suite for all FalconEye data models
///
/// Tests serialization, deserialization, and round-trip consistency
/// for all models used in network communication.
final class ModelTests: XCTestCase {

    // MARK: - DeviceInfo Tests

    func testDeviceInfoEncodeDecode() throws {
        let deviceInfo = DeviceInfo(
            model: "iPhone 14 Pro",
            osVersion: "iOS 17.1",
            hasLiDAR: true
        )

        let encoded = try JSONEncoder().encode(deviceInfo)
        let decoded = try JSONDecoder().decode(DeviceInfo.self, from: encoded)

        XCTAssertEqual(decoded.model, "iPhone 14 Pro")
        XCTAssertEqual(decoded.osVersion, "iOS 17.1")
        XCTAssertEqual(decoded.hasLiDAR, true)
    }

    func testDeviceInfoJSONFormat() throws {
        let deviceInfo = DeviceInfo(
            model: "iPhone 15 Pro Max",
            osVersion: "iOS 18.0",
            hasLiDAR: true
        )

        let encoded = try JSONEncoder().encode(deviceInfo)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["model"] as? String, "iPhone 15 Pro Max")
        XCTAssertEqual(json?["osVersion"] as? String, "iOS 18.0")
        XCTAssertEqual(json?["hasLiDAR"] as? Bool, true)
    }

    // MARK: - AuthRequest Tests

    func testAuthRequestEncodeDecode() throws {
        let deviceInfo = DeviceInfo(
            model: "iPhone 14 Pro",
            osVersion: "iOS 17.1",
            hasLiDAR: true
        )

        let authRequest = AuthRequest(
            deviceId: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
            token: "test-token-123",
            deviceInfo: deviceInfo
        )

        let encoded = try JSONEncoder().encode(authRequest)
        let decoded = try JSONDecoder().decode(AuthRequest.self, from: encoded)

        XCTAssertEqual(decoded.deviceId, "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")
        XCTAssertEqual(decoded.token, "test-token-123")
        XCTAssertEqual(decoded.deviceInfo.model, "iPhone 14 Pro")
    }

    // MARK: - AuthResponse Tests

    func testAuthResponseSuccessEncodeDecode() throws {
        let response = AuthResponse(
            success: true,
            sessionId: "session-abc123",
            error: nil
        )

        let encoded = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(AuthResponse.self, from: encoded)

        XCTAssertTrue(decoded.success)
        XCTAssertEqual(decoded.sessionId, "session-abc123")
        XCTAssertNil(decoded.error)
    }

    func testAuthResponseFailureEncodeDecode() throws {
        let response = AuthResponse(
            success: false,
            sessionId: nil,
            error: "Invalid token"
        )

        let encoded = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(AuthResponse.self, from: encoded)

        XCTAssertFalse(decoded.success)
        XCTAssertNil(decoded.sessionId)
        XCTAssertEqual(decoded.error, "Invalid token")
    }

    // MARK: - MessageType Tests

    func testMessageTypeEncodeDecode() throws {
        let types: [MessageType] = [.authRequest, .authResponse, .cameraFrame, .poseBroadcast]

        for type in types {
            let encoded = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(MessageType.self, from: encoded)
            XCTAssertEqual(decoded, type)
        }
    }

    // MARK: - Message Tests

    func testMessageEncodeDecode() throws {
        let deviceInfo = DeviceInfo(model: "iPhone 14 Pro", osVersion: "iOS 17.1", hasLiDAR: true)
        let authRequest = AuthRequest(deviceId: "test-device", token: "test-token", deviceInfo: deviceInfo)
        let payloadData = try JSONEncoder().encode(authRequest)

        let message = Message(
            type: .authRequest,
            timestamp: 1704067200.0,
            payload: payloadData
        )

        let encoded = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(Message.self, from: encoded)

        XCTAssertEqual(decoded.type, .authRequest)
        XCTAssertEqual(decoded.timestamp, 1704067200.0)

        // Verify payload can be decoded back to AuthRequest
        let decodedPayload = try JSONDecoder().decode(AuthRequest.self, from: decoded.payload)
        XCTAssertEqual(decodedPayload.deviceId, "test-device")
    }

    // MARK: - CameraIntrinsics Tests

    func testCameraIntrinsicsEncodeDecode() throws {
        let intrinsics = CameraIntrinsics(
            fx: 1234.5,
            fy: 1234.5,
            cx: 640.0,
            cy: 360.0,
            width: 1280,
            height: 720
        )

        let encoded = try JSONEncoder().encode(intrinsics)
        let decoded = try JSONDecoder().decode(CameraIntrinsics.self, from: encoded)

        XCTAssertEqual(decoded.fx, 1234.5)
        XCTAssertEqual(decoded.fy, 1234.5)
        XCTAssertEqual(decoded.cx, 640.0)
        XCTAssertEqual(decoded.cy, 360.0)
        XCTAssertEqual(decoded.width, 1280)
        XCTAssertEqual(decoded.height, 720)
    }

    // MARK: - CameraFrame Tests

    func testCameraFrameEncodeDecode() throws {
        let intrinsics = CameraIntrinsics(fx: 1234.5, fy: 1234.5, cx: 640.0, cy: 360.0, width: 1280, height: 720)

        let cameraFrame = CameraFrame(
            frameId: "frame-12345",
            timestamp: 1704067200.123,
            imageData: "base64-encoded-jpeg-data",
            devicePose: [
                [1.0, 0.0, 0.0, 0.0],
                [0.0, 1.0, 0.0, 0.0],
                [0.0, 0.0, 1.0, 0.0],
                [0.0, 0.0, 0.0, 1.0]
            ],
            intrinsics: intrinsics
        )

        let encoded = try JSONEncoder().encode(cameraFrame)
        let decoded = try JSONDecoder().decode(CameraFrame.self, from: encoded)

        XCTAssertEqual(decoded.frameId, "frame-12345")
        XCTAssertEqual(decoded.timestamp, 1704067200.123)
        XCTAssertEqual(decoded.imageData, "base64-encoded-jpeg-data")
        XCTAssertEqual(decoded.devicePose.count, 4)
        XCTAssertEqual(decoded.devicePose[0].count, 4)
        XCTAssertEqual(decoded.intrinsics.width, 1280)
    }

    // MARK: - JointType Tests

    func testJointTypeEncodeDecode() throws {
        let jointTypes: [JointType] = [
            .head, .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow, .leftWrist, .rightWrist,
            .leftHip, .rightHip, .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]

        for jointType in jointTypes {
            let encoded = try JSONEncoder().encode(jointType)
            let decoded = try JSONDecoder().decode(JointType.self, from: encoded)
            XCTAssertEqual(decoded, jointType)
        }
    }

    // MARK: - Joint Tests

    func testJointEncodeDecode() throws {
        let joint = Joint(
            type: .leftWrist,
            position: [1.2, 0.8, -2.5],
            confidence: 0.95
        )

        let encoded = try JSONEncoder().encode(joint)
        let decoded = try JSONDecoder().decode(Joint.self, from: encoded)

        XCTAssertEqual(decoded.type, .leftWrist)
        XCTAssertEqual(decoded.position, [1.2, 0.8, -2.5])
        XCTAssertEqual(decoded.confidence, 0.95)
    }

    // MARK: - DetectedPose Tests

    func testDetectedPoseEncodeDecode() throws {
        let joints = [
            Joint(type: .head, position: [0.0, 1.7, -2.0], confidence: 0.98),
            Joint(type: .leftShoulder, position: [-0.2, 1.5, -2.0], confidence: 0.95),
            Joint(type: .rightShoulder, position: [0.2, 1.5, -2.0], confidence: 0.96)
        ]

        let pose = DetectedPose(
            personId: "person-001",
            joints: joints,
            sourceDevice: "iPhone-ABC123",
            confidence: 0.93
        )

        let encoded = try JSONEncoder().encode(pose)
        let decoded = try JSONDecoder().decode(DetectedPose.self, from: encoded)

        XCTAssertEqual(decoded.personId, "person-001")
        XCTAssertEqual(decoded.joints.count, 3)
        XCTAssertEqual(decoded.joints[0].type, .head)
        XCTAssertEqual(decoded.sourceDevice, "iPhone-ABC123")
        XCTAssertEqual(decoded.confidence, 0.93)
    }

    // MARK: - PoseBroadcast Tests

    func testPoseBroadcastEncodeDecode() throws {
        let joints = [
            Joint(type: .head, position: [0.0, 1.7, -2.0], confidence: 0.98)
        ]

        let poses = [
            DetectedPose(personId: "person-001", joints: joints, sourceDevice: "iPhone-1", confidence: 0.92),
            DetectedPose(personId: "person-002", joints: joints, sourceDevice: "iPhone-2", confidence: 0.88)
        ]

        let broadcast = PoseBroadcast(
            timestamp: 1704067200.456,
            poses: poses
        )

        let encoded = try JSONEncoder().encode(broadcast)
        let decoded = try JSONDecoder().decode(PoseBroadcast.self, from: encoded)

        XCTAssertEqual(decoded.timestamp, 1704067200.456)
        XCTAssertEqual(decoded.poses.count, 2)
        XCTAssertEqual(decoded.poses[0].personId, "person-001")
        XCTAssertEqual(decoded.poses[1].personId, "person-002")
    }

    func testPoseBroadcastEmptyPoses() throws {
        let broadcast = PoseBroadcast(
            timestamp: 1704067200.0,
            poses: []
        )

        let encoded = try JSONEncoder().encode(broadcast)
        let decoded = try JSONDecoder().decode(PoseBroadcast.self, from: encoded)

        XCTAssertEqual(decoded.timestamp, 1704067200.0)
        XCTAssertEqual(decoded.poses.count, 0)
    }

    // MARK: - PoseMatrix Tests

    func testPoseMatrixEncodeDecode() throws {
        let identityMatrix: [[Float]] = [
            [1.0, 0.0, 0.0, 0.0],
            [0.0, 1.0, 0.0, 0.0],
            [0.0, 0.0, 1.0, 0.0],
            [0.0, 0.0, 0.0, 1.0]
        ]

        let poseMatrix = PoseMatrix(matrix: identityMatrix)

        let encoded = try JSONEncoder().encode(poseMatrix)
        let decoded = try JSONDecoder().decode(PoseMatrix.self, from: encoded)

        XCTAssertEqual(decoded.matrix.count, 4)
        XCTAssertEqual(decoded.matrix[0].count, 4)
        XCTAssertEqual(decoded.matrix[0][0], 1.0)
        XCTAssertEqual(decoded.matrix[1][1], 1.0)
        XCTAssertEqual(decoded.matrix[2][2], 1.0)
        XCTAssertEqual(decoded.matrix[3][3], 1.0)
    }

    #if canImport(simd)
    func testPoseMatrixSimdConversion() throws {
        let simdMatrix = simd_float4x4(
            SIMD4<Float>(1.0, 0.0, 0.0, 0.0),
            SIMD4<Float>(0.0, 1.0, 0.0, 0.0),
            SIMD4<Float>(0.0, 0.0, 1.0, 0.0),
            SIMD4<Float>(0.5, 0.5, 0.5, 1.0)
        )

        let poseMatrix = PoseMatrix(from: simdMatrix)
        let backToSimd = poseMatrix.toSimd()

        // Verify round-trip conversion
        XCTAssertEqual(backToSimd.columns.0.x, simdMatrix.columns.0.x)
        XCTAssertEqual(backToSimd.columns.3.x, 0.5)
        XCTAssertEqual(backToSimd.columns.3.y, 0.5)
        XCTAssertEqual(backToSimd.columns.3.z, 0.5)
    }
    #endif

    // MARK: - Round-trip Tests

    func testCompleteMessageRoundTrip() throws {
        // Create a complete message with CameraFrame payload
        let intrinsics = CameraIntrinsics(fx: 1000.0, fy: 1000.0, cx: 640.0, cy: 360.0, width: 1280, height: 720)
        let cameraFrame = CameraFrame(
            frameId: "test-frame",
            timestamp: Date().timeIntervalSince1970,
            imageData: "base64data",
            devicePose: [
                [1.0, 0.0, 0.0, 0.0],
                [0.0, 1.0, 0.0, 0.0],
                [0.0, 0.0, 1.0, 0.0],
                [0.0, 0.0, 0.0, 1.0]
            ],
            intrinsics: intrinsics
        )

        let payloadData = try JSONEncoder().encode(cameraFrame)
        let message = Message(type: .cameraFrame, timestamp: Date().timeIntervalSince1970, payload: payloadData)

        // Encode to JSON
        let encoded = try JSONEncoder().encode(message)

        // Decode from JSON
        let decoded = try JSONDecoder().decode(Message.self, from: encoded)

        // Verify message structure
        XCTAssertEqual(decoded.type, .cameraFrame)

        // Decode payload
        let decodedFrame = try JSONDecoder().decode(CameraFrame.self, from: decoded.payload)
        XCTAssertEqual(decodedFrame.frameId, "test-frame")
        XCTAssertEqual(decodedFrame.intrinsics.width, 1280)
    }
}
