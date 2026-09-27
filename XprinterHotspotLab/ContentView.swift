import SwiftUI

struct ContentView: View {
    @StateObject private var client = PrinterClient()
    @AppStorage("printerIP") private var printerIP = ""
    @AppStorage("printerPort") private var printerPort = "9100"

    var body: some View {
        NavigationStack {
            Form {
                Section("LAB-1 · Kết nối thủ công") {
                    TextField("IP máy in, ví dụ 172.20.10.2", text: $printerIP)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Port", text: $printerPort)
                        .keyboardType(.numberPad)
                    Button("Test TCP") {
                        client.test(host: printerIP, port: UInt16(printerPort) ?? 9100)
                    }
                    Button("In thử ESC/POS") {
                        client.printTest(host: printerIP, port: UInt16(printerPort) ?? 9100)
                    }
                }

                Section("Trạng thái") {
                    Text(client.state).font(.headline)
                }

                Section("Log") {
                    Text(client.log.isEmpty ? "Chưa có log." : client.log)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }

                Section("Mục tiêu") {
                    Text("iPhone phát Personal Hotspot → Xprinter vào hotspot → app trên chính iPhone kết nối TCP tới Xprinter → gửi ESC/POS.")
                    Text("LAB-1 không dùng multicast và không tự dò máy in.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Xprinter Hotspot Lab")
        }
    }
}
