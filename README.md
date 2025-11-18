# Aerie - FalconEye Server

The central processing hub for FalconEye's distributed spatial mapping system. Aerie runs on a MacBook and coordinates multiple iPhone clients for real-time through-wall human pose visualization.

## Overview

Aerie is a server-side Swift application built with the Vapor framework that:

- **Manages WebSocket connections** from multiple HawkSight iPhone clients
- **Authenticates devices** using token-based authentication with session management
- **Receives camera frames** and device poses from connected clients
- **Performs pose detection** using MediaPipe (planned for Phase 3)
- **Transforms detected poses** to a shared world coordinate system
- **Broadcasts world-frame poses** to all connected HawkSight clients

## Technology Stack

- **Language**: Swift 6.0
- **Framework**: Vapor 4.115+ (server-side web framework)
- **Networking**: SwiftNIO (non-blocking I/O), WebSocketKit 2.16+
- **Package Manager**: Swift Package Manager (SPM)
- **Platform**: macOS 13+
- **Pose Detection**: MediaPipe (planned integration)
- **Deployment**: Docker support included

## System Requirements

### Recommended Hardware
- M4 Max MacBook Pro (or equivalent)
- 16GB+ RAM (for handling 3+ simultaneous clients)
- 50GB+ available storage

### Software Requirements
- macOS 13 (Ventura) or later
- Swift 6.0+ (included with Xcode 16+)
- Docker (optional, for containerized deployment)

## Quick Start

### Installation

```bash
# Clone the repository (if not already done)
git clone [repository-url]
cd FalconEye/Aerie

# Resolve dependencies
swift package resolve

# Build the project
swift build
```

### Running the Server

```bash
# Run in development mode
swift run

# Server starts on 0.0.0.0:8000
# You should see: "Server starting on http://0.0.0.0:8000"
```

### Verify Server is Running

```bash
# From another terminal or device on the network
curl http://localhost:8000
# Expected response: "It works!"
```

### Running Tests

```bash
swift test
```

### Docker Deployment

```bash
# Build and run in Docker container
docker-compose up

# Run in detached mode
docker-compose up -d

# Stop container
docker-compose down
```

## Configuration

### Server Settings

Edit `Sources/Aerie/configure.swift` to modify:

```swift
// Network configuration
app.http.server.configuration.hostname = "0.0.0.0"  // Listen on all interfaces
app.http.server.configuration.port = 8000           // Default port

// For production, add TLS configuration:
// app.http.server.configuration.tlsConfiguration = ...
```

### Environment Variables

Create a `.env` file in the Aerie directory (not tracked by git):

```bash
# Server configuration
SERVER_PORT=8000
SERVER_HOSTNAME=0.0.0.0

# Authentication
AUTH_SECRET_KEY=your-secret-key-here

# Logging
LOG_LEVEL=debug
```

## Project Structure

```
Aerie/
├── Sources/
│   └── Aerie/
│       ├── entrypoint.swift      # Application entry point (@main)
│       ├── configure.swift       # Server configuration
│       └── routes.swift          # HTTP and WebSocket routes
├── Tests/
│   └── AerieTests/               # Unit tests
├── Public/                       # Static assets (if any)
├── Package.swift                 # SPM manifest with dependencies
├── Package.resolved              # Locked dependency versions
├── docker-compose.yml            # Docker Compose configuration
├── Dockerfile                    # Container image definition
└── README.md                     # This file
```

## Network Protocol

### WebSocket Endpoint

```
ws://[server-ip]:8000/ws/connect/{deviceId}
```

Example:
```
ws://192.168.1.100:8000/ws/connect/iPhone-12345
```

### Connection Flow

1. **Client connects** to WebSocket endpoint with unique deviceId
2. **Server accepts** connection and awaits authentication
3. **Client sends** `AuthRequest` with token and device metadata
4. **Server validates** token and creates session
5. **Server responds** with `AuthResponse` containing sessionId
6. **Session established** - client can transmit frames and receive poses

### Message Types

All messages use JSON encoding with Codable Swift models.

#### Incoming Messages (from HawkSight)

