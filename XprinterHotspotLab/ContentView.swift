import SwiftUI

struct ContentView: View {
    @StateObject private var provision = ProvisioningClient()
    @StateObject private var printer = PrinterClient()
    @StateObject private var diagnostic = HotspotDiagnostic()
    @AppStorage("hotspotSSID") private var hotspotSSID = ""
    @AppStorage("hotspotPassword") private var hotspotPassword = ""
    @AppStorage("printerIP") private var printerIP = ""
    @AppStorage("printerPort") private var printerPort = "9100"
    @FocusState private var focused: Field?
    enum Field { case ssid, password, ip, port }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    card("LAB-3 · Personal Hotspot Diagnostic") {
                        Button("Quét interface") { diagnostic.refresh() }
                            .buttonStyle(LabButtonStyle())
                        Button("Probe UDP broadcast tất cả interface") { closeKeyboard(); diagnostic.probeAll() }
                            .buttonStyle(LabButtonStyle())
                        Text(diagnostic.status).font(.headline)
                        ForEach(diagnostic.interfaces) { item in
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(item.name)  #\(item.index)").font(.system(.body, design: .monospaced).bold())
                                Text("IP \(item.address)  mask \(item.netmask)")
                                Text("broadcast \(item.broadcast.isEmpty ? "—" : item.broadcast)")
                            }
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ForEach(diagnostic.probes) { p in
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(p.interface): \(p.result)").bold()
                                Text("\(p.source) → \(p.destination)")
                                Text("errno=\(p.errnoCode) · \(p.timestamp.formatted(date: .omitted, time: .standard))")
                            }
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Text("SOCKET_SEND_PASS chỉ xác nhận sendto() thành công; không khẳng định packet đã được Xprinter nhận trên sóng.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }

                    card("1. Wi-Fi của iPhone") {
                        field("Tên Personal Hotspot", text: $hotspotSSID, field: .ssid)
                        SecureField("Mật khẩu Personal Hotspot", text: $hotspotPassword)
                            .textFieldStyle(.roundedBorder).focused($focused, equals: .password)
                        Text("Không dùng BSSID giả. Cả V1 và V2 chỉ nhận thông tin chúng ta thực sự biết.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }

                    card("2. Cấu hình Xprinter") {
                        Button("Thử ESP-Touch V1") { closeKeyboard(); provision.provisionV1(ssid: hotspotSSID, password: hotspotPassword) }
                            .buttonStyle(LabButtonStyle())
                        Button("Thử ESP-Touch V2") { closeKeyboard(); provision.provisionV2(ssid: hotspotSSID, password: hotspotPassword) }
                            .buttonStyle(LabButtonStyle())
                        Button("Hủy cấu hình", role: .cancel) { provision.cancel() }
                            .frame(maxWidth: .infinity, minHeight: 44)
                        Text(provision.state).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                        if !provision.engine.isEmpty {
                            Text("Engine: \(provision.engine)").font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    card("3. Kiểm tra in") {
                        field("IP máy in", text: $printerIP, field: .ip)
                            .keyboardType(.numbersAndPunctuation)
                        field("Port", text: $printerPort, field: .port)
                            .keyboardType(.numberPad)
                        Button("Test TCP") { closeKeyboard(); printer.test(host: printerIP, port: UInt16(printerPort) ?? 9100) }
                            .buttonStyle(LabButtonStyle())
                        Button("In thử ESC/POS") { closeKeyboard(); printer.printTest(host: printerIP, port: UInt16(printerPort) ?? 9100) }
                            .buttonStyle(LabButtonStyle())
                        Text(printer.state).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                    }

                    card("Log in") {
                        Text(printer.log.isEmpty ? "Chưa có log." : printer.log)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(18)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Xprinter Hotspot Lab")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Xong") { closeKeyboard() }
                }
            }
            .onChange(of: provision.discoveredIP) { newValue in
                if !newValue.isEmpty { printerIP = newValue }
            }
        }
    }

    @ViewBuilder private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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
