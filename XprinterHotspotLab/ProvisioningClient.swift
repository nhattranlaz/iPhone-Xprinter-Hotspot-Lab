import Foundation

@MainActor
final class ProvisioningClient: ObservableObject {
    @Published var state = "Chưa cấu hình"
    @Published var discoveredIP = ""
    private var task: ESPTouchTask?

    func provision(ssid: String, password: String, bssid: String) {
        let s = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { state = "Nhập tên Personal Hotspot"; return }
        state = "Đang gửi cấu hình ESP-Touch…"
        let effectiveBSSID = bssid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "00:00:00:00:00:00" : bssid
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let t = ESPTouchTask(apSsid: s, andApBssid: effectiveBSSID, andApPwd: password)
            t?.setPackageBroadcast(true)
            Task { @MainActor in self?.task = t }
            let result = t?.executeForResult()
            Task { @MainActor in
                guard let self else { return }
                if let result, result.isSuc {
                    self.discoveredIP = result.ipAddrData.flatMap { data in
                        let bytes = [UInt8](data)
                        return bytes.count == 4 ? bytes.map(String.init).joined(separator: ".") : nil
                    } ?? ""
                    self.state = self.discoveredIP.isEmpty ? "ESP-Touch PASS — máy in đã nhận Wi-Fi" : "ESP-Touch PASS — IP: \(self.discoveredIP)"
                } else if result?.isCancelled == true {
                    self.state = "Đã hủy cấu hình"
                } else {
                    self.state = "Chưa nhận được phản hồi từ Xprinter"
                }
            }
        }
    }

    func cancel() {
        task?.interrupt()
        state = "Đang hủy…"
    }
}
