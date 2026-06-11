import Foundation

enum ProgressParser {
    private static let regex = try! NSRegularExpression(
        pattern: #"time=(\d{2}):(\d{2}):(\d{2}(?:\.\d+)?)"#
    )

    static func seconds(from line: String) -> Double? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.matches(in: line, range: range).last,
              let hoursRange = Range(match.range(at: 1), in: line),
              let minutesRange = Range(match.range(at: 2), in: line),
              let secondsRange = Range(match.range(at: 3), in: line),
              let hours = Double(line[hoursRange]),
              let minutes = Double(line[minutesRange]),
              let seconds = Double(line[secondsRange]) else {
            return nil
        }
        return hours * 3600 + minutes * 60 + seconds
    }
}
