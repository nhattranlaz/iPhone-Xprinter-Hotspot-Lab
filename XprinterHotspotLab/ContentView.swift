import SwiftUI

struct ContentView: View {
    @StateObject private var provision = ProvisioningClient()
    @StateObject private var printer = PrinterClient()
    @StateObject private var diagnostic = HotspotDiagnostic()
    @StateObject private var hotspot = HotspotCredentialModel()

    @AppStorage("printerIP") private var printerIP = ""
    @AppStorage("printerPort") private var printerPort = "9100"

    @FocusState private var focused: Field?
    enum Field { case ssid, password, ip, port }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    card("1. Hotspot iPhone") {
                        TextField("Tên Personal Hotspot", text: $hotspot.ssid)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .focused($focused, equals: .ssid)
                            .frame(minHeight: 48)
                            .onChange(of: hotspot.ssid) { _ in hotspot.userEditedSSID() }

                        SecureField("Mật khẩu Personal Hotspot", text: $hotspot.password)
                            .textFieldStyle(.roundedBorder)
                            .focused($focused, equals: .password)
                            .frame(minHeight: 48)
                            .onChange(of: hotspot.password) { _ in hotspot.userEditedPassword() }

                        HStack {
                            Text("SSID: \(hotspot.ssidSource.rawValue)")
                            Spacer()
                            Text("Password: \(hotspot.passwordSource.rawValue)")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Text(hotspot.status)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button("Đọc lại thông tin Hotspot") {
                            closeKeyboard()
                            hotspot.resetAndDetect()
                        }
                        .buttonStyle(LabButtonStyle())
                    }

                    card("2. Máy in Xprinter") {
                        Button("Tìm & Cấu hình Xprinter") {
                            closeKeyboard()
                            provision.provisionV1(ssid: hotspot.ssid, password: hotspot.password)
                        }
                        .buttonStyle(LabButtonStyle())

                        Text(provision.state)
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Hủy cấu hình", role: .cancel) { provision.cancel() }
                            .frame(maxWidth: .infinity, minHeight: 44)


                    }

                    card("3. Kiểm tra in") {
                        field("IP máy in", text: $printerIP, field: .ip)
                            .keyboardType(.numbersAndPunctuation)
                        field("Port", text: $printerPort, field: .port)
                            .keyboardType(.numberPad)

                        Button("Test TCP") {
                            closeKeyboard()
                            printer.test(host: printerIP, port: UInt16(printerPort) ?? 9100)
                        }
                        .buttonStyle(LabButtonStyle())

                        Button("In thử ESC/POS") {
                            closeKeyboard()
                            printer.printTest(host: printerIP, port: UInt16(printerPort) ?? 9100)
                        }
                        .buttonStyle(LabButtonStyle())

                        Text(printer.state)
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    card("Log in") {
                        Text(printer.log.isEmpty ? "Chưa có log." : printer.log)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Xprinter Hotspot Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Xong") { closeKeyboard() }
                }
            }
            .task { hotspot.resetAndDetect() }
            .onChange(of: provision.discoveredIP) { newValue in
                if !newValue.isEmpty { printerIP = newValue }
            }
        }
    }

    @ViewBuilder
    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title3.bold())
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func field(_ placeholder: String, text: Binding<String>, field: Field) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.never)
            .focused($focused, equals: field)
            .frame(minHeight: 48)
    }

    private func closeKeyboard() { focused = nil }
}

private struct LabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(.primary.opacity(configuration.isPressed ? 0.14 : 0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}
