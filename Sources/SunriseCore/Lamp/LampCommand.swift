import Foundation

public struct Lamp: Codable, Equatable, Sendable {
    public let id: String
    public let ip: String
    public let model: String

    public init(id: String, ip: String, model: String) {
        self.id = id
        self.ip = ip
        self.model = model
    }

    /// Parses the bulb's answer to the `wifi_bulb` discovery search.
    public init?(discoveryResponse text: String) {
        var headers: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }
        guard let location = headers["location"], location.hasPrefix("yeelight://"),
              let id = headers["id"]
        else { return nil }
        let hostPort = location.dropFirst("yeelight://".count)
        let ip = hostPort.split(separator: ":").first.map(String.init) ?? ""
        guard !ip.isEmpty else { return nil }
        self.init(id: id, ip: ip, model: headers["model"] ?? "")
    }
}

public enum LampCommand: Equatable, Sendable {
    case sunrise(minutes: Int, endKelvin: Int)
    case sunset(minutes: Int)
    /// White light; turns the bulb on if it is off.
    case temperature(kelvin: Int, brightness: Int)
    /// A colour as 0xRRGGBB; turns the bulb on if it is off.
    case color(rgb: Int, brightness: Int)
    case powerOn
    case powerOff

    /// One line of the Yeelight LAN protocol, without the trailing CRLF.
    public var json: String {
        switch self {
        case .sunrise(let minutes, let endKelvin):
            // Action 1 = stay on the last colour.
            return Self.scene(Self.sunriseFlow(minutes: minutes, endKelvin: endKelvin), endAction: 1)
        case .sunset(let minutes):
            // Action 2 = turn the light off after the last step.
            return Self.scene(Self.sunsetFlow(minutes: minutes), endAction: 2)
        case .temperature(let kelvin, let brightness):
            let kelvin = LightSetting.kelvinRange.clamp(kelvin)
            return #"{"id":1,"method":"set_scene","params":["ct",\#(kelvin),\#(LightSetting.brightnessRange.clamp(brightness))]}"#
        case .color(let rgb, let brightness):
            let rgb = min(max(rgb, 0), 0xFFFFFF)
            return #"{"id":1,"method":"set_scene","params":["color",\#(rgb),\#(LightSetting.brightnessRange.clamp(brightness))]}"#
        case .powerOn:
            return #"{"id":1,"method":"set_power","params":["on","smooth",500]}"#
        case .powerOff:
            return #"{"id":1,"method":"set_power","params":["off","smooth",500]}"#
        }
    }

    struct FlowStep: Equatable {
        let duration: Int
        /// 1 = RGB, 2 = colour temperature.
        let mode: Int
        let value: Int
        let brightness: Int
    }

    /// A colour flow scene; count = number of steps, so the flow runs once.
    private static func scene(_ flow: [FlowStep], endAction: Int) -> String {
        let expression = flow.map { "\($0.duration),\($0.mode),\($0.value),\($0.brightness)" }.joined(separator: ",")
        return #"{"id":1,"method":"set_scene","params":["cf",\#(flow.count),\#(endAction),"\#(expression)"]}"#
    }

    /// Deep red at 1 % to white at 100 %, in five equal phases.
    static func sunriseFlow(minutes: Int, endKelvin: Int) -> [FlowStep] {
        let phase = minutes * 60_000 / 5
        let end = SunriseSchedule.endKelvinRange.clamp(endKelvin)
        return [
            FlowStep(duration: 50, mode: 1, value: 0xFF1E00, brightness: 1),
            FlowStep(duration: phase, mode: 1, value: 0xFF4500, brightness: 10),
            FlowStep(duration: phase, mode: 1, value: 0xFF8C00, brightness: 25),
            FlowStep(duration: phase, mode: 2, value: 2200, brightness: 45),
            FlowStep(duration: phase, mode: 2, value: min(3200, end), brightness: 70),
            FlowStep(duration: phase, mode: 2, value: end, brightness: 100),
        ]
    }

    /// The sunrise in reverse: from the current light through warm white and
    /// orange to a dim red, in four equal phases, then off.
    static func sunsetFlow(minutes: Int) -> [FlowStep] {
        let phase = minutes * 60_000 / 4
        return [
            FlowStep(duration: phase, mode: 2, value: 2700, brightness: 50),
            FlowStep(duration: phase, mode: 1, value: 0xFF8C00, brightness: 25),
            FlowStep(duration: phase, mode: 1, value: 0xFF4500, brightness: 8),
            FlowStep(duration: phase, mode: 1, value: 0xFF1E00, brightness: 1),
        ]
    }
}
