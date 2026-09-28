import Foundation
import SystemConfiguration.CaptiveNetwork

@MainActor
final class HotspotCredentialModel: ObservableObject {
    enum Source: String { case none = "Chưa lấy được", detected = "Tự động", user = "Người dùng nhập" }
    @Published var ssid = ""
    @Published var password = ""
    @Published var ssidSource: Source = .none
    @Published var passwordSource: Source = .none
    @Published var status = "Chưa đọc thông tin Hotspot"

    func resetAndDetect() {
        ssid = ""
        password = ""
        ssidSource = .none
        passwordSource = .none
        status = "Đang thử đọc thông tin Hotspot…"
        var found: String?
        if let names = CNCopySupportedInterfaces() as? [String] {
            for name in names {
                if let info = CNCopyCurrentNetworkInfo(name as CFString) as? [String: Any],
                   let value = info[kCNNetworkInfoKeySSID as String] as? String,
                   !value.isEmpty {
                    found = value
                    break
                }
            }
        }
        if let found {
            ssid = found
            ssidSource = .detected
            status = "Đã tự động lấy tên Wi-Fi"
        } else {
            status = "Không tự động lấy được tên Hotspot — hãy nhập thủ công"
        }
        // iOS does not expose Personal Hotspot password to third-party apps.
        password = ""
        passwordSource = .none
    }

    func userEditedSSID() { if !ssid.isEmpty { ssidSource = .user } }
    func userEditedPassword() { if !password.isEmpty { passwordSource = .user } }
}
