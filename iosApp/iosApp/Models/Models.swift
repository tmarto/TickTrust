import Foundation

enum DeviceType: String, CaseIterable, Identifiable, Codable {
    case iphone  = "iphone"
    case ipad    = "ipad"
    case mac     = "mac"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .iphone: return "iPhone"
        case .ipad:   return "iPad"
        case .mac:    return "MacBook"
        }
    }

    var systemImage: String {
        switch self {
        case .iphone: return "iphone"
        case .ipad:   return "ipad"
        case .mac:    return "laptopcomputer"
        }
    }
}

struct Child: Identifiable, Codable {
    let id: String
    let parentId: String
    var name: String
    var offlineMode: String
    var offlineGraceMin: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case parentId      = "parent_id"
        case offlineMode   = "offline_mode"
        case offlineGraceMin = "offline_grace_min"
    }
}

struct Device: Identifiable, Codable {
    let id: String
    let childId: String
    var name: String
    var type: DeviceType
    var lastSeenAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, type
        case childId     = "child_id"
        case lastSeenAt  = "last_seen_at"
    }
}

struct ManagedApp: Identifiable, Codable {
    let id: String
    let deviceId: String
    var bundleId: String
    var appName: String
    var dailyMinutes: Int
    var enabled: Bool

    enum CodingKeys: String, CodingKey {
        case id, enabled
        case deviceId     = "device_id"
        case bundleId     = "bundle_id"
        case appName      = "app_name"
        case dailyMinutes = "daily_minutes"
    }
}

struct TimeAccount: Codable {
    let childId: String
    let managedAppId: String
    let date: String
    var usedMinutes: Double
    var bonusMinutes: Int
    var debtMinutes: Int

    var availableMinutes: Int {
        let app_limit = 0 // resolved at call site
        return max(0, Int(Double(bonusMinutes - debtMinutes) - usedMinutes))
    }

    enum CodingKeys: String, CodingKey {
        case date
        case childId      = "child_id"
        case managedAppId = "managed_app_id"
        case usedMinutes  = "used_minutes"
        case bonusMinutes = "bonus_minutes"
        case debtMinutes  = "debt_minutes"
    }
}
