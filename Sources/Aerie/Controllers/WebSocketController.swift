import Foundation
import Vapor

/// Handles WebSocket connections and message routing
struct WebSocketController {

    // MARK: - Configuration

    /// Timeout for unauthenticated connections (seconds)
    static let authTimeout: TimeInterval = 10.0

    // MARK: - Properties

    private let sessionManager: SessionManager
    private let connectionManager: ConnectionManager
    private let authController: AuthController
    private let logger: Logger

    // MARK: - Initialization

    init(
        sessionManager: SessionManager,
        connectionManager: ConnectionManager,
        authController: AuthController,
        logger: Logger
    ) {
        self.sessionManager = sessionManager
        self.connectionManager = connectionManager
        self.authController = authController
        self.logger = logger
    }

    // MARK: - WebSocket Handler

    /// Handle a new WebSocket connection
    func handleConnection(req: Request, ws: WebSocket) async throws {
        guard let deviceId = req.parameters.get("deviceId") else {
            try await ws.close(code: .unexpectedServerError)
            throw Abort(.badRequest, reason: "Missing deviceId parameter")
        }

        logger.info("New WebSocket connection", metadata: [
            "deviceId": .string(deviceId),
            "remoteAddress": .string(req.remoteAddress?.description ?? "unknown")
        ])

        // Register the connection
        await connectionManager.addConnection(deviceId: deviceId, ws: ws)

        // Set up close handler
        ws.onClose.whenComplete { [connectionManager, sessionManager, logger] _ in
            Task {
                await connectionManager.removeConnection(deviceId: deviceId)
                await sessionManager.revokeSessionByDevice(deviceId)

                logger.info("WebSocket connection closed", metadata: [
                    "deviceId": .string(deviceId)
                ])
            }
        }

        // Set up message handler
        ws.onText { ws, text in
            await self.handleMessage(deviceId: deviceId, text: text, ws: ws)
        }

        // Start authentication timeout timer
        Task {
            try? await Task.sleep(nanoseconds: UInt64(Self.authTimeout * 1_000_000_000))

            // Check if device authenticated within timeout
            let isAuthenticated = await connectionManager.isAuthenticated(deviceId: deviceId)

            if !isAuthenticated {
                logger.warning("Connection timeout - no authentication received", metadata: [
                    "deviceId": .string(deviceId),
                    "timeout": .string(String(Self.authTimeout))
                ])

                try? await ws.close(code: .policyViolation)
                await connectionManager.removeConnection(deviceId: deviceId)
            }
        }
    }

    // MARK: - Message Routing

    /// Handle incoming WebSocket message
    private func handleMessage(deviceId: String, text: String, ws: WebSocket) async {
        logger.debug("Message received", metadata: [
            "deviceId": .string(deviceId),
            "length": .string(String(text.count))
        ])

        await connectionManager.updateActivity(deviceId: deviceId)

        do {
            // Parse the message wrapper
            let decoder = JSONDecoder()
            guard let data = text.data(using: .utf8) else {
                throw MessageError.invalidEncoding
            }

            let message = try decoder.decode(Message.self, from: data)

            // Route by message type
            switch message.type {
            case .authRequest:
                try await handleAuthRequest(deviceId: deviceId, message: message, ws: ws)

            case .cameraFrame:
                try await handleCameraFrame(deviceId: deviceId, message: message)

            case .heartbeat:
                try await handleHeartbeat(deviceId: deviceId, ws: ws)

            case .authResponse, .poseBroadcast:
                // These are outbound message types only
                logger.warning("Received unexpected message type from client", metadata: [
                    "deviceId": .string(deviceId),
                    "type": .string(String(describing: message.type))
                ])
            }

        } catch {
            logger.error("Failed to handle message", metadata: [
                "deviceId": .string(deviceId),
                "error": .string(error.localizedDescription)
            ])

            // Send error response
            await sendErrorResponse(deviceId: deviceId, ws: ws, error: error)
        }
    }

    // MARK: - Message Handlers

    /// Handle authentication request
    private func handleAuthRequest(deviceId: String, message: Message, ws: WebSocket) async throws {
        let decoder = JSONDecoder()
        let authRequest = try decoder.decode(AuthRequest.self, from: message.payload)

        // Process authentication
        let authResponse = await authController.handleAuthRequest(authRequest, deviceId: deviceId)

        // If successful, mark connection as authenticated
        if authResponse.success, let sessionId = authResponse.sessionId {
            await connectionManager.authenticateConnection(deviceId: deviceId, sessionId: sessionId)
        }

        // Send response
        let encoder = JSONEncoder()
        let responsePayload = try encoder.encode(authResponse)

        let responseMessage = Message(
            type: .authResponse,
            timestamp: Date().timeIntervalSince1970,
            payload: responsePayload
        )

        try await sendMessage(deviceId: deviceId, message: responseMessage, ws: ws)
    }

    /// Handle camera frame (placeholder for Phase 2)
    private func handleCameraFrame(deviceId: String, message: Message) async throws {
        // Verify authentication
        guard await connectionManager.isAuthenticated(deviceId: deviceId) else {
            throw MessageError.notAuthenticated
        }

        // Phase 2 implementation: Parse CameraFrame, process pose detection, etc.
        logger.debug("Camera frame received (Phase 2 - not yet implemented)", metadata: [
            "deviceId": .string(deviceId)
        ])
    }

    /// Handle heartbeat/ping message
    private func handleHeartbeat(deviceId: String, ws: WebSocket) async throws {
        // Send pong response
        let pongData = "{\"pong\": true}".data(using: .utf8) ?? Data()

        let pongMessage = Message(
            type: .heartbeat,
            timestamp: Date().timeIntervalSince1970,
            payload: pongData
        )

        try await sendMessage(deviceId: deviceId, message: pongMessage, ws: ws)

        logger.debug("Heartbeat received and acknowledged", metadata: [
            "deviceId": .string(deviceId)
        ])
    }

    // MARK: - Helper Methods

    /// Send a message to a device
    private func sendMessage(deviceId: String, message: Message, ws: WebSocket) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(message)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw MessageError.encodingFailed
        }

        try await ws.send(jsonString)

        logger.debug("Message sent", metadata: [
            "deviceId": .string(deviceId),
            "type": .string(String(describing: message.type))
        ])
    }

    /// Send error response to client
    private func sendErrorResponse(deviceId: String, ws: WebSocket, error: any Error) async {
        let errorResponse = AuthResponse(
            success: false,
            sessionId: nil,
            error: error.localizedDescription
        )

        do {
            let encoder = JSONEncoder()
            let errorPayload = try encoder.encode(errorResponse)

            let errorMessage = Message(
                type: .authResponse,
                timestamp: Date().timeIntervalSince1970,
                payload: errorPayload
            )

            try await sendMessage(deviceId: deviceId, message: errorMessage, ws: ws)
        } catch {
            logger.error("Failed to send error response", metadata: [
                "deviceId": .string(deviceId),
                "error": .string(error.localizedDescription)
            ])
        }
    }
}

// MARK: - Errors

enum MessageError: Error, CustomStringConvertible {
    case invalidEncoding
    case notAuthenticated
    case encodingFailed

    var description: String {
        switch self {
        case .invalidEncoding:
            return "Invalid message encoding"
        case .notAuthenticated:
            return "Device not authenticated"
        case .encodingFailed:
            return "Failed to encode message"
        }
    }
}
