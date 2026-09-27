import Foundation
import Network

@MainActor
final class PrinterClient: ObservableObject {
    @Published var state = "Chưa kết nối"
    @Published var log = ""

    private func append(_ text: String) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        log += "[\(stamp)] \(text)\n"
    }

    func test(host: String, port: UInt16) {
        run(host: host, port: port, payload: nil)
    }

    func printTest(host: String, port: UInt16) {
        var data = Data([0x1B, 0x40]) // ESC @
        data.append(Data("XPRINTER HOTSPOT LAB\nTCP 9100: PASS\n\n\n".utf8))
        data.append(contentsOf: [0x1D, 0x56, 0x00]) // GS V 0
        run(host: host, port: port, payload: data)
    }

    private func run(host: String, port: UInt16, payload: Data?) {
        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let nwPort = NWEndpoint.Port(rawValue: port) else {
            state = "IP/port không hợp lệ"
            append(state)
            return
        }

        state = "Đang kết nối..."
        append("TCP → \(host):\(port)")
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        let started = Date()
        var finished = false

        func finish(_ message: String) {
            guard !finished else { return }
            finished = true
            Task { @MainActor in
                self.state = message
                self.append(message)
            }
            connection.cancel()
        }

        connection.stateUpdateHandler = { newState in
            switch newState {
            case .ready:
                let ms = Int(Date().timeIntervalSince(started) * 1000)
                if let payload {
                    connection.send(content: payload, completion: .contentProcessed { error in
                        if let error { finish("Gửi lỗi: \(error.localizedDescription)") }
                        else { finish("Đã gửi ESC/POS (\(payload.count) bytes), connect \(ms) ms") }
                    })
                } else {
                    finish("TCP CONNECT PASS (\(ms) ms)")
                }
            case .failed(let error):
                finish("TCP FAIL: \(error.localizedDescription)")
            case .waiting(let error):
                Task { @MainActor in
                    self.state = "Đang chờ: \(error.localizedDescription)"
                    self.append(self.state)
                }
            case .cancelled:
                break
            default:
                break
            }
        }

        connection.start(queue: DispatchQueue(label: "xprinter.lab.tcp"))
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            finish("TIMEOUT sau 5 giây")
        }
    }
}
