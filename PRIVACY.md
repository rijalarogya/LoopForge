# Privacy

LoopForge does not operate a backend service and does not collect analytics,
telemetry, uploaded media, prompts, rendered videos, or API keys.

Media analysis and rendering run locally through the bundled FFmpeg tools.
Output files remain in the folder selected by the user.

When an online AI provider is selected, LoopForge sends the prompt and media
metadata needed to generate or refine an edit plan to the configured provider.
The media files themselves are not uploaded by LoopForge. Provider requests are
subject to that provider's privacy policy and account settings.

API keys are stored in the macOS Keychain. Non-secret application preferences
are stored in macOS user defaults.

Ollama requests are sent to the configured Ollama URL, which defaults to the
local Mac.
