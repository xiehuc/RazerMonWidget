import XCTest
@testable import RazerMonWidget

final class BatteryPublishingTests: XCTestCase {
    func testSeparateDevicesHaveStableDistinctIdentifiersAndCategories() throws {
        let mouse = try BatteryPowerSourceDetails(status: DeviceStatus(name: "Mouse", kind: .mouse, serialNumber: "M1", batteryPercent: 40))
        let keyboard = try BatteryPowerSourceDetails(status: DeviceStatus(name: "Keyboard", kind: .keyboard, serialNumber: "K1", batteryPercent: 60))
        XCTAssertNotEqual(mouse.values["Accessory Identifier"] as? String, keyboard.values["Accessory Identifier"] as? String)
        XCTAssertEqual(mouse.values["Accessory Category"] as? String, "Mouse")
        XCTAssertEqual(keyboard.values["Accessory Category"] as? String, "Keyboard")
        XCTAssertEqual(keyboard.values["Current Capacity"] as? Int, 60)
        XCTAssertEqual(keyboard.values["Max Capacity"] as? Int, 100)
    }

    func testMissingOrInvalidBatteryIsNotPublished() {
        for percent: Int? in [nil, -1, 101] {
            XCTAssertThrowsError(try BatteryPowerSourceDetails(status: DeviceStatus(name: "Mouse", kind: .mouse, serialNumber: "M1", batteryPercent: percent)))
        }
    }
}
