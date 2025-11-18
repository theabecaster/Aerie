import XCTest
import Vapor
@testable import Aerie

final class SessionManagerTests: XCTestCase {

    var logger: Logger!
    var sessionManager: SessionManager!

    override func setUp() async throws {
        logger = Logger(label: "test")
        sessionManager = SessionManager(sessionTimeout: 3600, logger: logger)
    }

    override func tearDown() async throws {
        sessionManager = nil
        logger = nil
    }

    // MARK: - Session Creation Tests

    func testCreateSession() async throws {
        let deviceId = "test-device-1"
        let token = "test-token-123"

        let session = await sessionManager.createSession(deviceId: deviceId, token: token)

        XCTAssertEqual(session.deviceId, deviceId)
        XCTAssertEqual(session.token, token)
        XCTAssertFalse(session.id.isEmpty)
        XCTAssertTrue(session.isValid)
        XCTAssertFalse(session.isExpired)
    }

    func testCreateSessionReplacesExisting() async throws {
        let deviceId = "test-device-1"
        let token1 = "token-1"
        let token2 = "token-2"

        let session1 = await sessionManager.createSession(deviceId: deviceId, token: token1)
        let session2 = await sessionManager.createSession(deviceId: deviceId, token: token2)

        XCTAssertNotEqual(session1.id, session2.id)
        XCTAssertEqual(session2.token, token2)

        // First session should no longer be valid
        let validated = await sessionManager.validateSession(session1.id)
        XCTAssertNil(validated)
    }

    // MARK: - Session Validation Tests

    func testValidateSession() async throws {
        let deviceId = "test-device-1"
        let token = "test-token-123"

        let session = await sessionManager.createSession(deviceId: deviceId, token: token)

        let validated = await sessionManager.validateSession(session.id)

        XCTAssertNotNil(validated)
        XCTAssertEqual(validated?.id, session.id)
        XCTAssertEqual(validated?.deviceId, deviceId)
    }

    func testValidateSessionRefreshesActivity() async throws {
        let deviceId = "test-device-1"
        let token = "test-token-123"

        let session = await sessionManager.createSession(deviceId: deviceId, token: token)
        let initialActivity = session.lastActivity

        // Wait a brief moment
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        let validated = await sessionManager.validateSession(session.id, refreshActivity: true)

        XCTAssertNotNil(validated)
        XCTAssertGreaterThan(validated!.lastActivity, initialActivity)
    }

    func testValidateSessionWithoutRefresh() async throws {
        let deviceId = "test-device-1"
        let token = "test-token-123"

        let session = await sessionManager.createSession(deviceId: deviceId, token: token)
        let initialActivity = session.lastActivity

        try await Task.sleep(nanoseconds: 100_000_000)

        let validated = await sessionManager.validateSession(session.id, refreshActivity: false)

        XCTAssertNotNil(validated)
        XCTAssertEqual(validated!.lastActivity, initialActivity)
    }

    func testValidateInvalidSession() async throws {
        let validated = await sessionManager.validateSession("non-existent-session")

        XCTAssertNil(validated)
    }

    func testValidateSessionByToken() async throws {
        let deviceId = "test-device-1"
        let token = "test-token-123"

        let session = await sessionManager.createSession(deviceId: deviceId, token: token)

        let validated = await sessionManager.validateSessionByToken(token)

        XCTAssertNotNil(validated)
        XCTAssertEqual(validated?.id, session.id)
    }

    func testValidateSessionByInvalidToken() async throws {
        let validated = await sessionManager.validateSessionByToken("non-existent-token")

        XCTAssertNil(validated)
    }

    // MARK: - Session Retrieval Tests

