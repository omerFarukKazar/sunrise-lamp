import Foundation

@MainActor
public protocol SettingsStoreProtocol: AnyObject {
    var schedule: SunriseSchedule { get set }
    var lamp: Lamp? { get set }
    var light: LightSetting { get set }
    /// The sunrise length the Shortcuts automation was last set up for, or nil
    /// before the user has set one up.
    var automationMinutes: Int? { get set }
}

/// Keeps everything in the app's own preferences, no separate files.
@MainActor
public final class SettingsStore: SettingsStoreProtocol {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var schedule: SunriseSchedule {
        get { read("schedule") ?? .default }
        set { write(newValue, "schedule") }
    }

    public var lamp: Lamp? {
        get { read("lamp") }
        set { write(newValue, "lamp") }
    }

    public var light: LightSetting {
        get { read("light") ?? .default }
        set { write(newValue, "light") }
    }

    public var automationMinutes: Int? {
        get { read("automationMinutes") }
        set { write(newValue, "automationMinutes") }
    }

    private func read<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ value: T?, _ key: String) {
        guard let value, let data = try? JSONEncoder().encode(value) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }
}
