import Foundation

enum TimeFormatter {
    static func display(_ seconds: Double?) -> String {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return "--:--" }
        let value = Int(seconds.rounded(.down))
        let hours = value / 3600
        let minutes = (value % 3600) / 60
        let remaining = value % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, remaining)
        }
        return String(format: "%02d:%02d", minutes, remaining)
    }

    static func ffmpeg(_ seconds: Double) -> String {
        String(format: "%.3f", seconds)
    }
}
