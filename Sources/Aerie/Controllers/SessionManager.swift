import Foundation
import Vapor

/// Represents an active session for an authenticated device
struct Session: Codable {
    let id: String
    let deviceId: String
    let token: String
    let createdAt: Date
    var lastActivity: Date
    let expiresAt: Date

    var isExpired: Bool {
        Date() > expiresAt
    }

    var isValid: Bool {
        !isExpired
    }
}

/// Thread-safe session manager using Swift 6 Actor model
actor SessionManager {

    // MARK: - Properties

    private var sessions: [String: Session] = [:]
    private let sessionTimeout: TimeInterval
    private let logger: Logger

    // MARK: - Initialization

    init(sessionTimeout: TimeInterval = 3600, logger: Logger) {
        self.sessionTimeout = sessionTimeout
        self.logger = logger
    }

    // MARK: - Session Management

    /// Create a new session for a device with the given token
    func createSession(deviceId: String, token: String) -> Session {
        let sessionId = UUID().uuidString
        let now = Date()
        let expiresAt = now.addingTimeInterval(sessionTimeout)

        let session = Session(
            id: sessionId,
            deviceId: deviceId,
            token: token,
            createdAt: now,
            lastActivity: now,
            expiresAt: expiresAt
        )

        // Remove any existing sessions for this device
        sessions = sessions.filter { $0.value.deviceId != deviceId }

        sessions[sessionId] = session

        logger.info("Session created", metadata: [
            "sessionId": .string(sessionId),
            "deviceId": .string(deviceId),
            "expiresAt": .string(expiresAt.ISO8601Format())
        ])

        return session
    }

    /// Validate a session by ID and optionally refresh its activity timestamp
    func validateSession(_ sessionId: String, refreshActivity: Bool = true) -> Session? {
        guard var session = sessions[sessionId], session.isValid else {
            if let session = sessions[sessionId] {
                logger.debug("Session validation failed - expired", metadata: [
                    "sessionId": .string(sessionId),
                    "deviceId": .string(session.deviceId)
                ])
            }
            return nil
        }

        if refreshActivity {
            session.lastActivity = Date()
            sessions[sessionId] = session
        }

        return session
    }

    /// Validate a session by token
    func validateSessionByToken(_ token: String) -> Session? {
        guard let session = sessions.values.first(where: { $0.token == token && $0.isValid }) else {
            return nil
        }

        return validateSession(session.id)
    }

    /// Get session by device ID
    func getSessionByDevice(_ deviceId: String) -> Session? {
        guard let session = sessions.values.first(where: { $0.deviceId == deviceId && $0.isValid }) else {
            return nil
        }

        return session
    }

    /// Revoke a session by ID
    func revokeSession(_ sessionId: String) {
        if let session = sessions.removeValue(forKey: sessionId) {
            logger.info("Session revoked", metadata: [
                "sessionId": .string(sessionId),
                "deviceId": .string(session.deviceId)
            ])
        }
    }

    /// Revoke session by device ID
    func revokeSessionByDevice(_ deviceId: String) {
        let matchingSessions = sessions.filter { $0.value.deviceId == deviceId }
        for (sessionId, _) in matchingSessions {
            sessions.removeValue(forKey: sessionId)
        }

        if !matchingSessions.isEmpty {
            logger.info("Session revoked by device", metadata: [
                "deviceId": .string(deviceId),
                "count": .string(String(matchingSessions.count))
            ])
        }
    }

    /// Clean up expired sessions
    func cleanupExpiredSessions() -> Int {
        let initialCount = sessions.count
        sessions = sessions.filter { $0.value.isValid }
        let removedCount = initialCount - sessions.count

        if removedCount > 0 {
            logger.info("Expired sessions cleaned up", metadata: [
                "removedCount": .string(String(removedCount)),
                "remainingCount": .string(String(sessions.count))
            ])
        }

        return removedCount
    }

    /// Get count of active sessions
    func getActiveSessionCount() -> Int {
        sessions.values.filter { $0.isValid }.count
    }

    /// Get all active sessions (for monitoring/debugging)
    func getAllActiveSessions() -> [Session] {
        Array(sessions.values.filter { $0.isValid })
    }
}
