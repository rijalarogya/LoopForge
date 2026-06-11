import Foundation

enum PromptRefinementPromptBuilder {
    static let systemPrompt = """
    Rewrite a user's video request so LoopForge can understand it reliably.
    Return JSON only in this exact shape: {"refined_prompt":"..."}
    Preserve every provided @filename reference exactly.
    Do not invent files, filenames, paths, durations, or loop counts.
    Keep all supported user intent.
    Remove or rephrase unsupported requests into the closest supported result.
    The app supports selecting one base video, selecting external audio, an explicit target duration,
    an explicit number of complete audio loops, looping video to match the final duration,
    image overlays in fixed positions, resizing, MP4 export, and automatic final five-second
    audio fade out plus video fade to black.
    Do not write FFmpeg or shell commands.
    Do not return markdown or commentary.
    """

    static func userMessage(for request: PromptRefinementRequest) throws -> String {
        let filenames = request.assets.map(\.filename).sorted()
        let encodedFilenames = try JSONEncoder().encode(filenames)
        let filenameJSON = String(decoding: encodedFilenames, as: UTF8.self)
        let unsupported = request.unsupportedRequests.isEmpty
            ? "None reported."
            : request.unsupportedRequests.joined(separator: "; ")

        return """
        ORIGINAL PROMPT:
        \(request.userPrompt)

        UPLOADED FILENAMES:
        \(filenameJSON)

        PREVIOUS FAILURE:
        \(request.failureReason ?? "No parser error was reported.")

        UNSUPPORTED REQUESTS:
        \(unsupported)

        Rewrite the original request as a concise, unambiguous supported prompt.
        """
    }
}