    func testGetSessionByDevice() async throws {
        let deviceId = "test-device-1"
        let token = "test-token-123"

        let session = await sessionManager.createSession(deviceId: deviceId, token: token)

        let retrieved = await sessionManager.getSessionByDevice(deviceId)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, session.id)
    }

    func testGetSessionByNonExistentDevice() async throws {
        let retrieved = await sessionManager.getSessionByDevice("non-existent-device")

        XCTAssertNil(retrieved)
    }

    // MARK: - Session Revocation Tests

    func testRevokeSession() async throws {
        let deviceId = "test-device-1"
        let token = "test-token-123"

        let session = await sessionManager.createSession(deviceId: deviceId, token: token)

        await sessionManager.revokeSession(session.id)

        let validated = await sessionManager.validateSession(session.id)
        XCTAssertNil(validated)
    }

    func testRevokeSessionByDevice() async throws {
        let deviceId = "test-device-1"
        let token = "test-token-123"

        _ = await sessionManager.createSession(deviceId: deviceId, token: token)

        await sessionManager.revokeSessionByDevice(deviceId)

        let retrieved = await sessionManager.getSessionByDevice(deviceId)
        XCTAssertNil(retrieved)
    }

    // MARK: - Session Expiration Tests

    func testSessionExpiration() async throws {
        // Create session manager with very short timeout
        let shortTimeoutManager = SessionManager(sessionTimeout: 0.2, logger: logger)

        let deviceId = "test-device-1"
        let token = "test-token-123"

        let session = await shortTimeoutManager.createSession(deviceId: deviceId, token: token)

        // Wait for session to expire
        try await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds

        let validated = await shortTimeoutManager.validateSession(session.id)
        XCTAssertNil(validated, "Session should be expired")
    }

    func testCleanupExpiredSessions() async throws {
        let shortTimeoutManager = SessionManager(sessionTimeout: 0.2, logger: logger)

        // Create multiple sessions
        _ = await shortTimeoutManager.createSession(deviceId: "device-1", token: "token-1")
        _ = await shortTimeoutManager.createSession(deviceId: "device-2", token: "token-2")
        _ = await shortTimeoutManager.createSession(deviceId: "device-3", token: "token-3")

        let initialCount = await shortTimeoutManager.getActiveSessionCount()
        XCTAssertEqual(initialCount, 3)

        // Wait for sessions to expire
        try await Task.sleep(nanoseconds: 300_000_000)

        let removedCount = await shortTimeoutManager.cleanupExpiredSessions()

        XCTAssertEqual(removedCount, 3, "All sessions should be cleaned up")

        let finalCount = await shortTimeoutManager.getActiveSessionCount()
        XCTAssertEqual(finalCount, 0)
    }

    func testCleanupDoesNotRemoveValidSessions() async throws {
        let deviceId = "test-device-1"
        let token = "test-token-123"

        _ = await sessionManager.createSession(deviceId: deviceId, token: token)

        let removedCount = await sessionManager.cleanupExpiredSessions()

        XCTAssertEqual(removedCount, 0, "No sessions should be removed")

        let finalCount = await sessionManager.getActiveSessionCount()
        XCTAssertEqual(finalCount, 1)
    }

    // MARK: - Session Count Tests

    func testGetActiveSessionCount() async throws {
        var count = await sessionManager.getActiveSessionCount()
        XCTAssertEqual(count, 0)

        _ = await sessionManager.createSession(deviceId: "device-1", token: "token-1")
        count = await sessionManager.getActiveSessionCount()
        XCTAssertEqual(count, 1)

        _ = await sessionManager.createSession(deviceId: "device-2", token: "token-2")
        count = await sessionManager.getActiveSessionCount()
        XCTAssertEqual(count, 2)

        await sessionManager.revokeSessionByDevice("device-1")
        count = await sessionManager.getActiveSessionCount()
        XCTAssertEqual(count, 1)
    }

    func testGetAllActiveSessions() async throws {
        _ = await sessionManager.createSession(deviceId: "device-1", token: "token-1")
        _ = await sessionManager.createSession(deviceId: "device-2", token: "token-2")

        let sessions = await sessionManager.getAllActiveSessions()

        XCTAssertEqual(sessions.count, 2)

        let deviceIds = Set(sessions.map { $0.deviceId })
        XCTAssertTrue(deviceIds.contains("device-1"))
        XCTAssertTrue(deviceIds.contains("device-2"))
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentSessionCreation() async throws {
        // Create multiple sessions concurrently
        let manager = sessionManager!

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask { @Sendable in
                    _ = await manager.createSession(
                        deviceId: "device-\(i)",
                        token: "token-\(i)"
                    )
                }
            }
        }

        let count = await sessionManager.getActiveSessionCount()
        XCTAssertEqual(count, 10, "All concurrent sessions should be created")
    }

    func testConcurrentValidation() async throws {
        // Create sessions
        var sessionIds: [String] = []
        for i in 0..<5 {
            let session = await sessionManager.createSession(
                deviceId: "device-\(i)",
                token: "token-\(i)"
            )
            sessionIds.append(session.id)
        }

        // Validate concurrently
        let manager = sessionManager!

        let validCount = await withTaskGroup(of: Bool.self) { group -> Int in
            for sessionId in sessionIds {
                group.addTask { @Sendable in
                    let validated = await manager.validateSession(sessionId)
                    return validated != nil
                }
            }

            var count = 0
            for await isValid in group {
                if isValid {
                    count += 1
                }
            }
            return count
        }

        XCTAssertEqual(validCount, 5, "All sessions should validate successfully")
    }
}
