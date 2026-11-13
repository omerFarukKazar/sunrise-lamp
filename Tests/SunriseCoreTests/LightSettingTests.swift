import Foundation
import Testing
@testable import SunriseCore

@Suite("LightSetting")
struct LightSettingTests {
    @Test("White light uses a ct scene that also turns the bulb on")
    func whiteCommand() {
        let json = LightSetting(mode: .white, kelvin: 4000, rgb: 0, brightness: 70).command.json
        #expect(json == #"{"id":1,"method":"set_scene","params":["ct",4000,70]}"#)
    }

    @Test("Colour uses a color scene")
    func colorCommand() {
        let json = LightSetting(mode: .color, kelvin: 4000, rgb: 0xFF4500, brightness: 30).command.json
        #expect(json == #"{"id":1,"method":"set_scene","params":["color",16729344,30]}"#)
    }

    @Test("Out-of-range values are clamped to what the bulb accepts")
    func clamps() {
        #expect(LampCommand.temperature(kelvin: 9000, brightness: 0).json.contains(#"["ct",6500,1]"#))
        #expect(LampCommand.temperature(kelvin: 1000, brightness: 300).json.contains(#"["ct",1700,100]"#))
    }

    @Test("Warm white looks orange, cool white looks near white")
    func kelvinColour() {
        let warm = LightSetting.rgb(forKelvin: 1700)
        let cool = LightSetting.rgb(forKelvin: 6500)
        #expect(warm >> 16 == 255 && warm & 0xFF < 80)
        #expect(cool & 0xFF > 240)
    }

    @Test("A schedule saved before endKelvin existed still loads")
    func oldScheduleDecodes() throws {
        let json = #"{"wakeHour":7,"wakeMinute":30,"durationMinutes":30,"weekdays":[1,2],"isEnabled":true}"#
        let schedule = try JSONDecoder().decode(SunriseSchedule.self, from: Data(json.utf8))
        #expect(schedule.endKelvin == SunriseSchedule.defaultEndKelvin)
        #expect(schedule.wakeHour == 7)
    }
}
