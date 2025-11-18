import Vapor

func routes(_ app: Application) throws {
    // MARK: - HTTP Routes

    app.get { req async in
        "FalconEye Aerie Server - Running"
    }

    app.get("hello") { req async -> String in
        "Hello, world!"
    }

    app.get("status") { req async -> Status in
        let sessionManager = req.application.storage[SessionManagerKey.self]!
        let connectionManager = req.application.storage[ConnectionManagerKey.self]!

        let activeSessionCount = await sessionManager.getActiveSessionCount()
        let connectionCount = await connectionManager.getConnectionCount()
        let authenticatedCount = await connectionManager.getAuthenticatedCount()

        return Status(
            running: true,
            activeSessions: activeSessionCount,
            totalConnections: connectionCount,
            authenticatedConnections: authenticatedCount,
            timestamp: Date()
        )
    }

    // MARK: - WebSocket Routes

    app.webSocket("ws", "connect", ":deviceId") { req, ws async in
        // Retrieve managers from application storage
        guard let webSocketController = req.application.storage[WebSocketControllerKey.self] else {
            req.logger.error("Failed to retrieve required managers from application storage")
            try? await ws.close(code: .unexpectedServerError)
            return
        }

        do {
            try await webSocketController.handleConnection(req: req, ws: ws)
        } catch {
            req.logger.error("WebSocket connection error: \(error)")
            try? await ws.close(code: .unexpectedServerError)
        }
    }
}

// MARK: - Response Models

struct Status: Content {
    let running: Bool
    let activeSessions: Int
    let totalConnections: Int
    let authenticatedConnections: Int
    let timestamp: Date
}

// MARK: - Storage Keys

struct SessionManagerKey: StorageKey {
    typealias Value = SessionManager
}

struct ConnectionManagerKey: StorageKey {
    typealias Value = ConnectionManager
}

struct AuthControllerKey: StorageKey {
    typealias Value = AuthController
}

struct WebSocketControllerKey: StorageKey {
    typealias Value = WebSocketController
}
