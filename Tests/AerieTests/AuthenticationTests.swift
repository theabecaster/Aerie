import XCTest
import Vapor
@testable import Aerie

final class AuthenticationTests: XCTestCase {

    var logger: Logger!
    var sessionManager: SessionManager!
    var authController: AuthController!

    override func setUp() async throws {
        logger = Logger(label: "test")
        sessionManager = SessionManager(sessionTimeout: 3600, logger: logger)
        authController = AuthController(
            sessionManager: sessionManager,
            serverSecret: "test-secret",
            logger: logger
        )
    }

    override func tearDown() async throws {
        authController = nil
        sessionManager = nil
        logger = nil
    }

    // MARK: - Token Generation Tests

    func testGenerateToken() throws {
        let deviceId = "test-device-1"

        let token = authController.generateToken(for: deviceId)

        XCTAssertFalse(token.isEmpty, "Token should not be empty")
        XCTAssertGreaterThan(token.count, 16, "Token should be reasonably long")
    }

    func testGenerateTokenUniqueness() throws {
        let deviceId = "test-device-1"

        let token1 = authController.generateToken(for: deviceId)
        let token2 = authController.generateToken(for: deviceId)

        // Tokens should always be unique due to nonce and high-precision timestamp
        XCTAssertNotEqual(token1, token2, "Tokens should be unique even when generated immediately")
    }

    // MARK: - Token Validation Tests

    func testValidateValidToken() throws {
        let deviceId = "test-device-1"
        let token = authController.generateToken(for: deviceId)

        let isValid = authController.validateToken(token)

        XCTAssertTrue(isValid, "Generated token should be valid")
    }

    func testValidateEmptyToken() throws {
        let isValid = authController.validateToken("")

        XCTAssertFalse(isValid, "Empty token should be invalid")
    }

    func testValidateShortToken() throws {
        let isValid = authController.validateToken("short")

        XCTAssertFalse(isValid, "Short token should be invalid")
    }

    func testValidateNonBase64Token() throws {
        let isValid = authController.validateToken("this-is-not-base64!@#$%^&*()")

        XCTAssertFalse(isValid, "Non-base64 token should be invalid")
    }

    func testValidateValidBase64Token() throws {
        // Valid base64 string (64 chars)
        let validBase64 = "dGhpcyBpcyBhIHZhbGlkIGJhc2U2NCBlbmNvZGVkIHN0cmluZyB0aGF0IGlzIGxvbmcgZW5vdWdo"

        let isValid = authController.validateToken(validBase64)

        XCTAssertTrue(isValid, "Valid base64 token should be valid")
    }

    // MARK: - Authentication Request Handling Tests

    func testHandleAuthRequestSuccess() async throws {
        let deviceId = "test-device-1"
        let token = authController.generateToken(for: deviceId)

        let deviceInfo = DeviceInfo(
            model: "iPhone 15 Pro",
            osVersion: "iOS 17.0",
            hasLiDAR: true
        )

        let authRequest = AuthRequest(
            deviceId: "iPhone 15 Pro",
            token: token,
            deviceInfo: deviceInfo
        )

        let response = await authController.handleAuthRequest(authRequest, deviceId: deviceId)

        XCTAssertTrue(response.success, "Auth should succeed")
        XCTAssertNotNil(response.sessionId, "Session ID should be provided")
        XCTAssertNil(response.error, "Error should be nil on success")
    }

    func testHandleAuthRequestInvalidToken() async throws {
        let deviceId = "test-device-1"
        let invalidToken = "invalid"

        let deviceInfo = DeviceInfo(
            model: "iPhone 15 Pro",
            osVersion: "iOS 17.0",
            hasLiDAR: true
        )

        let authRequest = AuthRequest(
            deviceId: "iPhone 15 Pro",
            token: invalidToken,
            deviceInfo: deviceInfo
        )

        let response = await authController.handleAuthRequest(authRequest, deviceId: deviceId)

        XCTAssertFalse(response.success, "Auth should fail with invalid token")
        XCTAssertNil(response.sessionId, "Session ID should not be provided")
        XCTAssertNotNil(response.error, "Error message should be provided")
        XCTAssertTrue(response.error?.contains("Invalid") ?? false, "Error message should mention invalid token")
    }

    func testHandleAuthRequestCreatesSession() async throws {
        let deviceId = "test-device-1"
        let token = authController.generateToken(for: deviceId)

        let deviceInfo = DeviceInfo(
            model: "iPhone 15 Pro",
            osVersion: "iOS 17.0",
            hasLiDAR: true
        )

        let authRequest = AuthRequest(
            deviceId: "iPhone 15 Pro",
            token: token,
            deviceInfo: deviceInfo
        )

        let response = await authController.handleAuthRequest(authRequest, deviceId: deviceId)

        XCTAssertTrue(response.success)

        // Verify session was created
        let sessionId = try XCTUnwrap(response.sessionId as String?)
        let session = await sessionManager.validateSession(sessionId)

        XCTAssertNotNil(session, "Session should exist")
        XCTAssertEqual(session?.deviceId, deviceId, "Session should be for correct device")
    }

