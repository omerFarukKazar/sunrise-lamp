import Darwin
import Foundation
import Network

public protocol LampClientProtocol: Sendable {
    func discover(preferredIP: String?) async -> Lamp?
    func send(_ command: LampCommand, to lamp: Lamp) async throws
}

public enum LampError: LocalizedError, Equatable {
    case timedOut
    case connection(String)

    public var errorDescription: String? {
        switch self {
        case .timedOut: "Lamba cevap vermedi."
        case .connection(let reason): "Lambaya bağlanılamadı: \(reason)"
        }
    }
}

/// Talks to a Yeelight bulb over its LAN protocol: UDP 1982 for discovery,
/// TCP 55443 for commands. LAN Control must be on in the Yeelight app.
public struct YeelightClient: LampClientProtocol {
    private static let searchMessage = Array(
        "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1982\r\nMAN: \"ssdp:discover\"\r\nST: wifi_bulb\r\n".utf8
    )

    public init() {}

    public func discover(preferredIP: String?) async -> Lamp? {
        if let preferredIP, let lamp = Self.search(hosts: [preferredIP], timeout: 1.5) {
            return lamp
        }
        // The bulb answers unicast searches, so ask every host on the subnet
        // as well as the multicast group.
        guard let prefix = Self.localSubnetPrefix() else { return nil }
        let hosts = ["239.255.255.250"] + (1...254).map { "\(prefix).\($0)" }
        return Self.search(hosts: hosts, timeout: 3)
    }

    public func send(_ command: LampCommand, to lamp: Lamp) async throws {
        let connection = NWConnection(host: .init(lamp.ip), port: 55443, using: .tcp)
        defer { connection.cancel() }
        let data = Data((command.json + "\r\n").utf8)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = ResumeOnce(continuation)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: data, completion: .contentProcessed { error in
                        once.resume(error.map { .failure(LampError.connection($0.localizedDescription)) } ?? .success(()))
                    })
                case .failed(let error), .waiting(let error):
                    once.resume(.failure(LampError.connection(error.localizedDescription)))
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                once.resume(.failure(LampError.timedOut))
            }
        }
        // Give the bulb a moment to read the line before the socket closes.
        try? await Task.sleep(for: .seconds(1))
    }

    /// Sends the discovery search to each host and returns the first bulb that answers.
    private static func search(hosts: [String], timeout: TimeInterval) -> Lamp? {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        for host in hosts {
            var address = sockaddr_in()
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = in_port_t(1982).bigEndian
            guard inet_pton(AF_INET, host, &address.sin_addr) == 1 else { continue }
            _ = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(fd, searchMessage, searchMessage.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }

        let deadline = Date().addingTimeInterval(timeout)
        var buffer = [UInt8](repeating: 0, count: 2048)
        while Date() < deadline {
            var descriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let remaining = Int32(max(deadline.timeIntervalSinceNow, 0) * 1000)
            guard poll(&descriptor, 1, remaining) > 0 else { break }
            let count = recv(fd, &buffer, buffer.count, 0)
            guard count > 0 else { continue }
            if let lamp = Lamp(discoveryResponse: String(decoding: buffer[0..<count], as: UTF8.self)) {
                return lamp
            }
        }
        return nil
    }

    /// The first three octets of the device's Wi-Fi/Ethernet IPv4 address, e.g. "192.168.1".
    private static func localSubnetPrefix() -> String? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0 else { return nil }
        defer { freeifaddrs(list) }

        var cursor = list
        while let entry = cursor?.pointee {
            defer { cursor = entry.ifa_next }
            guard let address = entry.ifa_addr, address.pointee.sa_family == sa_family_t(AF_INET),
                  String(cString: entry.ifa_name).hasPrefix("en")
            else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0
            else { continue }
            let octets = String(decoding: host.prefix { $0 != 0 }.map(UInt8.init), as: UTF8.self).split(separator: ".")
            guard octets.count == 4 else { continue }
            return octets.prefix(3).joined(separator: ".")
        }
        return nil
    }
}

/// Resumes a continuation exactly once, whichever callback gets there first.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?

    init(_ continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<Void, Error>) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(with: result)
    }
}
