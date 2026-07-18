# ScreenTutor for macOS

ScreenTutor is a native menu-bar tutor that can see the active Mac window and hold a low-latency voice conversation about it. Microphone audio streams directly to OpenAI's `gpt-realtime-2.1`, and the model's PCM audio streams straight back to the Mac speakers.

There is no separate Whisper transcription request and no separate text-to-speech request. Assistant captions come from the same Realtime audio response.

## Current feature set

- Direct 24 kHz PCM16 speech-to-speech over the Realtime WebSocket API
- Semantic VAD with natural barge-in and conversation truncation
- A fresh active-window screenshot attached before every response
- Native echo cancellation through AVAudioEngine voice processing
- Menu-bar control plus a nonactivating, notch-like status HUD
- An optional teaching highlight the model can place over a visible formula, plot, cell, or control
- OpenAI API key storage in macOS Keychain
- Command-Shift-Space global start/stop shortcut
- Launch-at-login support through `SMAppService`
- Explicit microphone, Screen Recording, network, and error handling

The teaching highlight is visual only. ScreenTutor does not click, type, move the real pointer, or autonomously control the Mac.

## How one turn works

1. AVAudioEngine captures the microphone and converts it to mono PCM16 at 24 kHz.
2. Audio chunks stream through `input_audio_buffer.append`; GPT consumes the voice natively.
3. Semantic VAD reports that speech started, which also interrupts any current answer.
4. ScreenTutor captures the frontmost window of the last external application.
5. VAD commits the spoken turn. ScreenTutor appends the JPEG as an `input_image`, then sends `response.create`.
6. `response.output_audio.delta` chunks play immediately. The matching transcript updates the menu.
7. If pointing helps, GPT calls `highlight_screen_region`; ScreenTutor draws a temporary, click-through overlay and asks GPT to continue speaking.

Automatic response creation is deliberately disabled in VAD. This prevents GPT from starting its answer before the screenshot reaches the conversation.

## Requirements

- macOS 15 or newer
- Xcode with Swift 6 support
- An OpenAI API key with access to `gpt-realtime-2.1`
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) only when regenerating the checked-in Xcode project

## Run it

1. Open `ScreenTutor.xcodeproj` in Xcode.
2. Select your development team under Signing & Capabilities.
3. Run the `ScreenTutor` scheme on My Mac.
4. Open the waveform menu-bar item, choose Settings, and save your API key.
5. Start a conversation and grant Microphone and Screen Recording access. macOS may require one app restart after Screen Recording is first granted.
6. Keep a notebook, paper, browser, or editor active and press Command-Shift-Space.

The app has `LSUIElement` enabled, so it lives in the menu bar rather than the Dock.

## Development

Regenerate the project after adding files:

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

The project uses only Apple frameworks: SwiftUI, AppKit, AVFAudio, ScreenCaptureKit, Security, ServiceManagement, and Carbon for the global hotkey.

## Privacy, credentials, and billing

This implementation sends spoken audio and the captured active-window image to OpenAI. It captures a single window image per spoken turn, not a continuous screen recording.

`gpt-realtime-2.1` is a cloud API model and incurs normal OpenAI API usage charges. Avoiding separate transcription and TTS reduces components; it does not make the Realtime model offline or free.

The current BYOK design is appropriate for a personal build: the long-lived key is stored in Keychain and never in source or UserDefaults. A distributed product should put credentials behind a backend, issue short-lived client tokens, and evaluate WebRTC instead of shipping a standard API key to clients.

## Protocol references

- [Realtime WebSocket guide](https://developers.openai.com/api/docs/guides/realtime-websocket)
- [Realtime conversations and audio](https://developers.openai.com/api/docs/guides/realtime-conversations)
- [`gpt-realtime-2.1` model](https://developers.openai.com/api/docs/models/gpt-realtime-2.1)
