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
    case sunrise(minutes: Int)
    case powerOff

    /// One line of the Yeelight LAN protocol, without the trailing CRLF.
    public var json: String {
        switch self {
        case .sunrise(let minutes):
            let flow = Self.sunriseFlow(minutes: minutes)
            let steps = flow.count
            let expression = flow.map { "\($0.duration),\($0.mode),\($0.value),\($0.brightness)" }.joined(separator: ",")
            // count = number of steps, action 1 = stay on the last colour.
            return #"{"id":1,"method":"set_scene","params":["cf",\#(steps),1,"\#(expression)"]}"#
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

    /// Deep red at 1 % to daylight at 100 %, in five equal phases.
    static func sunriseFlow(minutes: Int) -> [FlowStep] {
        let phase = minutes * 60_000 / 5
        return [
            FlowStep(duration: 50, mode: 1, value: 0xFF1E00, brightness: 1),
            FlowStep(duration: phase, mode: 1, value: 0xFF4500, brightness: 10),
            FlowStep(duration: phase, mode: 1, value: 0xFF8C00, brightness: 25),
            FlowStep(duration: phase, mode: 2, value: 2200, brightness: 45),
            FlowStep(duration: phase, mode: 2, value: 3200, brightness: 70),
            FlowStep(duration: phase, mode: 2, value: 4500, brightness: 100),
        ]
    }
}
