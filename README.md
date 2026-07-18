# ScreenTutor for macOS

[![CI](https://github.com/SebastianBoehler/screen-tutor-mac/actions/workflows/ci.yml/badge.svg)](https://github.com/SebastianBoehler/screen-tutor-mac/actions/workflows/ci.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![macOS 15+](https://img.shields.io/badge/macOS-15%2B-111111?logo=apple)](https://support.apple.com/macos)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Talk naturally about whatever is open on your Mac.

ScreenTutor is a native, open-source menu-bar tutor that combines the relevant Mac window with a low-latency voice conversation. Microphone audio streams directly to OpenAI's `gpt-realtime-2.1`, and the model's PCM audio streams straight back to the Mac speakers.

There is no separate Whisper transcription request and no separate text-to-speech request. Assistant captions come from the same Realtime audio response.

> [!IMPORTANT]
> ScreenTutor is an early-stage, bring-your-own-key project for local development. It is not currently distributed as a signed or notarized app.

## What it does

- Streams 24 kHz PCM16 speech-to-speech over the Realtime WebSocket API
- Uses semantic voice activity detection with natural barge-in and response truncation
- Lets GPT inspect visible app/window titles and capture only the window relevant to the question
- Uses native echo cancellation through `AVAudioEngine` voice processing
- Lives in the menu bar with a nonactivating, notch-like status HUD
- Lets the model place a temporary teaching highlight over a formula, plot, cell, or control
- Stores the OpenAI API key in macOS Keychain
- Uses Command-Shift-Space to start, pause, or resume listening while the Realtime session remains connected
- Automatically pauses the microphone after 20 seconds of listening inactivity
- Offers an explicit New conversation action when you want to replace the current context
- Supports launch at login through `SMAppService`
- Handles microphone, Screen Recording, network, and protocol errors explicitly

The teaching highlight is visual and click-through. ScreenTutor never moves the real pointer, clicks, types, or autonomously controls the Mac.

## How one turn works

1. `AVAudioEngine` captures the microphone and converts it to mono PCM16 at 24 kHz.
2. Audio chunks stream through `input_audio_buffer.append`; GPT consumes the voice natively.
3. Semantic VAD reports that speech started, which interrupts any current answer.
4. VAD commits the spoken turn and ScreenTutor asks GPT to respond.
5. When screen context is needed, GPT calls `list_windows`, chooses from opaque IDs plus app/window titles, and calls `capture_window`.
6. ScreenTutor validates that selection, appends only that window as a high-detail `input_image`, and asks GPT to continue.
7. `response.output_audio.delta` chunks play immediately while the matching transcript updates the menu.
8. If pointing helps, GPT calls `highlight_screen_region`; ScreenTutor draws a temporary overlay and asks GPT to continue speaking.

The window list and capture calls are serial, recoverable tools. A closed window produces a tool error so GPT can list again instead of ending the voice session.

## Requirements

- macOS 15 or newer
- Xcode 16.4 or newer with Swift 6 support
- An OpenAI API key with access to `gpt-realtime-2.1`
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.45 or newer only when regenerating the checked-in Xcode project

## Run locally

1. Clone the repository.
2. Copy `Config/LocalSigning.xcconfig.example` to `Config/LocalSigning.xcconfig` and replace `YOUR_TEAM_ID` with the Team ID shown in Xcode Settings > Accounts. The local file is ignored by Git and gives builds a stable signed identity; ad-hoc builds can lose their macOS privacy grants after every rebuild.
3. Open `ScreenTutor.xcodeproj` in Xcode and run the `ScreenTutor` scheme on My Mac.
4. Open the waveform menu-bar item, choose Settings, and save your API key.
5. Start a conversation and grant Microphone and Screen Recording access. macOS may require one app restart after Screen Recording is first granted.
6. Keep a notebook, paper, browser, or editor open and press Command-Shift-Space.

Press the shortcut again to pause the microphone. While the Realtime session remains connected, press it later to resume the same conversation, including prior voice turns. Realtime sessions last at most 60 minutes. The menu also shows the current Listening, Thinking, Speaking, or Paused state. Choose New conversation when you want an empty context.

The app has `LSUIElement` enabled, so it lives in the menu bar rather than the Dock.

## Architecture

| Area | Responsibility |
| --- | --- |
| `App` | Session lifecycle and application state |
| `Audio` | Microphone conversion, echo cancellation, and streamed playback |
| `Realtime` | Typed OpenAI Realtime events and WebSocket transport |
| `Screen` | Privacy-filtered window catalog and model-selected one-shot capture |
| `UI` | Menu, HUD, settings, and click-through teaching highlight |
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

ScreenTutor sends spoken audio to OpenAI. For a screen-grounded question, it also sends the names and titles of eligible visible windows so GPT can choose one, followed by the pixels of only the selected window. It does not continuously record the screen. Close or minimize sensitive windows before asking a screen-aware question.

Pausing stops microphone capture but intentionally keeps the Realtime WebSocket and its conversation context alive within the 60-minute session limit. New conversation and Quit disconnect that session. A network or API disconnect also ends the live context.

`gpt-realtime-2.1` is a cloud API model and incurs normal OpenAI API usage charges. Avoiding separate transcription and TTS reduces components; it does not make the Realtime model offline or free.

The current BYOK design is intended for personal development: the long-lived key is stored in Keychain and never in source or `UserDefaults`. A distributed product should put credentials behind a backend, issue short-lived client tokens, and evaluate WebRTC instead of shipping a standard API key to clients.

## Contributing

Bug reports, accessibility improvements, documentation, focused tests, and well-scoped implementation changes are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md). Report security issues through the process in [SECURITY.md](SECURITY.md), not a public issue.

## Protocol references

- [Realtime WebSocket guide](https://developers.openai.com/api/docs/guides/realtime-websocket)
- [Realtime conversations and audio](https://developers.openai.com/api/docs/guides/realtime-conversations)
- [`gpt-realtime-2.1` model](https://developers.openai.com/api/docs/models/gpt-realtime-2.1)

## License

ScreenTutor is available under the [MIT License](LICENSE).