    func testHandleAuthRequestReuseExistingSession() async throws {
        let deviceId = "test-device-1"
        let token = authController.generateToken(for: deviceId)

        let deviceInfo = DeviceInfo(
            model: "iPhone 15 Pro",
            osVersion: "iOS 17.0",
            hasLiDAR: true
        )

        let authRequest = AuthRequest(
            deviceId: "iPhone 15 Pro",
            token: token,
            deviceInfo: deviceInfo
        )

        // First authentication
        let response1 = await authController.handleAuthRequest(authRequest, deviceId: deviceId)
        let sessionId1 = try XCTUnwrap(response1.sessionId as String?)

        // Second authentication (should reuse session)
        let response2 = await authController.handleAuthRequest(authRequest, deviceId: deviceId)
        let sessionId2 = try XCTUnwrap(response2.sessionId as String?)

        XCTAssertEqual(sessionId1, sessionId2, "Should reuse existing session")
        XCTAssertNil(response2.error, "Error should be nil on success")
    }

    // MARK: - Session Verification Tests

    func testVerifySessionValid() async throws {
        let deviceId = "test-device-1"
        let token = authController.generateToken(for: deviceId)

        let session = await sessionManager.createSession(deviceId: deviceId, token: token)

        let isValid = await authController.verifySession(session.id)

        XCTAssertTrue(isValid, "Session should be valid")
    }

    func testVerifySessionInvalid() async throws {
        let isValid = await authController.verifySession("non-existent-session")

        XCTAssertFalse(isValid, "Non-existent session should be invalid")
    }

    func testGetDeviceIdFromSession() async throws {
        let deviceId = "test-device-1"
        let token = authController.generateToken(for: deviceId)

        let session = await sessionManager.createSession(deviceId: deviceId, token: token)

        let retrievedDeviceId = await authController.getDeviceId(forSession: session.id)

        XCTAssertEqual(retrievedDeviceId, deviceId, "Should retrieve correct device ID")
    }

    func testGetDeviceIdFromInvalidSession() async throws {
        let retrievedDeviceId = await authController.getDeviceId(forSession: "non-existent-session")

        XCTAssertNil(retrievedDeviceId, "Should return nil for invalid session")
    }

    // MARK: - Multiple Device Tests

    func testMultipleDevicesAuthenticate() async throws {
        let devices = ["device-1", "device-2", "device-3"]
        var sessionIds: [String] = []

        for deviceId in devices {
            let token = authController.generateToken(for: deviceId)

            let deviceInfo = DeviceInfo(
                model: "iPhone 15 Pro",
                osVersion: "iOS 17.0",
                hasLiDAR: true
            )

            let authRequest = AuthRequest(
                deviceId: "iPhone 15 Pro",
                token: token,
                deviceInfo: deviceInfo
            )

            let response = await authController.handleAuthRequest(authRequest, deviceId: deviceId)

            XCTAssertTrue(response.success)
            sessionIds.append(try XCTUnwrap(response.sessionId))
        }

        // Verify all sessions are unique
        let uniqueSessionIds = Set(sessionIds)
        XCTAssertEqual(uniqueSessionIds.count, 3, "All session IDs should be unique")

        // Verify all sessions are valid
        for sessionId in sessionIds {
            let isValid = await authController.verifySession(sessionId)
            XCTAssertTrue(isValid, "All sessions should be valid")
        }
    }

    // MARK: - Security Tests

    func testTokensAreDifferentForDifferentDevices() throws {
        let device1 = "device-1"
        let device2 = "device-2"

        let token1 = authController.generateToken(for: device1)
        let token2 = authController.generateToken(for: device2)

        XCTAssertNotEqual(token1, token2, "Different devices should get different tokens")
    }

    func testEmptyDeviceIdGeneratesToken() throws {
        // Should still generate a token, even with empty device ID
        let token = authController.generateToken(for: "")

        XCTAssertFalse(token.isEmpty, "Should generate token even with empty device ID")
    }

    // MARK: - Integration Tests

    func testCompleteAuthFlow() async throws {
        // Step 1: Generate token
        let deviceId = "test-device-1"
        let token = authController.generateToken(for: deviceId)

        // Step 2: Validate token format
        XCTAssertTrue(authController.validateToken(token))

        // Step 3: Create auth request
        let deviceInfo = DeviceInfo(
            model: "iPhone 15 Pro",
            osVersion: "iOS 17.0",
            hasLiDAR: true
        )

        let authRequest = AuthRequest(
            deviceId: "iPhone 15 Pro",
            token: token,
            deviceInfo: deviceInfo
        )

        // Step 4: Handle authentication
        let response = await authController.handleAuthRequest(authRequest, deviceId: deviceId)

        XCTAssertTrue(response.success)
        let sessionId = try XCTUnwrap(response.sessionId as String?)

        // Step 5: Verify session
        let isValid = await authController.verifySession(sessionId)
        XCTAssertTrue(isValid)

        // Step 6: Get device ID from session
        let retrievedDeviceId = await authController.getDeviceId(forSession: sessionId)
        XCTAssertEqual(retrievedDeviceId, deviceId)

        // Step 7: Verify session in session manager
        let session = await sessionManager.validateSession(sessionId)
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.deviceId, deviceId)
        XCTAssertEqual(session?.token, token)
    }
}
