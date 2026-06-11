import AppKit
import SwiftUI

struct LogsView: View {
    @ObservedObject var logs: LogStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Logs")
                    .font(.title2.bold())
                Spacer()
                Button("Copy Logs") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(logs.text, forType: .string)
                }
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            ScrollView {
                Text(logs.text.isEmpty ? "No logs yet." : logs.text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(10)
            .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(Color.white.opacity(0.9))
        }
        .padding(20)
        .frame(width: 760, height: 520)
    }
}
