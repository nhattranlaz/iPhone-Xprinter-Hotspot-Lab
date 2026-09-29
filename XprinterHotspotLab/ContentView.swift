import SwiftUI

struct ContentView: View {
    @StateObject private var setup = PrinterSetupService()
    @StateObject private var printer = PrinterClient()

    @State private var ssid = ""
    @State private var password = ""
    @State private var bssid = ""
    @State private var omitBSSID = true
    @State private var printerIP = ""
    @FocusState private var focused: Field?
    enum Field { case ssid, password, bssid, ip }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Xprinter Wi-Fi Setup")
                        .font(.largeTitle.bold())

                    Text("Đưa máy in vào chế độ chờ kết nối Wi-Fi. Nhập thông tin mạng rồi bấm Cấu hình máy in.")
                        .foregroundStyle(.secondary)

                    Group {
                        TextField("SSID Wi-Fi", text: $ssid)
                            .focused($focused, equals: .ssid)
                        SecureField("Mật khẩu Wi-Fi", text: $password)
                            .focused($focused, equals: .password)
                        TextField("BSSID (tùy chọn)", text: $bssid)
                            .textInputAutocapitalization(.never)
                            .focused($focused, equals: .bssid)
                            .disabled(omitBSSID)
                            .opacity(omitBSSID ? 0.45 : 1)
                    }
                    .textFieldStyle(.roundedBorder)
                    .frame(minHeight: 48)

                    Toggle("Không gửi BSSID", isOn: $omitBSSID)

                    Button(setup.isRunning ? "ĐANG CẤU HÌNH…" : "CẤU HÌNH MÁY IN") {
                        focused = nil
                        setup.configure(ssid: ssid, password: password, bssid: bssid, omitBSSID: omitBSSID)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(setup.isRunning)

                    if setup.isRunning {
                        Button("Hủy cấu hình", role: .cancel) { setup.cancel() }
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }

                    Text(setup.status)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Divider().padding(.vertical, 4)

                    Text("Kiểm tra máy in").font(.title2.bold())

                    TextField("IP máy in", text: $printerIP)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)
                        .focused($focused, equals: .ip)
                        .frame(minHeight: 48)

                    Button("TEST TCP 9100") {
                        focused = nil
                        printer.test(host: printerIP, port: 9100)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button("IN THỬ") {
                        focused = nil
                        printer.printTest(host: printerIP, port: 9100)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Text(printer.state)
                        .font(.headline)

                    if !printer.log.isEmpty {
                        Text(printer.log)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Xong") { focused = nil }
                }
            }
            .onChange(of: setup.printerIP) { value in
                if !value.isEmpty { printerIP = value }
            }
        }
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(.primary.opacity(configuration.isPressed ? 0.15 : 0.08),
                        in: RoundedRectangle(cornerRadius: 14))
    }
}