**AuthRequest**
```json
{
  "deviceId": "iPhone-12345",
  "token": "base64-hmac-signature",
  "deviceInfo": {
    "model": "iPhone 14 Pro",
    "osVersion": "iOS 17.1",
    "hasLiDAR": true
  }
}
```

**CameraFrame** (Phase 2)
```json
{
  "frameId": "uuid-here",
  "timestamp": 1234567890.123,
  "imageData": "base64-jpeg-data",
  "devicePose": [[...], [...], [...], [...]],  // 4x4 matrix
  "intrinsics": {
    "fx": 1200.5,
    "fy": 1200.5,
    "cx": 640.0,
    "cy": 480.0,
    "width": 1280,
    "height": 960
  }
}
```

#### Outgoing Messages (to HawkSight)

**AuthResponse**
```json
{
  "success": true,
  "sessionId": "session-uuid",
  "error": null
}
```

**PoseBroadcast** (Phase 5)
```json
{
  "timestamp": 1234567890.123,
  "poses": [
    {
      "personId": "person-1",
      "sourceDevice": "iPhone-12345",
      "confidence": 0.92,
      "joints": [
        {
          "type": "head",
          "position": [1.2, 0.5, 3.4],  // [x, y, z] in world frame
          "confidence": 0.95
        },
        // ... 12 more joints
      ]
    }
  ]
}
```

## Authentication & Session Management

### Authentication Flow (Phase 1)

1. **Token Generation**: Pre-shared secret used for HMAC signature
2. **Token Validation**: Verify HMAC signature and timestamp
3. **Session Creation**: Generate unique sessionId (UUID)
4. **Session Storage**: Store in memory with device metadata
5. **Session Validation**: Validate sessionId for all subsequent messages
6. **Session Expiration**: 1-hour timeout for inactive sessions
7. **Session Revocation**: Clean up on client disconnect

### Security Features

- HMAC-SHA256 token signatures using CryptoKit
- Cryptographically secure session IDs
- Rate limiting for authentication attempts (planned)
- Audit logging for all auth events
- WSS (Secure WebSocket) support for production

## Pose Detection Pipeline (Phase 3)

### MediaPipe Integration

**Detection Flow**:
1. Receive `CameraFrame` from HawkSight
2. Decode base64 JPEG to pixel buffer
3. Pass image to MediaPipe pose detection model
4. Extract 13 key joints with confidence scores
5. Filter detections below confidence threshold (0.5)
6. Support multi-person detection (3+ people simultaneously)

### Detected Joints (13 total)

```
0:  Head/Nose
1:  Left Shoulder
2:  Right Shoulder
3:  Left Elbow
4:  Right Elbow
5:  Left Wrist
6:  Right Wrist
7:  Left Hip
8:  Right Hip
9:  Left Knee
10: Right Knee
11: Left Ankle
12: Right Ankle
```

## Coordinate Transformation (Phase 4)

### Transform Pipeline

**Camera → Device → World**

```swift
// 1. Unproject 2D + depth → Camera 3D
func unproject(pixel: CGPoint, depth: Float, intrinsics: CameraIntrinsics) -> simd_float3

// 2. Camera 3D → Device frame
let devicePoint = devicePose * cameraPoint

// 3. Device frame → World frame
let worldPoint = worldFromDevice * devicePoint
```

### World Coordinate System

- Origin defined by first connected device (or manual calibration)
- Y-axis: up (against gravity)
- X/Z axes: horizontal plane
- All poses transformed to this shared frame before broadcasting

## Broadcasting Strategy (Phase 5)

1. **Trigger**: New pose detected and transformed
2. **Aggregation**: Collect all poses within 100ms window
3. **Serialization**: Package as `PoseBroadcast` JSON message
4. **Distribution**: Send via WebSocket to all connected clients
5. **Rate Limiting**: Max 30 broadcasts per second

### Broadcast Optimization

- Only broadcast poses with confidence >0.5
- Skip broadcast if no poses detected
- Include source device for debugging
- Compress JSON for reduced bandwidth

## Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Pose detection latency | <100ms | Per frame on M4 Max |
| WebSocket round-trip | <50ms | Network + processing |
| Memory usage | <1GB | With 3+ connected devices |
| CPU usage | <50% | During sustained operation |
| Concurrent connections | 3-5 | Multiple HawkSight clients |
| Frames processed/sec | 90+ | 30 FPS × 3 devices |

