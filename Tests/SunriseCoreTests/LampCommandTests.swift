import Foundation
import Testing
@testable import SunriseCore

@Suite("LampCommand")
struct LampCommandTests {
    @Test("Sunset scene runs once and turns the light off at the end")
    func sunsetTurnsOff() {
        let json = LampCommand.sunset(minutes: 20).json
        let steps = LampCommand.sunsetFlow(minutes: 20)
        #expect(json.contains(#""cf",4,2,"#))
        #expect(steps.map(\.duration).reduce(0, +) == 20 * 60_000)
        #expect(steps.last?.brightness == 1)
    }

    @Test("Sunrise scene count matches the number of steps")
    func sunriseCount() {
        let json = LampCommand.sunrise(minutes: 30, endKelvin: 5000).json
        let steps = LampCommand.sunriseFlow(minutes: 30, endKelvin: 5000)
        #expect(json.contains(#""cf",\#(steps.count),1,"#))
        #expect(json.hasPrefix(#"{"id":1,"method":"set_scene""#))
    }

    @Test("Sunrise starts deep red and ends at the chosen white, phases fill the duration")
    func sunriseFlow() {
        let steps = LampCommand.sunriseFlow(minutes: 30, endKelvin: 6500)
        #expect(steps.first == .init(duration: 50, mode: 1, value: 0xFF1E00, brightness: 1))
        #expect(steps.last?.brightness == 100)
        #expect(steps.last?.mode == 2 && steps.last?.value == 6500)
        #expect(steps.dropFirst().map(\.duration).reduce(0, +) == 30 * 60_000)
    }

    @Test("Discovery response is parsed into a lamp")
    func parseDiscovery() {
        let response = "HTTP/1.1 200 OK\r\nCache-Control: max-age=3600\r\nLocation: yeelight://192.168.1.9:55443\r\nid: 0x000000001b375de2\r\nmodel: colorb\r\npower: on\r\n"
        #expect(Lamp(discoveryResponse: response) == Lamp(id: "0x000000001b375de2", ip: "192.168.1.9", model: "colorb"))
    }

    @Test("Unrelated SSDP answers are ignored")
    func ignoreOtherDevices() {
        #expect(Lamp(discoveryResponse: "HTTP/1.1 200 OK\r\nLocation: http://192.168.1.1/desc.xml\r\n") == nil)
    }
}
