import Foundation

@MainActor
final class PrinterProvisioner: ObservableObject {
    @Published var status = "Sẵn sàng"
    @Published var printerIP = ""
    @Published var running = false
    private var task: ESPTouchTask?

    func start(ssid: String, password: String, bssid: String, omitBSSID: Bool) {
        let s = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = bssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { status = "Nhập SSID"; return }
        if !omitBSSID && !b.isEmpty {
            let p = #"^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$"#
            guard b.range(of: p, options: .regularExpression) != nil else {
                status = "BSSID không đúng định dạng"; return
            }
        }

        let sentBSSID = omitBSSID ? "" : b
        printerIP = ""
        running = true
        status = sentBSSID.isEmpty ? "Đang cấu hình · không gửi BSSID" : "Đang cấu hình · có BSSID"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let t = ESPTouchTask(apSsid: s, andApBssid: sentBSSID, andApPwd: password)
            self?.task = t
            let result = t?.executeForResult()
            Task { @MainActor in
                guard let self else { return }
                self.running = false
                if let result, result.isSuc {
                    let ip = result.getAddressString() ?? ""
                    self.printerIP = ip
                    self.status = ip.isEmpty ? "ESP-Touch PASS" : "ESP-Touch PASS · IP: \(ip)"
                } else {
                    self.status = "Không nhận ACK · chưa kết luận máy in không join mạng"
                }
            }
        }
    }
}