## Development

### Adding Routes

Edit `Sources/Aerie/routes.swift`:

```swift
func routes(_ app: Application) throws {
    app.get("health") { req async -> String in
        "OK"
    }
}
```

### Adding WebSocket Handlers

```swift
app.webSocket("ws", "connect", ":deviceId") { req, ws async in
    let deviceId = req.parameters.get("deviceId")!

    // Handle WebSocket messages
    ws.onText { ws, text in
        // Process incoming message
    }
}
```

### Modifying Dependencies

Edit `Package.swift`, then:

```bash
swift package resolve
swift build
```

## Testing

### Unit Tests

```bash
# Run all tests
swift test

# Run specific test
swift test --filter AerieTests.SomeTest
```

### Integration Testing

1. **Single Client**: Connect one HawkSight, verify auth and frame reception
2. **Multi-Client**: Connect 2-3 HawkSight instances simultaneously
3. **Load Test**: Sustained 30 FPS from 3 devices for 5+ minutes
4. **Reconnection**: Test disconnect/reconnect and session cleanup
5. **Invalid Auth**: Verify rejection of invalid tokens

### Manual Testing with WebSocket Tools

```bash
# Install wscat (WebSocket CLI tool)
npm install -g wscat

# Connect to server
wscat -c ws://localhost:8000/ws/connect/test-device

# Send test message
> {"deviceId": "test-device", "token": "test-token"}
```

## Logging & Monitoring

### Log Levels

```swift
// Configure in configure.swift
app.logger.logLevel = .debug  // .trace, .debug, .info, .notice, .warning, .error, .critical
```

### Key Events Logged

- Device connections/disconnections
- Authentication attempts (success/failure)
- Frame reception rate per device
- Pose detection latency
- Memory/CPU warnings
- WebSocket errors

### Future Monitoring Dashboard (Phase 9)

- Real-time connection status
- Performance metrics visualization
- Detected pose preview
- Frame rate per device
- Network bandwidth usage

## Troubleshooting

### Port 8000 already in use

```bash
# Find process using port
lsof -i :8000

# Kill process
kill -9 <PID>

# Or change port in configure.swift
```

### Swift version mismatch

```bash
# Check Swift version
swift --version
# Should be 6.0 or later

# Update Xcode Command Line Tools
xcode-select --install
```

### Build fails with dependency errors

```bash
# Clean everything
rm -rf .build
rm Package.resolved

# Rebuild
swift package resolve
swift build
```

### WebSocket connections rejected

- Check macOS Firewall: System Settings → Network → Firewall
- Verify hostname is "0.0.0.0" not "127.0.0.1"
- Ensure clients use correct server IP (not localhost)
- Check WiFi network allows device-to-device communication

### High memory usage

- Limit frame buffer size (default: 30 frames per device)
- Reduce pose history retention (default: 1 second)
- Check for memory leaks in frame processing
- Monitor with Activity Monitor or `swift run --enable-malloc-scribble`

## Future Enhancements

### Phase 6: Performance Optimization
- H.264 video streaming (replace JPEG frames)
- GPU acceleration for pose detection (Metal Performance Shaders)
- Binary protocol for reduced serialization overhead
- Frame pipelining for parallel processing

### Phase 7: Multi-Person Tracking
- Persistent person ID assignment
- Temporal tracking with Kalman filtering
- Cross-device identity correlation
- Velocity and acceleration tracking

### Phase 9: Monitoring Dashboard
- Web-based UI for server monitoring
- Real-time pose visualization
- Recording and playback functionality
- Configuration controls
- Performance metrics display

### Phase 10: Quest 3 Support
- Additional endpoints for Quest clients
- 3D skeleton format for MR rendering
- Support for Quest-specific message types

## References

- [Vapor Documentation](https://docs.vapor.codes/)
- [SwiftNIO](https://github.com/apple/swift-nio)
- [WebSocketKit](https://github.com/vapor/websocket-kit)
- [MediaPipe](https://mediapipe.dev/)

## Support

For component-specific issues:
- Server bugs: Open issue in Aerie repository
- Client bugs: Check HawkSight repository
- System integration: Open issue in FalconEye repository
