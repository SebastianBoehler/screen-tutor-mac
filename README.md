# ScreenTutor for macOS

[![CI](https://github.com/SebastianBoehler/screen-tutor-mac/actions/workflows/ci.yml/badge.svg)](https://github.com/SebastianBoehler/screen-tutor-mac/actions/workflows/ci.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![macOS 15+](https://img.shields.io/badge/macOS-15%2B-111111?logo=apple)](https://support.apple.com/macos)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Talk naturally about whatever is open on your Mac.

ScreenTutor is a native, open-source menu-bar tutor that combines the relevant Mac window with a low-latency voice conversation. Microphone audio streams directly to OpenAI's `gpt-realtime-2.1` or `gpt-realtime-2.1-mini`, and the model's PCM audio streams straight back to the Mac speakers.

The answer path has no standalone transcription or text-to-speech step. Assistant captions come from the same Realtime audio response. An asynchronous `gpt-4o-mini-transcribe` input transcript runs alongside it only to make local conversation history readable; it is separate model usage and can differ from what the Realtime model understood.

> [!IMPORTANT]
> ScreenTutor is an early-stage, bring-your-own-key project for local development. It is not currently distributed as a signed or notarized app.

## What it does

- Streams 24 kHz PCM16 speech-to-speech over the Realtime WebSocket API
- Uses semantic voice activity detection with natural barge-in and response truncation
- Lets GPT inspect visible app/window titles and capture only the window relevant to the question
- Uses shareable macOS microphone I/O plus Realtime far-field noise reduction
- Lives in the menu bar with a draggable, translucent status and transcript HUD
- Moves an animated tutor cursor to a formula, plot, cell, or control and highlights the target
- Saves text-only conversations and privacy-safe tool status records as local JSONL
- Shows prior turns and compact tool activity badges in a native history window
- Offers Automatic, Deutsch, and English speech-language settings
- Lets you customize the tutor's teaching instructions without replacing screen/privacy rules
- Lets you trade response latency for deeper model reasoning from Minimal through Extra high
- Offers quality-first GPT-Realtime-2.1 and lower-cost GPT-Realtime-2.1 mini
- Stores the OpenAI API key in macOS Keychain
- Uses a configurable global shortcut (default: Command-Shift-Space) to start, mute, or unmute the microphone
- Automatically pauses the microphone after 20 seconds of listening inactivity
- Offers an explicit New conversation action when you want to replace the current context
- Supports launch at login through `SMAppService`
- Handles microphone, Screen Recording, network, and protocol errors explicitly

The tutor cursor is a visual, click-through overlay. ScreenTutor never moves the real pointer, clicks, types, or autonomously controls the Mac.

ScreenTutor does not currently perform web search or use web grounding. Its answers use the live conversation and the selected window capture; adding search requires a separate Realtime function or MCP tool integration.

## How one turn works

1. `AVAudioEngine` captures the microphone and converts it to mono PCM16 at 24 kHz.
2. Audio chunks stream through `input_audio_buffer.append`; GPT consumes the voice natively.
3. Semantic VAD reports that speech started, which interrupts any current answer.
4. VAD commits the spoken turn and ScreenTutor asks GPT to respond.
5. When screen context is needed, GPT calls `list_windows`, chooses from opaque IDs plus app/window titles, and calls `capture_window`.
6. ScreenTutor validates that selection, appends only that window as a high-detail `input_image`, and asks GPT to continue.
7. `response.output_audio.delta` chunks play immediately while the matching transcript updates the menu and optional on-screen HUD.
8. Separately, completed input transcription events are queued into the local history without blocking the audio event stream.
9. If pointing helps, GPT calls `highlight_screen_region`; ScreenTutor animates its tutor cursor to the target and asks GPT to continue speaking.

The window list and capture calls are serial, recoverable tools. A closed window produces a tool error so GPT can list again instead of ending the voice session.

## Requirements

- macOS 15 or newer
- Xcode 16.4 or newer with Swift 6 support
- An OpenAI API key with access to `gpt-realtime-2.1` or `gpt-realtime-2.1-mini`
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.45 or newer only when regenerating the checked-in Xcode project

## Run locally

1. Clone the repository.
2. Copy `Config/LocalSigning.xcconfig.example` to `Config/LocalSigning.xcconfig` and replace `YOUR_TEAM_ID` with the Team ID shown in Xcode Settings > Accounts. The local file is ignored by Git and gives builds a stable signed identity; ad-hoc builds can lose their macOS privacy grants after every rebuild.
3. Open `ScreenTutor.xcodeproj` in Xcode and run the `ScreenTutor` scheme on My Mac.
4. Open the waveform menu-bar item, choose Settings, save your API key, and optionally pin the
   tutor's Realtime model, spoken language, reasoning effort, or teaching instructions. Automatic
   follows the language of your latest spoken turn.
5. Start a conversation and grant Microphone and Screen Recording access. macOS may require one app restart after Screen Recording is first granted.
6. Keep a notebook, paper, browser, or editor open and press Command-Shift-Space.

Press the shortcut again to mute only ScreenTutor's microphone upload. The Realtime connection and any answer already being spoken remain active; OBS and other microphone-enabled apps can continue recording. Press it later to unmute and resume the same conversation, including prior voice turns. Change the combination under Settings > System by clicking the shortcut recorder and typing a modified key combination. If macOS or another app already owns it, ScreenTutor keeps the prior working shortcut and reports the conflict.

Realtime sessions last at most 60 minutes. The menu and draggable overlay show the current Listening, Thinking, Speaking, or Microphone muted state. Green means ScreenTutor input is live, orange means it is muted, and the icon and label provide the same state without relying on color. The overlay also shows live window-listing, capture, and highlighting tool chips and plays a short cue before ScreenTutor inspects window information or pixels. Choose New conversation when you want an empty context.

Choose Conversation History… to browse prior text turns and tool activity, copy messages, or reveal the underlying JSONL file in Finder. The detail page has a labeled Continue conversation button instead of an icon-only toolbar action. Settings > Conversation storage shows the canonical folder path and can reveal all JSONL files or one selected conversation. Hotkey mute/unmute keeps writing to the same conversation; New conversation starts a new one. A network disconnect cannot preserve the original server-side Realtime session, but the next microphone action reconnects and replays the completed local conversation context. An app restart still requires selecting Continue conversation. The on-screen transcript can be hidden independently from the menu and dragged to a comfortable position.

The spoken-language choice applies when a new Realtime conversation starts. Deutsch and English pin both the tutor's pronunciation instructions and the optional input-transcription language hint. Automatic leaves transcription language detection open and instructs the tutor to mirror the latest spoken language.

Tutor instructions are also applied when a new conversation starts. You can rewrite or clear the editable teaching preferences and restore the default at any time. ScreenTutor always keeps its app-owned window-selection, prompt-injection, privacy, capture-truthfulness, and teaching-pointer requirements around that editable layer.

Reasoning effort also applies to new conversations. `Low` is the default for responsive voice use; higher levels can improve multi-step explanations and tool decisions at the cost of additional latency and output-token usage.

GPT-Realtime-2.1 remains the default for the strongest tutoring quality. The mini model supports the same audio, text, image, and function-calling surfaces used here, but it is a distilled model, so lower cost can come with less capable explanations or tool decisions. Model changes apply to the next connection.

The app has `LSUIElement` enabled, so it lives in the menu bar rather than the Dock.

## Architecture

| Area | Responsibility |
| --- | --- |
| `App` | Session lifecycle and application state |
| `Audio` | Shareable microphone conversion and streamed playback |
| `Realtime` | Typed OpenAI Realtime events and WebSocket transport |
| `Screen` | Privacy-filtered window catalog and model-selected one-shot capture |
| `History` | Ordered, private JSONL persistence and conversation projection |
| `UI` | Menu, transcript HUD, history browser, settings, and tutor cursor |
| `System` | Global hotkey and launch-at-login integration |

The app uses Apple frameworks only: SwiftUI, AppKit, AVFAudio, ScreenCaptureKit, Security, ServiceManagement, and Carbon.

## Development

Regenerate the checked-in project after adding or moving source files:

```bash
xcodegen generate
```

Build without signing:

```bash
xcodebuild \
  -project ScreenTutor.xcodeproj \
  -scheme ScreenTutor \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run the focused tests:

```bash
xcodebuild \
  -project ScreenTutor.xcodeproj \
  -scheme ScreenTutor \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

## Privacy, credentials, and billing

ScreenTutor sends spoken audio to OpenAI. Input audio is also transcribed asynchronously for readable history. For a screen-grounded question, the app sends the names and titles of eligible visible windows so GPT can choose one, followed by the pixels of only the selected window. It does not continuously record the screen. Close or minimize sensitive windows before asking a screen-aware question.

Completed user and assistant captions are retained as plain-text JSONL in ScreenTutor's sandboxed Application Support directory. The directory and files use owner-only permissions (`0700` and `0600`); ScreenTutor does not add application-level encryption. The logs contain transcript text, provider correlation IDs, and tool names with success/failure status—not audio, screenshots, window titles, tool arguments, coordinates, or result payloads. Use Conversation History… > Reveal JSONL to find them. Hide the on-screen transcript when people nearby should not see it.

The selected model, custom tutor instructions, and reasoning effort are stored locally in `UserDefaults`. They are sent to OpenAI as part of each new Realtime session and are not written to conversation-history JSONL.

Muting suppresses microphone audio sent by ScreenTutor without stopping its shared audio engine, assistant playback, or Realtime WebSocket. It does not mute the Mac globally or block OBS from using the microphone. New conversation and Quit disconnect the session. After a network disconnect, ScreenTutor reconnects on the next microphone action and restores completed turns from local history into a new Realtime session.

`gpt-realtime-2.1`, `gpt-realtime-2.1-mini`, and `gpt-4o-mini-transcribe` are cloud API models and incur their respective OpenAI API usage charges. At current standard rates, flagship audio costs $32 input / $64 output per 1M audio tokens; mini costs $10 input / $20 output. Text and captured images are also billed. The auxiliary input transcript does not sit in the direct speech-to-speech answer path, but it is separately billed. ScreenTutor is not offline or free to run.

The current BYOK design is intended for personal development: the long-lived key is stored in Keychain and never in source or `UserDefaults`. A distributed product should put credentials behind a backend, issue short-lived client tokens, and evaluate WebRTC instead of shipping a standard API key to clients.

## Contributing

Bug reports, accessibility improvements, documentation, focused tests, and well-scoped implementation changes are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md). Report security issues through the process in [SECURITY.md](SECURITY.md), not a public issue.

## Protocol references

- [Realtime WebSocket guide](https://developers.openai.com/api/docs/guides/realtime-websocket)
- [Realtime conversations and audio](https://developers.openai.com/api/docs/guides/realtime-conversations)
- [Realtime prompting: language constraints](https://developers.openai.com/api/docs/guides/realtime-models-prompting#language-constraint)
- [Realtime prompting: reasoning effort](https://developers.openai.com/api/docs/guides/realtime-models-prompting#set-reasoning-effort)
- [Realtime voice activity detection](https://developers.openai.com/api/docs/guides/realtime-vad)
- [Realtime transcription session fields](https://developers.openai.com/api/docs/guides/realtime-transcription#session-fields)
- [Input audio transcription events](https://developers.openai.com/api/reference/resources/realtime/server-events#conversation.item.input_audio_transcription.completed)
- [`gpt-realtime-2.1` model](https://developers.openai.com/api/docs/models/gpt-realtime-2.1)
- [`gpt-realtime-2.1-mini` model](https://developers.openai.com/api/docs/models/gpt-realtime-2.1-mini)
- [OpenAI API pricing](https://developers.openai.com/api/docs/pricing#audio-tokens)

## License

ScreenTutor is available under the [MIT License](LICENSE).
