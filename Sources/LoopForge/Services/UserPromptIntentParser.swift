import Foundation

enum UserPromptIntentParser {
    private static let audioLoopPatterns = [
        #"(?:music|audio|song|track)[^\n.!?]{0,80}?(?:loop(?:ed)?|play(?:ed)?)[^\d]{0,20}(\d+)\s*(?:times?|loops?)"#,
        #"(?:loop|play)\s+(?:the\s+)?(?:music|audio|song|track)[^\d]{0,30}(\d+)\s*(?:times?|loops?)"#,
        #"(?:loop(?:ed)?|play(?:ed)?)[^\n.!?]{0,50}?(\d+)\s*(?:times?|loops?)"#
    ].map {
        try! NSRegularExpression(pattern: $0, options: [.caseInsensitive])
    }

    static func requestedAudioLoopCount(from prompt: String) -> Int? {
        let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
        for regex in audioLoopPatterns {
            guard let match = regex.firstMatch(in: prompt, range: range),
                  let countRange = Range(match.range(at: 1), in: prompt),
                  let count = Int(prompt[countRange]),
                  count > 0 else {
                continue
            }
            return count
        }
        return nil
    }
}
