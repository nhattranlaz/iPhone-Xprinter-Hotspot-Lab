import Foundation

@MainActor
final class ProvisioningClient: NSObject, ObservableObject, ESPProvisionerDelegate {
    @Published var state = "Chưa cấu hình"
    @Published var discoveredIP = ""
    @Published var engine = ""
    private var v1Task: ESPTouchTask?

    func provisionV1(ssid: String, password: String) {
        let s = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { state = "Nhập tên Personal Hotspot"; return }
        engine = "ESP-Touch V1 Multicast"
        state = "V1 Multicast: đang gửi Guide/Datum packets…"
        discoveredIP = ""
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Do not invent a BSSID. Empty string lets the SDK encode only the information we actually have.
            let task = ESPTouchTask(apSsid: s, andApBssid: "", andApPwd: password)
            // Original ESP-Touch V1 multicast sequence (234.x.x.x).\n            task?.setPackageBroadcast(false)
            Task { @MainActor in self?.v1Task = task }
            let result = task?.executeForResult()
            Task { @MainActor in
                guard let self else { return }
                if let result, result.isSuc {
                    self.discoveredIP = result.getAddressString() ?? ""
                    self.state = self.discoveredIP.isEmpty ? "V1 PASS — máy in đã nhận Wi-Fi" : "V1 PASS — IP: \(self.discoveredIP)"
                } else if result?.isCancelled == true {
                    self.state = "V1 đã hủy"
                } else {
                    self.state = "V1 Multicast: hết thời gian, chưa nhận ACK"
                }
            }
        }
    }

    func provisionV2(ssid: String, password: String) {
        let s = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { state = "Nhập tên Personal Hotspot"; return }
        engine = "ESP-Touch V2"
        discoveredIP = ""
        state = "V2 đang gửi SSID/password…"
        let request = ESPProvisioningRequest()
        request.ssid = Data(s.utf8)
        request.password = Data(password.utf8)
        request.bssid = Data()
        request.reservedData = Data()
        request.aesKey = ""
        request.deviceCount = "1"
        request.securityVer = 1
        ESPProvisioner.share().startProvisioning(request, with: self)
    }

    func cancel() {
        v1Task?.interrupt()
        ESPProvisioner.share().stopProvisioning()
        ESPProvisioner.share().stopSync()
        state = "Đã hủy"
    }

    nonisolated func onProvisioningStart() {
        Task { @MainActor in self.state = "V2 provisioning đã bắt đầu…" }
    }

    nonisolated func onProvisioningStop() {
        Task { @MainActor in
            if self.discoveredIP.isEmpty { self.state = "V2 đã dừng — chưa thấy Xprinter" }
        }
    }

    nonisolated func onProvisoningScanResult(_ result: ESPProvisioningResult) {
        Task { @MainActor in
            self.discoveredIP = result.address
            self.state = "V2 PASS — IP: \(result.address)"
        }
    }

    nonisolated func onProvisioningError(_ exception: NSException) {
        Task { @MainActor in self.state = "V2 lỗi: \(exception.reason ?? "không rõ")" }
    }
}
