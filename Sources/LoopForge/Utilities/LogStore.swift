import Foundation

@MainActor
final class LogStore: ObservableObject {
    @Published private(set) var entries: [String] = []

    var text: String {
        entries.joined(separator: "\n")
    }

    func append(_ message: String) {
        let timestamp = DateFormatter.logTimestamp.string(from: Date())
        entries.append("[\(timestamp)] \(message)")
    }

    func clear() {
        entries.removeAll()
    }
}

private extension DateFormatter {
    static let logTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
