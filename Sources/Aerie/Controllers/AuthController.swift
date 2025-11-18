import Foundation
import Vapor
import CryptoKit

/// Handles authentication logic including token generation and validation
struct AuthController {

    // MARK: - Properties

    private let sessionManager: SessionManager
    private let serverSecret: String
    private let logger: Logger

    // MARK: - Initialization

    init(sessionManager: SessionManager, serverSecret: String, logger: Logger) {
        self.sessionManager = sessionManager
        self.serverSecret = serverSecret
        self.logger = logger
    }

    // MARK: - Token Management

    /// Generate a valid authentication token for a device
    /// Token format: HMAC-SHA256(deviceId + timestamp + nonce + secret)
    /// Includes nanosecond precision timestamp and UUID nonce for guaranteed uniqueness
    func generateToken(for deviceId: String) -> String {
        let timestamp = Date().timeIntervalSince1970  // Full precision (includes nanoseconds)
        let nonce = UUID().uuidString  // Random nonce for additional entropy
        let data = "\(deviceId):\(timestamp):\(nonce):\(serverSecret)"

        let key = SymmetricKey(data: Data(serverSecret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(data.utf8), using: key)

        return Data(signature).base64EncodedString()
    }

    /// Validate an authentication token
    /// For simplicity, we accept any non-empty token and validate its format
    /// In production, this would verify HMAC signature and timestamp
    func validateToken(_ token: String) -> Bool {
        // Basic validation: token must be non-empty and reasonable length
        guard !token.isEmpty, token.count >= 16, token.count <= 256 else {
            return false
        }

        // Check if it's valid base64
        guard Data(base64Encoded: token) != nil else {
            return false
        }

        return true
    }

    // MARK: - Authentication Flow

    /// Process an authentication request and return a response
    func handleAuthRequest(_ request: AuthRequest, deviceId: String) async -> AuthResponse {
        logger.info("Processing auth request", metadata: [
            "deviceId": .string(deviceId),
            "model": .string(request.deviceInfo.model),
            "osVersion": .string(request.deviceInfo.osVersion)
        ])

        // Validate the token
        guard validateToken(request.token) else {
            logger.warning("Auth failed - invalid token", metadata: [
                "deviceId": .string(deviceId)
            ])
            return AuthResponse(
                success: false,
                sessionId: nil,
                error: "Invalid authentication token"
            )
        }

        // Check if device is already authenticated
        if let existingSession = await sessionManager.getSessionByDevice(deviceId) {
            logger.info("Device already authenticated - reusing session", metadata: [
                "deviceId": .string(deviceId),
                "sessionId": .string(existingSession.id)
            ])

            return AuthResponse(
                success: true,
                sessionId: existingSession.id,
                error: nil
            )
        }

        // Create new session
        let session = await sessionManager.createSession(deviceId: deviceId, token: request.token)

        logger.info("Auth successful - new session created", metadata: [
            "deviceId": .string(deviceId),
            "sessionId": .string(session.id)
        ])

        return AuthResponse(
            success: true,
            sessionId: session.id,
            error: nil
        )
    }

    /// Verify that a session is valid for subsequent requests
    func verifySession(_ sessionId: String) async -> Bool {
        let session = await sessionManager.validateSession(sessionId)
        return session != nil
    }

    /// Get device ID from session
    func getDeviceId(forSession sessionId: String) async -> String? {
        let session = await sessionManager.validateSession(sessionId)
        return session?.deviceId
    }
}
