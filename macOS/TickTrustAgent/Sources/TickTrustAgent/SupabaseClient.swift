import Foundation

// MARK: - Response types

struct LaunchCheckResponse: Decodable {
    let allowed: Bool
    let reason: String
    let minutesRemaining: Int

    enum CodingKeys: String, CodingKey {
        case allowed, reason
        case minutesRemaining = "minutes_remaining"
    }
}

struct HeartbeatResponse: Decodable {
    let action: String        // continue | warn_2min | warn_1min | warn_10s | kill
    let minutesRemaining: Int

    enum CodingKeys: String, CodingKey {
        case action
        case minutesRemaining = "minutes_remaining"
    }
}

struct ManagedApp: Decodable {
    let bundleId: String
    let appName: String

    enum CodingKeys: String, CodingKey {
        case bundleId = "bundle_id"
        case appName  = "app_name"
    }
}

// MARK: - Client

final class SupabaseClient {
    private let config: Config
    private let session: URLSession
    private let decoder: JSONDecoder
    private let fmt = ISO8601DateFormatter()

    init(config: Config) {
        self.config = config
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: cfg)
        self.decoder = JSONDecoder()
    }

    // Fetch all managed bundle IDs for this device (called at startup + every 5 min)
    func fetchManagedApps() async throws -> [ManagedApp] {
        let url = URL(string: "\(config.supabaseURL)/rest/v1/managed_apps?device_id=eq.\(config.deviceId)&enabled=eq.true&select=bundle_id,app_name")!
        var req = baseRequest(url: url, method: "GET")
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        let (data, _) = try await session.data(for: req)
        return try decoder.decode([ManagedApp].self, from: data)
    }

    func launchCheck(bundleId: String) async throws -> LaunchCheckResponse {
        let url = URL(string: "\(config.supabaseURL)/functions/v1/launch-check")!
        var req = baseRequest(url: url, method: "POST")
        req.httpBody = try JSONEncoder().encode(["device_id": config.deviceId, "bundle_id": bundleId])
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(LaunchCheckResponse.self, from: data)
    }

    func heartbeat(bundleId: String, sessionStartedAt: Date) async throws -> HeartbeatResponse {
        let url = URL(string: "\(config.supabaseURL)/functions/v1/heartbeat")!
        var req = baseRequest(url: url, method: "POST")
        req.httpBody = try JSONEncoder().encode([
            "device_id":          config.deviceId,
            "bundle_id":          bundleId,
            "session_started_at": fmt.string(from: sessionStartedAt)
        ])
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(HeartbeatResponse.self, from: data)
    }

    func sessionEnd(bundleId: String, startedAt: Date, endedAt: Date) async throws {
        let url = URL(string: "\(config.supabaseURL)/functions/v1/session-end")!
        var req = baseRequest(url: url, method: "POST")
        let mins = max(0, Int(endedAt.timeIntervalSince(startedAt) / 60))
        req.httpBody = try JSONEncoder().encode([
            "device_id":          config.deviceId,
            "bundle_id":          bundleId,
            "session_started_at": fmt.string(from: startedAt),
            "ended_at":           fmt.string(from: endedAt),
            "duration_minutes":   String(mins)
        ])
        _ = try await session.data(for: req)
    }

    func killConfirm(bundleId: String, killEventId: String) async throws {
        let url = URL(string: "\(config.supabaseURL)/functions/v1/kill-confirm")!
        var req = baseRequest(url: url, method: "POST")
        req.httpBody = try JSONEncoder().encode([
            "device_id":     config.deviceId,
            "bundle_id":     bundleId,
            "kill_event_id": killEventId
        ])
        _ = try await session.data(for: req)
    }

    // MARK: - Private

    private func baseRequest(url: URL, method: String) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json",                 forHTTPHeaderField: "Content-Type")
        req.setValue(config.supabaseAnonKey,             forHTTPHeaderField: "apikey")
        return req
    }
}
