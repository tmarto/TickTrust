import Foundation

struct Config {
    let supabaseURL: String
    let supabaseAnonKey: String
    let deviceId: String
    let offlineMode: String        // "strict" | "lenient"
    let offlineGraceMinutes: Int

    static let configPath = "/Library/Application Support/TickTrust/config.plist"

    static func load() -> Config {
        guard
            let dict = NSDictionary(contentsOfFile: configPath) as? [String: Any],
            let url  = dict["supabase_url"]       as? String,
            let key  = dict["supabase_anon_key"]  as? String,
            let did  = dict["device_id"]          as? String
        else {
            fatalError("[TickTrust] Missing or invalid config at \(configPath)")
        }
        return Config(
            supabaseURL: url,
            supabaseAnonKey: key,
            deviceId: did,
            offlineMode: dict["offline_mode"] as? String ?? "strict",
            offlineGraceMinutes: dict["offline_grace_minutes"] as? Int ?? 30
        )
    }
}
