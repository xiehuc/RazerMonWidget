import Foundation
import IOKit
import Darwin

/// One logical mouse, even when it switches between its cable and receiver.
/// Session currently selects one mouse; this identifier intentionally represents that slot.
struct BatteryPowerSourceDetails {
    let values: [String: Any]
    init(status: DeviceStatus) throws {
        guard let percent = status.batteryPercent, (0...100).contains(percent) else {
            throw NSError(domain: "RazerMonWidget", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid battery percentage"])
        }
        values = [
            "Type": "Accessory Source", "Name": status.name,
            "Accessory Identifier": "local.razermonwidget.\(status.serialNumber)",
            "Transport Type": "USB",
            "Accessory Category": status.kind == .keyboard ? "Keyboard" : status.kind == .mouse ? "Mouse" : "Unknown",
            "Is Present": true, "Is Charging": false,
            "Power Source State": "Battery Power",
            "Current Capacity": percent, "Max Capacity": 100, "Vendor ID": 0x1532,
        ]
    }
}

/// Private IOKit publishing API, resolved at runtime so an OS change fails gracefully.
final class BatteryPowerSource {
    private typealias Create = @convention(c) (UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> IOReturn
    private typealias SetDetails = @convention(c) (UnsafeMutableRawPointer, CFDictionary) -> IOReturn
    private typealias Release = @convention(c) (UnsafeMutableRawPointer) -> IOReturn
    private let create: Create
    private let setDetails: SetDetails
    private let release: Release
    private var source: UnsafeMutableRawPointer?
    private var previous: NSDictionary?

    init() throws {
        // IOKit is already linked; RTLD_DEFAULT searches the loaded images.
        let handle = UnsafeMutableRawPointer(bitPattern: -2)
        guard let c = dlsym(handle, "IOPSCreatePowerSource"),
              let s = dlsym(handle, "IOPSSetPowerSourceDetails"),
              let r = dlsym(handle, "IOPSReleasePowerSource") else {
            throw publishingError("this macOS version does not provide the accessory battery publishing API")
        }
        create = unsafeBitCast(c, to: Create.self)
        setDetails = unsafeBitCast(s, to: SetDetails.self)
        release = unsafeBitCast(r, to: Release.self)
    }

    /// Returns true only when a changed reading was published.
    @discardableResult func update(_ details: BatteryPowerSourceDetails) throws -> Bool {
        let dictionary = details.values as NSDictionary
        if previous?.isEqual(dictionary) == true { return false }
        if source == nil { try check(create(&source), operation: "create") }
        guard let source else { throw publishingError("IOPS returned no power source") }
        try check(setDetails(source, details.values as CFDictionary), operation: "publish")
        previous = dictionary
        return true
    }

    func remove() {
        if let source { _ = release(source) }
        source = nil
        previous = nil
    }

    deinit { remove() }

    private func check(_ result: IOReturn, operation: String) throws {
        guard result == kIOReturnSuccess else {
            throw publishingError("cannot \(operation) accessory battery: 0x\(String(UInt32(bitPattern: result), radix: 16))")
        }
    }
}

private func publishingError(_ message: String) -> NSError { NSError(domain: "RazerMonWidget", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
