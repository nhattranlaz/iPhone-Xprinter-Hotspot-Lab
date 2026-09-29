import Foundation

@MainActor
final class PrinterSetupService: ObservableObject {
    @Published var status = "Sẵn sàng"
    @Published var printerIP = ""
    @Published var isRunning = false
    private var task: ESPTouchTask?

    func configure(ssid: String, password: String, bssid: String?, omitBSSID: Bool) {
        let cleanSSID = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanSSID.isEmpty else { status = "Nhập SSID Wi-Fi"; return }

        let cleanBSSID = (bssid ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !omitBSSID && !cleanBSSID.isEmpty {
            let pattern = #"^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$"#
            guard cleanBSSID.range(of: pattern, options: .regularExpression) != nil else {
                status = "BSSID không đúng định dạng aa:bb:cc:dd:ee:ff"
                return
            }
        }

        let effectiveBSSID = omitBSSID ? "" : cleanBSSID
        printerIP = ""
        isRunning = true
        status = effectiveBSSID.isEmpty
            ? "Đang cấu hình Xprinter · không gửi BSSID"
            : "Đang cấu hình Xprinter · có BSSID"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let espTask = ESPTouchTask(apSsid: cleanSSID, andApBssid: effectiveBSSID, andApPwd: password)
            self?.task = espTask
            let result = espTask?.executeForResult()
            Task { @MainActor in
                guard let self else { return }
                self.isRunning = false
                if let result, result.isSuc {
                    let address = result.getAddressString() ?? ""
                    self.printerIP = address
                    self.status = address.isEmpty ? "ESP-Touch PASS · đã nhận ACK" : "ESP-Touch PASS · IP: \(address)"
                } else if result?.isCancelled == true {
                    self.status = "Đã hủy"
                } else {
                    self.status = "Hết thời gian ACK · chưa kết luận máy in không join mạng"
                }
            }
        }
    }

    func cancel() {
        task?.interrupt()
        isRunning = false
        status = "Đã hủy"
    }
}
