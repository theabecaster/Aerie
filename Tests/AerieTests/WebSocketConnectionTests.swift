import XCTest
import Vapor
@testable import Aerie

final class WebSocketConnectionTests: XCTestCase {

    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
        app = nil
    }

    // MARK: - HTTP Endpoint Tests

    func testRootEndpoint() async throws {
        try await app.test(.GET, "/") { res async in
            XCTAssertEqual(res.status, .ok)
            XCTAssertTrue(res.body.string.contains("FalconEye Aerie Server"))
        }
    }

    func testStatusEndpoint() async throws {
        try await app.test(.GET, "/status") { res async throws in
            XCTAssertEqual(res.status, .ok)

            let status = try res.content.decode(Status.self)
            XCTAssertTrue(status.running)
            XCTAssertEqual(status.activeSessions, 0)
            XCTAssertEqual(status.totalConnections, 0)
            XCTAssertEqual(status.authenticatedConnections, 0)
        }
    }

    // NOTE: WebSocket integration tests are best performed manually or with dedicated
    // integration test frameworks. For now, we verify the HTTP endpoints work correctly.
    // Manual WebSocket testing can be done using tools like `wscat`:
    //
    // 1. Start server: swift run Aerie
    // 2. Connect: wscat -c ws://localhost:8000/ws/connect/test-device
    // 3. Send auth request with valid token
    // 4. Verify auth response with sessionId
}
