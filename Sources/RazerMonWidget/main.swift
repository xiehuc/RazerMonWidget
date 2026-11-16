import Foundation
import Darwin

private var stopped: sig_atomic_t = 0

final class WidgetService {
    private let registry = HIDDeviceRegistry()
    private var changed = true
    private var publishers: [String: BatteryPowerSource] = [:]
    private var cache: [String: CachedDeviceStatus] = [:]

    func run() throws {
        // Resolve the private API before starting the service, so unsupported OSes fail clearly.
        _ = try BatteryPowerSource()
        let oldINT = signal(SIGINT) { _ in stopped = 1 }
        let oldTERM = signal(SIGTERM) { _ in stopped = 1 }
        defer {
            publishers.removeAll()
            signal(SIGINT, oldINT)
            signal(SIGTERM, oldTERM)
        }
        registry.onChange = { [weak self] _ in self?.changed = true }
        try registry.start()
        var nextRead = Date.distantPast
        var lastError: String?
        log("Watching Razer HID devices; publishing accessory batteries.")
        while stopped == 0 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            let connected = registry.connectedProductIDs
            // Remove only on physical receiver removal; sleeping devices retain their reading.
            for (serial, cached) in cache {
                if let receiver = cached.status.receiverProductID, !connected.contains(receiver) {
                    publishers.removeValue(forKey: serial)?.remove()
                    cache.removeValue(forKey: serial)
                }
            }
            guard changed || Date() >= nextRead else { continue }
            changed = false
            nextRead = Date().addingTimeInterval(60)
            guard !connected.isEmpty else { continue }
            do {
                let devices = try RazerMonitor.readDevices(
                    connectedProductIDs: connected, cachedDevices: cache,
                    batteryMaximumAge: 60, forceBatteryRefresh: false, onDiscovery: { _ in })
                for device in devices {
                    let serial = device.status.serialNumber
                    let publisher = try publishers[serial] ?? BatteryPowerSource()
                    if try publisher.update(BatteryPowerSourceDetails(status: device.status)) {
                        log("\(device.status.name) [\(serial)]: \(device.status.batteryPercent!)%")
                    }
                    publishers[serial] = publisher
                    cache[serial] = device
                }
                // Per-device read failures are represented by an old cache entry or omitted result.
                if devices.isEmpty || devices.contains(where: { Date().timeIntervalSince($0.batteryReadAt) >= 60 }) {
                    nextRead = Date().addingTimeInterval(5)
                }
                lastError = nil
            } catch {
                let message = String(describing: error)
                if message != lastError { log(message); lastError = message }
                nextRead = Date().addingTimeInterval(5)
            }
        }
        log("Stopped; removing system battery entries.")
    }
}

private func log(_ text: String) {
    FileHandle.standardError.write(Data("RazerMonWidget: \(text)\n".utf8))
}

do {
    switch Array(CommandLine.arguments.dropFirst()) {
    case [], ["--battery-widget"]:
        let service = WidgetService()
        try withExtendedLifetime(service) { try service.run() }
    case ["--install-service"]: try BatteryService.install()
    case ["--uninstall-service"]: try BatteryService.uninstall()
    case ["--help"], ["-h"]:
        print("RazerMonWidget [--battery-widget | --install-service | --uninstall-service | --help]")
    default:
        throw NSError(domain: "RazerMonWidget", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Unknown arguments; use --help"])
    }
} catch {
    log((error as NSError).localizedDescription)
    exit(1)
}
