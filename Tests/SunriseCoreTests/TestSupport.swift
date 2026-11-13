import Foundation
@testable import SunriseCore

let bulb = Lamp(id: "0x1", ip: "192.168.1.9", model: "colorb")

final class MockLampClient: LampClientProtocol, @unchecked Sendable {
    var discovered: Lamp? = bulb
    var failSends = 0
    private(set) var sent: [LampCommand] = []

    func discover(preferredIP: String?) async -> Lamp? { discovered }

    func send(_ command: LampCommand, to lamp: Lamp) async throws {
        if failSends > 0 {
            failSends -= 1
            throw LampError.timedOut
        }
        sent.append(command)
    }
}

@MainActor
final class MockStore: SettingsStoreProtocol {
    var schedule: SunriseSchedule = .default
    var lamp: Lamp?
}
