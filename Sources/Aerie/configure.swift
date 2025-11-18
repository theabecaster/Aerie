import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // Listen on 0.0.0.0:8000
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = 8000
    
    // existing config (routes, middleware, etc.)
    try routes(app)
}
