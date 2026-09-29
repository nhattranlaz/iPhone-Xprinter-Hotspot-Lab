import Foundation
import Network

@MainActor
final class PrinterTCPClient: ObservableObject {
    @Published var status = "Chưa kiểm tra"

    func test(ip: String) { connect(ip: ip, printData: nil) }

    func printTest(ip: String) {
        let bytes = Data([0x1B,0x40]) + Data("XPRINTER IOS CLEAN LAB\nTCP 9100 PASS\n\n\n".utf8)
        connect(ip: ip, printData: bytes)
    }

    private func connect(ip: String, printData: Data?) {
        guard !ip.isEmpty else { status = "Nhập IP máy in"; return }
        status = "Đang kết nối \(ip):9100…"
        let c = NWConnection(host: NWEndpoint.Host(ip), port: 9100, using: .tcp)
        c.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if let data = printData {
                    c.send(content: data, completion: .contentProcessed { error in
                        Task { @MainActor in self?.status = error == nil ? "PRINT PASS" : "PRINT FAIL: \(error!.localizedDescription)" }
                        c.cancel()
                    })
                } else {
                    Task { @MainActor in self?.status = "TCP 9100 PASS" }
                    c.cancel()
                }
            case .failed(let e):
                Task { @MainActor in self?.status = "TCP FAIL: \(e.localizedDescription)" }
            default: break
            }
        }
        c.start(queue: .global(qos: .userInitiated))
    }
}
