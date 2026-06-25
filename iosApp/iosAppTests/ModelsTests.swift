import XCTest
@testable import iosApp

final class ModelsTests: XCTestCase {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    // MARK: - DeviceType

    func testDeviceTypeRawValuesAndDisplay() {
        XCTAssertEqual(DeviceType.iphone.rawValue, "iphone")
        XCTAssertEqual(DeviceType.ipad.rawValue, "ipad")
        XCTAssertEqual(DeviceType.mac.rawValue, "mac")

        XCTAssertEqual(DeviceType.iphone.displayName, "iPhone")
        XCTAssertEqual(DeviceType.ipad.displayName, "iPad")
        XCTAssertEqual(DeviceType.mac.displayName, "MacBook")

        XCTAssertEqual(DeviceType.iphone.systemImage, "iphone")
        XCTAssertEqual(DeviceType.ipad.systemImage, "ipad")
        XCTAssertEqual(DeviceType.mac.systemImage, "laptopcomputer")
    }

    func testDeviceTypeCaseIterableAndID() {
        XCTAssertEqual(DeviceType.allCases.count, 3)
        for type in DeviceType.allCases {
            XCTAssertEqual(type.id, type.rawValue)
        }
    }

    // MARK: - TimeAccount.availableMinutes

    func testAvailableMinutesBasic() {
        let acc = TimeAccount(childId: "c", managedAppId: "m", date: "2026-06-01",
                              usedMinutes: 30, bonusMinutes: 60, debtMinutes: 0)
        XCTAssertEqual(acc.availableMinutes, 30)
    }

    func testAvailableMinutesClampsToZero() {
        let acc = TimeAccount(childId: "c", managedAppId: "m", date: "2026-06-01",
                              usedMinutes: 50, bonusMinutes: 10, debtMinutes: 0)
        XCTAssertEqual(acc.availableMinutes, 0)
    }

    func testAvailableMinutesSubtractsDebt() {
        let acc = TimeAccount(childId: "c", managedAppId: "m", date: "2026-06-01",
                              usedMinutes: 0, bonusMinutes: 30, debtMinutes: 20)
        XCTAssertEqual(acc.availableMinutes, 10)
    }

    func testAvailableMinutesTruncatesFractionalUsage() {
        let acc = TimeAccount(childId: "c", managedAppId: "m", date: "2026-06-01",
                              usedMinutes: 29.5, bonusMinutes: 60, debtMinutes: 0)
        XCTAssertEqual(acc.availableMinutes, 30)
    }

    // MARK: - Codable (PostgREST snake_case)

    func testChildDecodesSnakeCase() throws {
        let json = """
        {"id":"c1","name":"Ana","parent_id":"p1","offline_mode":"strict","offline_grace_min":30}
        """.data(using: .utf8)!
        let child = try decoder.decode(Child.self, from: json)
        XCTAssertEqual(child.id, "c1")
        XCTAssertEqual(child.name, "Ana")
        XCTAssertEqual(child.parentId, "p1")
        XCTAssertEqual(child.offlineMode, "strict")
        XCTAssertEqual(child.offlineGraceMin, 30)
    }

    func testDeviceDecodesAndRoundTrips() throws {
        let json = """
        {"id":"d1","child_id":"c1","name":"iPhone","type":"iphone","last_seen_at":null}
        """.data(using: .utf8)!
        let device = try decoder.decode(Device.self, from: json)
        XCTAssertEqual(device.id, "d1")
        XCTAssertEqual(device.childId, "c1")
        XCTAssertEqual(device.type, .iphone)
        XCTAssertNil(device.lastSeenAt)

        let reDecoded = try decoder.decode(Device.self, from: try encoder.encode(device))
        XCTAssertEqual(reDecoded, device)
    }

    func testManagedAppDecodes() throws {
        let json = """
        {"id":"a1","device_id":"d1","bundle_id":"com.mojang.minecraftpe",
         "app_name":"Minecraft","daily_minutes":65,"enabled":true}
        """.data(using: .utf8)!
        let app = try decoder.decode(ManagedApp.self, from: json)
        XCTAssertEqual(app.deviceId, "d1")
        XCTAssertEqual(app.bundleId, "com.mojang.minecraftpe")
        XCTAssertEqual(app.appName, "Minecraft")
        XCTAssertEqual(app.dailyMinutes, 65)
        XCTAssertTrue(app.enabled)
    }

    // MARK: - SupabaseService helper

    func testMacInstallCommandIncludesDeviceID() {
        let cmd = SupabaseService.shared.macInstallCommand(deviceId: "device-123")
        XCTAssertTrue(cmd.contains("device-123"))
        XCTAssertTrue(cmd.contains("install.sh"))
        XCTAssertTrue(cmd.contains("sudo bash"))
    }
}
