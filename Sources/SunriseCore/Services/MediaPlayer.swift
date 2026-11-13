import Foundation
#if os(macOS)
import AppKit
import AVFoundation
#endif

/// What plays when the sunrise reaches daylight.
public enum WakeMedia: Codable, Equatable, Sendable {
    /// A web link, e.g. a YouTube video, opened in the default browser.
    case link(URL)
    /// A local audio file played by the app itself.
    case file(URL)

    /// Accepts a pasted web link; returns nil for anything that is not http(s).
    public init?(link text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https", url.host != nil
        else { return nil }
        self = .link(url)
    }

    public var title: String {
        switch self {
        case .link(let url): url.host.map { "\($0)\(url.path)" } ?? url.absoluteString
        case .file(let url): url.lastPathComponent
        }
    }
}

@MainActor
public protocol MediaPlayerProtocol: AnyObject {
    /// Starts the media; with a `fadeIn` it begins quiet and gets louder over
    /// that many seconds.
    func play(_ media: WakeMedia, fadeIn: TimeInterval) -> Bool
    func stop()
}

#if os(macOS)
@MainActor
public final class MediaPlayer: MediaPlayerProtocol {
    private var player: AVAudioPlayer?
    private var ramp: Task<Void, Never>?

    public init() {}

    public func play(_ media: WakeMedia, fadeIn: TimeInterval) -> Bool {
        stop()
        switch media {
        case .link(let url):
            // The browser plays the video, so the fade runs on the Mac's own volume.
            let target = SystemVolume.audibleLevel()
            if fadeIn > 0 { SystemVolume.set(0) }
            guard NSWorkspace.shared.open(url) else {
                SystemVolume.set(target)
                return false
            }
            if fadeIn > 0 { rampSystemVolume(to: target, over: fadeIn) }
            return true
        case .file(let url):
            guard let player = try? AVAudioPlayer(contentsOf: url) else { return false }
            self.player = player
            if fadeIn > 0 {
                // Loop while the light rises, then let the current pass finish.
                player.numberOfLoops = -1
                player.volume = 0
                SystemVolume.set(SystemVolume.audibleLevel())
                ramp = Task { [weak player] in
                    try? await Task.sleep(for: .seconds(fadeIn))
                    player?.numberOfLoops = 0
                }
            }
            guard player.play() else { return false }
            if fadeIn > 0 { player.setVolume(1, fadeDuration: fadeIn) }
            return true
        }
    }

    public func stop() {
        ramp?.cancel()
        ramp = nil
        player?.stop()
        player = nil
    }

    /// Raises the volume in small steps; stops if someone changes it by hand.
    private func rampSystemVolume(to target: Int, over duration: TimeInterval) {
        let interval: TimeInterval = 5
        let steps = max(1, Int(duration / interval))
        ramp = Task {
            var last = 0
            for step in 1...steps {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled, abs(SystemVolume.current() - last) <= 2 else { return }
                last = target * step / steps
                SystemVolume.set(last)
            }
        }
    }
}

/// The Mac's output volume, 0–100.
@MainActor
enum SystemVolume {
    /// The volume to fade up to: the current level, or half when muted or silent.
    static func audibleLevel() -> Int {
        let level = current()
        return level > 0 && !isMuted() ? level : 50
    }

    static func current() -> Int {
        Int(run("output volume of (get volume settings)")?.int32Value ?? 0)
    }

    static func set(_ level: Int) {
        _ = run("set volume output volume \(min(max(level, 0), 100)) without output muted")
    }

    private static func isMuted() -> Bool {
        run("output muted of (get volume settings)")?.booleanValue ?? false
    }

    private static func run(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        return NSAppleScript(source: source)?.executeAndReturnError(&error)
    }
}
#endif
