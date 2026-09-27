import Foundation
import Darwin

struct InterfaceRecord: Identifiable {
    let id = UUID()
    let name: String
    let index: UInt32
    let address: String
    let netmask: String
    let broadcast: String
    let flags: UInt32
}

struct ProbeRecord: Identifiable {
    let id = UUID()
    let timestamp: Date
    let interface: String
    let source: String
    let destination: String
    let result: String
    let errnoCode: Int32
}

@MainActor
final class HotspotDiagnostic: ObservableObject {
    @Published var interfaces: [InterfaceRecord] = []
    @Published var probes: [ProbeRecord] = []
    @Published var status = "Chưa chạy diagnostic"

    func refresh() {
        interfaces = Self.enumerateIPv4()
        status = "Tìm thấy \(interfaces.count) IPv4 interface đang UP"
    }

    func probeAll(port: UInt16 = 18266) {
        refresh()
        probes.removeAll()
        let candidates = interfaces
        status = "Đang probe UDP broadcast…"
        DispatchQueue.global(qos: .userInitiated).async {
            let results = candidates.map { Self.probe($0, port: port) }
            Task { @MainActor in
                self.probes = results
                let ok = results.filter { $0.errnoCode == 0 }.count
                self.status = "Probe xong: \(ok)/\(results.count) sendto() PASS"
            }
        }
    }

    private static func enumerateIPv4() -> [InterfaceRecord] {
        var ptr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ptr) == 0, let first = ptr else { return [] }
        defer { freeifaddrs(ptr) }
        var out: [InterfaceRecord] = []
        var p: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = p {
            let item = cur.pointee
            defer { p = item.ifa_next }
            guard let addr = item.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let flags = item.ifa_flags
            guard (flags & UInt32(IFF_UP)) != 0 else { continue }
            let name = String(cString: item.ifa_name)
            let ip = stringIPv4(addr)
            let mask = item.ifa_netmask.map(stringIPv4) ?? ""
            var broadcast = ""
            if let dst = item.ifa_dstaddr { broadcast = stringIPv4(dst) }
            if broadcast.isEmpty, let computed = computeBroadcast(ip: ip, mask: mask) { broadcast = computed }
            out.append(.init(name: name, index: if_nametoindex(name), address: ip, netmask: mask, broadcast: broadcast, flags: flags))
        }
        return out.sorted { $0.name < $1.name }
    }

    private static func stringIPv4(_ sa: UnsafePointer<sockaddr>) -> String {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        var copy = sa.pointee
        let len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let rc = withUnsafePointer(to: &copy) {
            getnameinfo($0, len, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
        }
        return rc == 0 ? String(cString: host) : ""
    }

    private static func computeBroadcast(ip: String, mask: String) -> String? {
        var a = in_addr(), m = in_addr()
        guard inet_pton(AF_INET, ip, &a) == 1, inet_pton(AF_INET, mask, &m) == 1 else { return nil }
        let host = ntohl(a.s_addr), nm = ntohl(m.s_addr)
        var b = in_addr(s_addr: htonl(host | ~nm))
        var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &b, &buf, socklen_t(INET_ADDRSTRLEN)) != nil else { return nil }
        return String(cString: buf)
    }

    private static func probe(_ iface: InterfaceRecord, port: UInt16) -> ProbeRecord {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else {
            return .init(timestamp: Date(), interface: iface.name, source: iface.address, destination: iface.broadcast, result: "socket FAIL", errnoCode: errno)
        }
        defer { close(fd) }

        var yes: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout.size(ofValue: yes)))

        var index = iface.index
        let boundIfRC = setsockopt(fd, IPPROTO_IP, IP_BOUND_IF, &index, socklen_t(MemoryLayout.size(ofValue: index)))
        if boundIfRC != 0 {
            let e = errno
            return .init(timestamp: Date(), interface: iface.name, source: iface.address, destination: iface.broadcast, result: "IP_BOUND_IF FAIL", errnoCode: e)
        }

        var source = sockaddr_in()
        source.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        source.sin_family = sa_family_t(AF_INET)
        source.sin_port = 0
        inet_pton(AF_INET, iface.address, &source.sin_addr)
        let bindRC = withUnsafePointer(to: &source) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        if bindRC != 0 {
            let e = errno
            return .init(timestamp: Date(), interface: iface.name, source: iface.address, destination: iface.broadcast, result: "bind FAIL", errnoCode: e)
        }

        guard !iface.broadcast.isEmpty else {
            return .init(timestamp: Date(), interface: iface.name, source: iface.address, destination: "", result: "No broadcast address", errnoCode: EDESTADDRREQ)
        }
        var dst = sockaddr_in()
        dst.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        dst.sin_family = sa_family_t(AF_INET)
        dst.sin_port = port.bigEndian
        inet_pton(AF_INET, iface.broadcast, &dst.sin_addr)
        let payload = Array("WWT2-HOTSPOT-DIAG".utf8)
        let sent = payload.withUnsafeBytes { bytes in
            withUnsafePointer(to: &dst) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(fd, bytes.baseAddress, bytes.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        if sent < 0 {
            let e = errno
            return .init(timestamp: Date(), interface: iface.name, source: iface.address, destination: "\(iface.broadcast):\(port)", result: "sendto FAIL", errnoCode: e)
        }
        return .init(timestamp: Date(), interface: iface.name, source: iface.address, destination: "\(iface.broadcast):\(port)", result: "SOCKET_SEND_PASS bytes=\(sent)", errnoCode: 0)
    }
}
