import SwiftUI

struct ContentView: View {
    @StateObject private var setup = PrinterProvisioner()
    @StateObject private var printer = PrinterTCPClient()
    @State private var ssid = ""
    @State private var bssid = ""
    @State private var password = ""
    @State private var omitBSSID = true
    @State private var printerIP = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Xprinter Wi-Fi Setup").font(.largeTitle.bold())
                Text("Đưa máy in vào trạng thái chờ kết nối Wi-Fi, nhập thông tin mạng rồi cấu hình.")
                    .foregroundStyle(.secondary)

                TextField("SSID", text: $ssid).textFieldStyle(.roundedBorder)
                TextField("BSSID (tùy chọn)", text: $bssid)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .disabled(omitBSSID)
                    .opacity(omitBSSID ? 0.45 : 1)
                SecureField("Password", text: $password).textFieldStyle(.roundedBorder)

                Toggle("Không gửi BSSID", isOn: $omitBSSID)

                Button(setup.running ? "ĐANG CẤU HÌNH…" : "CẤU HÌNH MÁY IN") {
                    setup.start(ssid: ssid, password: password, bssid: bssid, omitBSSID: omitBSSID)
                }
                .buttonStyle(WideButton())
                .disabled(setup.running)

                Text(setup.status).font(.headline)

                Divider().padding(.vertical, 6)

                TextField("IP máy in", text: $printerIP)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation)

                Button("TEST TCP 9100") { printer.test(ip: printerIP) }
                    .buttonStyle(WideButton())
                Button("IN THỬ") { printer.printTest(ip: printerIP) }
                    .buttonStyle(WideButton())

                Text(printer.status).font(.headline)
            }
            .padding(20)
            .onChange(of: setup.printerIP) { value in
                if !value.isEmpty { printerIP = value }
            }
        }
    }
}

private struct WideButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(.primary.opacity(configuration.isPressed ? 0.16 : 0.08),
                        in: RoundedRectangle(cornerRadius: 12))
    }
}
