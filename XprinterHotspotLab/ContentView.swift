import SwiftUI

struct ContentView: View {
    @StateObject private var provision = ProvisioningClient()
    @StateObject private var printer = PrinterClient()
    @AppStorage("hotspotSSID") private var hotspotSSID = ""
    @AppStorage("hotspotPassword") private var hotspotPassword = ""
    @AppStorage("hotspotBSSID") private var hotspotBSSID = ""
    @AppStorage("printerIP") private var printerIP = ""
    @AppStorage("printerPort") private var printerPort = "9100"

    var body: some View {
        NavigationStack {
            Form {
                Section("1 · Đưa Xprinter vào Hotspot iPhone") {
                    TextField("Tên Personal Hotspot (SSID)", text: $hotspotSSID)
                        .textInputAutocapitalization(.never)
                    SecureField("Mật khẩu Personal Hotspot", text: $hotspotPassword)
                    TextField("BSSID (để trống để thử tự động)", text: $hotspotBSSID)
                        .textInputAutocapitalization(.never)
                    Button("Gửi cấu hình Wi-Fi cho Xprinter") {
                        provision.provision(ssid: hotspotSSID, password: hotspotPassword, bssid: hotspotBSSID)
                    }
                    Button("Hủy cấu hình", role: .cancel) { provision.cancel() }
                    Text(provision.state)
                    if !provision.discoveredIP.isEmpty {
                        Button("Dùng IP \(provision.discoveredIP)") {
                            printerIP = provision.discoveredIP
                        }
                    }
                    Text("Đưa máy in vào chế độ cấu hình Wi-Fi trước khi bấm. LAB dùng ESP-Touch V1 chính thức của Espressif.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("2 · Kiểm tra in") {
                    TextField("IP máy in", text: $printerIP)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Port", text: $printerPort).keyboardType(.numberPad)
                    Button("Test TCP") {
                        printer.test(host: printerIP, port: UInt16(printerPort) ?? 9100)
                    }
                    Button("In thử ESC/POS") {
                        printer.printTest(host: printerIP, port: UInt16(printerPort) ?? 9100)
                    }
                    Text(printer.state).font(.headline)
                }

                Section("Log in") {
                    Text(printer.log.isEmpty ? "Chưa có log." : printer.log)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("Xprinter Hotspot Lab")
            .onChange(of: provision.discoveredIP) { _, newValue in
                if !newValue.isEmpty { printerIP = newValue }
            }
        }
    }
}
