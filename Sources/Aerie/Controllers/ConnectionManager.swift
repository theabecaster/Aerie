import Foundation
import Vapor

/// Information about a connected client
struct ConnectedClient {
    let deviceId: String
    var sessionId: String?
    let connectedAt: Date
    var isAuthenticated: Bool
    var lastActivity: Date

    var connectionDuration: TimeInterval {
        Date().timeIntervalSince(connectedAt)
    }
}

/// Thread-safe manager for active WebSocket connections
actor ConnectionManager {

    // MARK: - Properties

    private var connections: [String: WebSocket] = [:]
    private var clientInfo: [String: ConnectedClient] = [:]
    private let logger: Logger

    // MARK: - Initialization

    init(logger: Logger) {
        self.logger = logger
    }

    // MARK: - Connection Management

    /// Register a new WebSocket connection
    func addConnection(deviceId: String, ws: WebSocket) {
        connections[deviceId] = ws
        clientInfo[deviceId] = ConnectedClient(
            deviceId: deviceId,
            sessionId: nil,
            connectedAt: Date(),
            isAuthenticated: false,
            lastActivity: Date()
        )

        logger.info("WebSocket connection added", metadata: [
            "deviceId": .string(deviceId),
            "totalConnections": .string(String(connections.count))
        ])
    }

    /// Remove a WebSocket connection
    func removeConnection(deviceId: String) {
        connections.removeValue(forKey: deviceId)
        clientInfo.removeValue(forKey: deviceId)

        logger.info("WebSocket connection removed", metadata: [
            "deviceId": .string(deviceId),
            "totalConnections": .string(String(connections.count))
        ])
    }

    /// Mark a connection as authenticated with session ID
    func authenticateConnection(deviceId: String, sessionId: String) {
        if var client = clientInfo[deviceId] {
            client.isAuthenticated = true
            client.sessionId = sessionId
            client.lastActivity = Date()
            clientInfo[deviceId] = client

            logger.info("Connection authenticated", metadata: [
                "deviceId": .string(deviceId),
                "sessionId": .string(sessionId)
            ])
        }
    }

    /// Update last activity timestamp for a connection
    func updateActivity(deviceId: String) {
        if var client = clientInfo[deviceId] {
            client.lastActivity = Date()
            clientInfo[deviceId] = client
        }
    }

    /// Get WebSocket connection for a device
    func getConnection(deviceId: String) -> WebSocket? {
        connections[deviceId]
    }

    /// Get client info for a device
    func getClientInfo(deviceId: String) -> ConnectedClient? {
        clientInfo[deviceId]
    }

    /// Check if a device is connected
    func isConnected(deviceId: String) -> Bool {
        connections[deviceId] != nil
    }

    /// Check if a device is authenticated
    func isAuthenticated(deviceId: String) -> Bool {
        clientInfo[deviceId]?.isAuthenticated ?? false
    }

    /// Get all connected device IDs
    func getConnectedDevices() -> [String] {
        Array(connections.keys)
    }

    /// Get count of active connections
    func getConnectionCount() -> Int {
        connections.count
    }

    /// Get count of authenticated connections
    func getAuthenticatedCount() -> Int {
        clientInfo.values.filter { $0.isAuthenticated }.count
    }

    // MARK: - Broadcasting

    /// Send a message to a specific device
    func sendToDevice(deviceId: String, message: String) async throws {
        guard let ws = connections[deviceId] else {
            throw Abort(.notFound, reason: "Device not connected")
        }

        try await ws.send(message)
        updateActivity(deviceId: deviceId)
    }

    /// Send a message to a specific device (typed)
    func sendToDevice<T: Codable>(deviceId: String, message: T) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw Abort(.internalServerError, reason: "Failed to encode message")
        }

        try await sendToDevice(deviceId: deviceId, message: jsonString)
    }

    /// Broadcast a message to all connected devices
    func broadcast(message: String, excludingDevice: String? = nil) async {
        for (deviceId, ws) in connections where deviceId != excludingDevice {
            do {
                try await ws.send(message)
                updateActivity(deviceId: deviceId)
            } catch {
                logger.error("Failed to broadcast to device", metadata: [
                    "deviceId": .string(deviceId),
                    "error": .string(error.localizedDescription)
                ])
            }
        }
    }

    /// Broadcast a message to all authenticated devices
    func broadcastToAuthenticated(message: String, excludingDevice: String? = nil) async {
        for (deviceId, client) in clientInfo where client.isAuthenticated && deviceId != excludingDevice {
            if let ws = connections[deviceId] {
                do {
                    try await ws.send(message)
                    updateActivity(deviceId: deviceId)
                } catch {
                    logger.error("Failed to broadcast to authenticated device", metadata: [
                        "deviceId": .string(deviceId),
                        "error": .string(error.localizedDescription)
                    ])
                }
            }
        }
    }

    // MARK: - Cleanup

    /// Close and remove all connections
    func closeAllConnections() async {
        logger.info("Closing all WebSocket connections", metadata: [
            "count": .string(String(connections.count))
        ])

        for (deviceId, ws) in connections {
            do {
                try await ws.close(code: .goingAway)
            } catch {
                logger.error("Error closing connection", metadata: [
                    "deviceId": .string(deviceId),
                    "error": .string(error.localizedDescription)
                ])
            }
        }

        connections.removeAll()
        clientInfo.removeAll()
    }

    /// Find and close unauthenticated connections older than timeout
    func closeUnauthenticatedConnections(olderThan timeout: TimeInterval) async {
        let now = Date()

        for (deviceId, client) in clientInfo where !client.isAuthenticated {
            let timeSinceConnection = now.timeIntervalSince(client.connectedAt)

            if timeSinceConnection > timeout {
                logger.warning("Closing unauthenticated connection due to timeout", metadata: [
                    "deviceId": .string(deviceId),
                    "timeout": .string(String(timeout)),
                    "duration": .string(String(timeSinceConnection))
                ])

                if let ws = connections[deviceId] {
                    do {
                        try await ws.close(code: .policyViolation)
                    } catch {
                        logger.error("Error closing unauthenticated connection", metadata: [
                            "deviceId": .string(deviceId),
                            "error": .string(error.localizedDescription)
                        ])
                    }
                }

                removeConnection(deviceId: deviceId)
            }
        }
    }
}
