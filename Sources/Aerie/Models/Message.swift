import Foundation

/// Message type enumeration for protocol routing
///
/// Defines all possible message types in the FalconEye protocol.
/// Used to route messages to appropriate handlers on both client and server.
enum MessageType: String, Codable {
    /// Authentication request from client
    case authRequest

    /// Authentication response from server
    case authResponse

    /// Camera frame data from client
    case cameraFrame

    /// Detected poses broadcast from server to all clients
    case poseBroadcast
}

/// Universal message wrapper for all WebSocket communication
///
/// All messages exchanged between Aerie and HawkSight are wrapped in this structure.
/// The `type` field determines how to decode the `payload` field.
///
/// Example JSON:
/// ```json
/// {
///   "type": "authRequest",
///   "timestamp": 1704067200.0,
///   "payload": "eyJkZXZpY2VJZCI6IkExQjJD..."
/// }
/// ```
///
/// Usage:
/// ```swift
/// // Encoding a message
/// let authReq = AuthRequest(deviceId: "...", token: "...", deviceInfo: info)
/// let payloadData = try JSONEncoder().encode(authReq)
/// let message = Message(type: .authRequest, timestamp: Date().timeIntervalSince1970, payload: payloadData)
///
/// // Decoding a message
/// let authReq = try JSONDecoder().decode(AuthRequest.self, from: message.payload)
/// ```
struct Message: Codable {
    /// Type of message for routing
    let type: MessageType

    /// Unix timestamp (seconds since epoch) when message was created
    let timestamp: Double

    /// JSON-encoded payload specific to the message type
    /// Decode based on `type` field:
    /// - .authRequest → AuthRequest
    /// - .authResponse → AuthResponse
    /// - .cameraFrame → CameraFrame
    /// - .poseBroadcast → PoseBroadcast
    let payload: Data
}
