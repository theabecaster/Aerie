import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // MARK: - Server Configuration

    // Listen on all interfaces on port 8000
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = 8000

    // MARK: - Initialize Managers

    app.logger.info("Initializing FalconEye Aerie server managers...")

    // Server secret for token generation (in production, load from environment)
    let serverSecret = Environment.get("SERVER_SECRET") ?? "falcon-eye-default-secret-change-in-production"

    // Session timeout (default: 1 hour)
    let sessionTimeout = TimeInterval(Environment.get("SESSION_TIMEOUT").flatMap(Double.init) ?? 3600)

    // Initialize SessionManager
    let sessionManager = SessionManager(
        sessionTimeout: sessionTimeout,
        logger: app.logger
    )
    app.storage[SessionManagerKey.self] = sessionManager

    app.logger.info("SessionManager initialized", metadata: [
        "sessionTimeout": .string("\(sessionTimeout)s")
    ])

    // Initialize ConnectionManager
    let connectionManager = ConnectionManager(logger: app.logger)
    app.storage[ConnectionManagerKey.self] = connectionManager

    app.logger.info("ConnectionManager initialized")

    // Initialize AuthController
    let authController = AuthController(
        sessionManager: sessionManager,
        serverSecret: serverSecret,
        logger: app.logger
    )
    app.storage[AuthControllerKey.self] = authController

    app.logger.info("AuthController initialized")

    // Initialize WebSocketController
    let webSocketController = WebSocketController(
        sessionManager: sessionManager,
        connectionManager: connectionManager,
        authController: authController,
        logger: app.logger
    )
    app.storage[WebSocketControllerKey.self] = webSocketController

    app.logger.info("WebSocketController initialized")

    // MARK: - Background Tasks

    // Session cleanup task - runs every 5 minutes
    Task {
        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: 300_000_000_000)  // 5 minutes

                let removedCount = await sessionManager.cleanupExpiredSessions()

                if removedCount > 0 {
                    app.logger.info("Background session cleanup completed", metadata: [
                        "removedSessions": .string(String(removedCount))
                    ])
                }
            } catch {
                if !Task.isCancelled {
                    app.logger.error("Session cleanup task error: \(error)")
                }
            }
        }
    }

    // Auth timeout enforcement - runs every 30 seconds
    Task {
        let authTimeout = WebSocketController.authTimeout

        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: 30_000_000_000)  // 30 seconds

                await connectionManager.closeUnauthenticatedConnections(olderThan: authTimeout)
            } catch {
                if !Task.isCancelled {
                    app.logger.error("Auth timeout enforcement error: \(error)")
                }
            }
        }
    }

    app.logger.info("Background tasks started")

    // MARK: - Shutdown Handler

    app.lifecycle.use(
        AerieLifecycleHandler(
            connectionManager: connectionManager,
            logger: app.logger
        )
    )

    // MARK: - Register Routes

    try routes(app)

    app.logger.info("Aerie server configuration complete - ready to accept connections")
}

// MARK: - Lifecycle Handler

struct AerieLifecycleHandler: Vapor.LifecycleHandler {
    let connectionManager: ConnectionManager
    let logger: Logger

    func shutdown(_ app: Application) async {
        logger.info("Shutting down Aerie server - closing all connections")
        await connectionManager.closeAllConnections()
        logger.info("Shutdown complete")
    }

    func didBoot(_ app: Application) throws {
        logger.info("Aerie server started successfully", metadata: [
            "hostname": .string(app.http.server.configuration.hostname),
            "port": .string(String(app.http.server.configuration.port))
        ])
    }
}
