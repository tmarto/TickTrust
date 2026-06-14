import Foundation

final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    let projectURL  = "https://xdwvhezjgmcptyncoipa.supabase.co"
    // Anon key — safe to embed in client app (RLS enforces access control)
    let anonKey     = "YOUR_SUPABASE_ANON_KEY"

    private var authToken: String?
    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private init() {}

    // MARK: - Auth

    func signIn(email: String, password: String) async throws {
        let url = URL(string: "\(projectURL)/auth/v1/token?grant_type=password")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONEncoder().encode(["email": email, "password": password])
        let (data, _) = try await session.data(for: req)
        struct AuthResponse: Decodable { let access_token: String }
        let resp = try JSONDecoder().decode(AuthResponse.self, from: data)
        authToken = resp.access_token
    }

    // MARK: - Children

    func fetchChildren(parentId: String) async throws -> [Child] {
        try await get("/rest/v1/children?parent_id=eq.\(parentId)&order=name")
    }

    func createChild(parentId: String, name: String) async throws -> Child {
        let body = ["parent_id": parentId, "name": name]
        return try await post("/rest/v1/children", body: body)
    }

    // MARK: - Devices

    func fetchDevices(childId: String) async throws -> [Device] {
        try await get("/rest/v1/devices?child_id=eq.\(childId)&order=name")
    }

    func createDevice(childId: String, name: String, type: DeviceType) async throws -> Device {
        struct Body: Encodable {
            let child_id: String
            let name: String
            let type: String
        }
        return try await post("/rest/v1/devices",
                              body: Body(child_id: childId, name: name, type: type.rawValue))
    }

    func deleteDevice(deviceId: String) async throws {
        try await delete("/rest/v1/devices?id=eq.\(deviceId)")
    }

    // MARK: - Managed Apps

    func fetchManagedApps(deviceId: String) async throws -> [ManagedApp] {
        try await get("/rest/v1/managed_apps?device_id=eq.\(deviceId)&order=app_name")
    }

    func createManagedApp(deviceId: String, bundleId: String, appName: String, dailyMinutes: Int) async throws -> ManagedApp {
        struct Body: Encodable {
            let device_id: String
            let bundle_id: String
            let app_name: String
            let daily_minutes: Int
        }
        return try await post("/rest/v1/managed_apps",
                              body: Body(device_id: deviceId, bundle_id: bundleId,
                                         app_name: appName, daily_minutes: dailyMinutes))
    }

    func updateManagedApp(appId: String, dailyMinutes: Int, enabled: Bool) async throws {
        struct Body: Encodable { let daily_minutes: Int; let enabled: Bool }
        try await patch("/rest/v1/managed_apps?id=eq.\(appId)",
                        body: Body(daily_minutes: dailyMinutes, enabled: enabled))
    }

    func deleteManagedApp(appId: String) async throws {
        try await delete("/rest/v1/managed_apps?id=eq.\(appId)")
    }

    // MARK: - Bonus

    func grantBonus(childId: String, parentId: String, minutes: Int, managedAppId: String? = nil) async throws {
        struct Body: Encodable {
            let child_id: String
            let granted_by: String
            let minutes: Int
            let managed_app_id: String?
        }
        let _: [String: String] = try await post(
            "/rest/v1/bonus_grants",
            body: Body(child_id: childId, granted_by: parentId,
                       minutes: minutes, managed_app_id: managedAppId)
        )
    }

    // MARK: - Install command helper

    func macInstallCommand(deviceId: String) -> String {
        """
        curl -fsSL https://raw.githubusercontent.com/tmarto/TickTrust/main/macOS/TickTrustAgent/install.sh \\
          | sudo bash -s -- \\
            "\(deviceId)" \\
            "\(anonKey)"
        """
    }

    // MARK: - HTTP helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        var req = baseRequest(path: path, method: "GET")
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(T.self, from: data)
    }

    private func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        var req = baseRequest(path: path, method: "POST")
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await session.data(for: req)
        // PostgREST returns array on insert; unwrap first element
        if let arr = try? decoder.decode([T].self, from: data), let first = arr.first {
            return first
        }
        return try decoder.decode(T.self, from: data)
    }

    private func patch<B: Encodable>(_ path: String, body: B) async throws {
        var req = baseRequest(path: path, method: "PATCH")
        req.httpBody = try JSONEncoder().encode(body)
        _ = try await session.data(for: req)
    }

    private func delete(_ path: String) async throws {
        let req = baseRequest(path: path, method: "DELETE")
        _ = try await session.data(for: req)
    }

    private func baseRequest(path: String, method: String) -> URLRequest {
        var req = URLRequest(url: URL(string: "\(projectURL)\(path)")!)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        if let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }
}
