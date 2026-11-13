# ScreenTutor for macOS

[![CI](https://github.com/SebastianBoehler/screen-tutor-mac/actions/workflows/ci.yml/badge.svg)](https://github.com/SebastianBoehler/screen-tutor-mac/actions/workflows/ci.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![macOS 15+](https://img.shields.io/badge/macOS-15%2B-111111?logo=apple)](https://support.apple.com/macos)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A voice tutor that watches your desk, sees your Mac, and teaches like a good one-on-one tutor.

ScreenTutor is a native, open-source menu-bar app for studying at a desk. Mount an iPhone (or any camera) above your paper, talk naturally, and the tutor follows your handwritten work, steps in when you make a mistake or get stuck, puts formulas and diagrams on a floating board, and can open videos, apps and write documents for you.

- **Voice:** full-duplex speech-to-speech over OpenAI's Realtime WebRTC API (`gpt-realtime-2.1` or `-mini`), with barge-in and echo cancellation.
- **Desk observer:** a fast vision model on OpenRouter (default `google/gemini-3.5-flash-lite`, routed for throughput with zero data retention) reads the paper whenever it materially changes and tells the voice tutor what you wrote, where an error is, or that you seem stuck.
- **Pedagogy:** the tutor policy is adapted from [LecturePilot](https://github.com/SebastianBoehler/lecture-pilot): attempt first, least sufficient support (prompt → cue → faded example → one worked step), hand the next step back, fade into independent transfer tasks, and never count assisted work as mastery.

> [!IMPORTANT]
> ScreenTutor is an early-stage, bring-your-own-key project for local development. It is not currently distributed as a signed or notarized app.

## What it does

- **Live desk camera** — continuous capture from an iPhone via Continuity Camera or Desk View, a USB document camera, or the built-in camera, with a Desk window for preview, camera choice and rotation (for an upside-down overhead mount)
- **On-device change detection** — a 64×48 grayscale fingerprint decides when new writing has appeared and your hand has moved away, so the observer runs only on real changes (and once more if an active task shows no progress for 90 seconds)
- **Proactive tutoring** — when the observer flags an error you have moved past, a stall, finished work, or (in Active mode) a natural check-in, the tutor speaks first with a short cue or question — never while you or it are talking, and with a cooldown
- **Tasks on paper** — the tutor can `assign_task`; the task is pinned on the Tutor Board and the observer checks your paper against it until `finish_task` records an honest outcome (independent, assisted, abandoned)
- **Tutor Board** — a floating panel that renders Markdown, LaTeX math (KaTeX) and Mermaid diagrams for things that are hard to follow by ear
- **Screen annotations** — the tutor says what to mark ("circle the η in the update rule, label it step size") and boxes, circles, underlines, arrows, a spotlight or short notes draw themselves over any app in about 1.5 s, in the order the tutor talks about them. Labels are placed so they never cover the marked text or each other
- **Lesson videos** — the tutor finds YouTube videos and plays them in ScreenTutor's own player window, then pauses to ask a prediction, replays or loops a short section, slows it down, or jumps to a chapter; it can also annotate a paused frame
- **Mac actions** — open a URL, open an installed app, or write a Word (`.docx`), Markdown or RTF document into `~/Downloads/ScreenTutor` and open it
- **Screen awareness** — on request, the tutor lists visible windows, captures only the relevant one, and can move a rendered teaching cursor to a precise point
- Desk context is attached automatically to each spoken turn as a short text note; the tutor calls `look_at_desk` when it needs the actual image
- The microphone stays open while the desk observer is watching (silence usually means you are writing); otherwise it auto-pauses after 20 seconds
- Local, text-only conversation history (JSONL), custom teaching instructions, Automatic/Deutsch/English speech, model and reasoning-effort choice, Keychain-stored keys, global shortcut (default Command-Shift-Space), launch at login

- **Computer control (opt-in)** — with Settings > Computer control on and Accessibility granted, the tutor can click, type, press shortcuts and scroll in a window it just captured, or hand a multi-step goal ("open the lecture PDF in Downloads and go to the eigenvalue chapter") to a background agent that loops screenshot → `google/gemini-3.5-flash` → action while you keep talking, then reports back by voice

Computer control is off by default. It acts only when you ask or agree, never types passwords or payment details, signs in, buys, sends messages, accepts terms, changes system settings or deletes files, and it stops immediately when you move the mouse, say "stop", or press **Stop computer task** in the menu.

## Study room (group mode)

`room/` adds a shared video study room with no media server and no SDKs, and only an OpenAI API key is required. Learners join from a browser with their mic and desk camera, video goes directly between browsers, and a small Bun server mixes everyone's audio into one raw OpenAI Realtime WebSocket. The tutor knows who spoke, answers when addressed, watches every desk with the same change gate, and keeps a shared board (Markdown, math, Mermaid), tasks, and desk status in sync for everyone. Open it from the menu bar with **Study room with others…**. See [room/README.md](room/README.md).

## How the desk loop works

1. The Desk window keeps one `AVCaptureSession` running on the selected camera; frames stay on the Mac and only the newest rotated frame is kept.
2. Once per second the observer compares a tiny fingerprint of the frame with the previous tick (motion: a hand) and with the last analysed frame (material change: new writing).
3. When the page changed and the image has been still for 1.5 seconds (at most every 4 seconds), the frame goes to the OpenRouter vision model with the active task, the previous observation, and the last spoken exchange. It returns JSON: summary, faithful LaTeX transcription, progress, an optional located issue, and an optional interjection with a suggested pedagogical move.
4. If the interjection kind is allowed by the chosen proactivity and the cooldown has passed, ScreenTutor waits until the conversation is idle, adds a `<desk_observer>` note plus the frame to the Realtime conversation, and asks the voice tutor to respond — typically one short cue like "check the sign in your second line".
5. When you speak, the newest observer note is attached after your turn so the tutor knows what is on the paper without an extra round trip.

## How screen annotations work

1. `annotate_screen` captures the display under the pointer, hiding ScreenTutor's own windows except the lesson player.
2. On the Mac, Vision text recognition finds every text line together with word-level boxes. When ScreenTutor is trusted for Accessibility (and not sandboxed), it also reads the frontmost app's controls from the accessibility tree.
3. The model gets a 1024 px screenshot with reference marks drawn on it, plus a numbered list of elements (`t12 [x0,y0,x1,y1] "text"`):
   - a faint 0–1000 grid labelled along the edges
   - small id tags on the elements

   It returns which element (and which substring) to mark. Free coordinates are only for figures or video frames. The default model is `deepseek/deepseek-v4.1-flash` via OpenRouter, with reasoning off and zero data retention.
4. Element ids resolve to the exact on-screen word boxes. Prefers whole words, so "eta" never lands inside "theta".
5. Click-through panels, one per display, draw the marks with animated strokes and place labels so they don't collide.

The voice tutor waits up to 3 s for the result, so it can say what was drawn; slower plans keep drawing in the background.

Measured on synthetic slides (Nov 2026):
- **Text targets:** the circle lands on the requested word in about 1.5 s.
- **Figure target** ("circle the minimum of the loss curve"), median error over 3 runs:

  | Model | Plain | Grid | Grid + tags |
  |---|---|---|---|
  | DeepSeek V4.1 Flash | 17 px | 9 px | 2 px |
  | Gemini 3.1 Flash Lite | 31 px | 30 px | 74 px |
  | Gemma 4 26B | 101 px | 65 px | 78 px |

  The grid helps every model, so it stays on.

## How the lesson player works

- **Finding videos:** `find_videos` reads YouTube's public search page (no API key): ids, titles, channels and lengths. `play_video` also reads the video's chapter timestamps from its description. YouTube now blocks transcripts without a token, so chapters and titles are what the tutor uses to jump to a concept.
- **Playback:** the video plays through the official IFrame Player API inside a WKWebView in a floating window. `control_video` covers play, pause, seek, back/forward, speed, loop A–B, status and close, and reports position, duration and loop state back to the tutor.
- Videos that forbid embedding return an error, and the tutor picks another.

## How computer control works

- **Direct tools** (`click_in_window`, `type_text`, `press_keys`, `scroll_window`) act on the window from the latest `capture_window`, mapping normalized coordinates through the window's live frame, showing the tutor cursor at the target first, then posting `CGEvent`s. Shortcuts are mapped through the current keyboard layout, so `cmd+z` is correct on QWERTZ too.
- **Background agent** (`do_on_computer`): captures the display under the pointer with ScreenTutor's own windows hidden, asks the agent model for one JSON action (0–1000 coordinates, `type`, `keys`, `scroll`, `open_url`, `open_app`, `wait`, `done`, `needs_user`), executes it, waits for the UI to settle, and repeats up to 25 steps. Its report reaches the voice tutor as a `<computer_agent>` note once the conversation is idle.
- **Takeover:** before every event, ScreenTutor checks whether the real pointer moved more than 60 pt from where it last put it; if so, it stops and tells the tutor that you took over.

## How one voice turn works

1. WebRTC streams the microphone to GPT; semantic VAD detects turns and interrupts any current answer.
2. ScreenTutor commits the turn, attaches the latest desk note, and requests a response.
3. The tutor may call tools: `look_at_desk`, `get_desk_notes`, `assign_task`, `finish_task`, `show_visual`, `list_windows`, `capture_window`, `point_at_screen_position`, `open_url`, `search_youtube`, `open_application`, `create_document`, and (when enabled) `click_in_window`, `type_text`, `press_keys`, `scroll_window`, `do_on_computer`, `stop_computer_task`. Tools run serially; failures come back as recoverable tool errors.
4. Images (desk frames, window captures) are appended as high-detail `input_image` items for the current turn only.
5. Remote audio plays immediately; transcripts update the menu and the on-screen HUD.

## Requirements

- macOS 15 or newer
- Xcode 16.4 or newer with Swift 6 support
- An OpenAI API key with access to `gpt-realtime-2.1` or `gpt-realtime-2.1-mini`
- An OpenRouter API key for the desk observer (optional; saved in Keychain, or read from `OPENROUTER_API_KEY` when launched from Xcode or a shell)
- For the desk: an iPhone on a desk/arm mount (Continuity Camera), Desk View, or any USB camera
- For computer control: Accessibility permission (Privacy & Security > Accessibility), requested when you enable it
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.45 or newer only when regenerating the checked-in Xcode project

## Run locally

1. Clone the repository.
2. Copy `Config/LocalSigning.xcconfig.example` to `Config/LocalSigning.xcconfig` and replace `YOUR_TEAM_ID` with the Team ID shown in Xcode Settings > Accounts. The local file is ignored by Git and gives builds a stable signed identity; ad-hoc builds can lose their macOS privacy grants after every rebuild.
3. Open `ScreenTutor.xcodeproj` in Xcode and run the `ScreenTutor` scheme on My Mac.
4. Open the waveform menu-bar item, choose Settings, save your API key, and optionally pin the
   tutor's Realtime model, spoken language, reasoning effort, or teaching instructions. Automatic
   follows the language of your latest spoken turn.
5. In Settings > Desk observer, save an OpenRouter key (or rely on `OPENROUTER_API_KEY`) and keep or change the vision model.
6. Open **Desk…** from the menu, pick your iPhone/Desk View/USB camera, set the orientation, press **Start camera**, then **Watch desk**. Choose how proactive the tutor may be (Only when asked, Gentle, Active).
7. Start a conversation with Command-Shift-Space and grant Microphone and Screen Recording access. macOS may require one app restart after Screen Recording is first granted.
8. Work on paper and talk. Try "give me a practice problem on eigenvalues", "check my last line", "show me the derivation on the board", "find me a YouTube video on this", or "write a one-page summary as a Word document".

Press the shortcut again to mute only ScreenTutor's microphone upload. The Realtime connection and any answer already being spoken remain active; OBS and other microphone-enabled apps can continue recording. Press it later to unmute and resume the same conversation, including prior voice turns. Change the combination under Settings > System by clicking the shortcut recorder and typing a modified key combination. If macOS or another app already owns it, ScreenTutor keeps the prior working shortcut and reports the conflict.

ScreenTutor keeps the microphone live while the tutor is speaking, so you can interrupt a reply naturally. WebRTC receives the tutor playback reference needed for acoustic echo cancellation and OpenAI tracks the remote playback buffer for interruption truncation. ScreenTutor no longer reconfigures the Mac input device with a private `AVAudioEngine`, so OBS and other microphone-enabled apps can retain their own capture streams.

Realtime sessions last at most 60 minutes. The menu and draggable overlay show the current Listening, Thinking, Speaking, or Microphone muted state. Green means ScreenTutor input is live, orange means it is muted, and the icon and label provide the same state without relying on color. The overlay also shows live window-listing, window capture, camera capture, and pointing tool chips and plays a short cue before ScreenTutor inspects window information or pixels. Choose New conversation when you want an empty context.

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
| `Audio` | Microphone permission and WebRTC media capture |
| `Desk` | Continuous desk camera, on-device change gate, OpenRouter observer and its prompt/JSON contract |
| `Actions` | Validated Mac actions (URLs, YouTube, apps, documents) and layout-aware mouse/keyboard input |
| `Computer` | Display capture and the screenshot → model → action computer agent |
| `Camera` | Camera permission |
| `Realtime` | Typed OpenAI events, WebRTC media, and data-channel transport |
| `Screen` | Privacy-filtered window catalog and model-selected one-shot capture |
| `History` | Ordered, private JSONL persistence and conversation projection |
| `UI` | Menu, Desk window, Tutor Board, transcript HUD, history browser, settings, and tutor cursor |
| `System` | Global hotkey and launch-at-login integration |

The native app uses SwiftUI, AppKit, AVFoundation, AVFAudio, ScreenCaptureKit, Security, ServiceManagement, and Carbon. WebRTC media and audio processing come from the community-maintained [`stasel/WebRTC`](https://github.com/stasel/WebRTC) Swift package, pinned to M150 and built unmodified from the upstream WebRTC source. See that project and WebRTC's BSD license for dependency notices.

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

The desk camera runs only after you press Start camera in the Desk window, and stops with Stop camera or Quit. Frames stay in memory on the Mac (only the newest one is kept). While Watch desk is on, a compressed frame (at most 180 KB) is sent to OpenRouter only when the page materially changes, when an active task shows no visible progress, or when you press Look now; requests ask OpenRouter for zero-data-retention providers that do not collect prompts. The voice tutor receives a desk frame only when it calls `look_at_desk` or when a proactive interjection is delivered, plus short text notes from the observer after your spoken turns. Desk images are not written to conversation JSONL. Anything on your desk—including other documents—can end up in a frame, so keep sensitive papers out of view.

When computer control is used, the background agent sends a screenshot of the display under the pointer (ScreenTutor's own windows excluded) to OpenRouter for every step, with the same zero-retention routing. Anything visible on that display can be included, so close sensitive windows first. Direct click/type tools send nothing extra beyond the window capture the tutor already made.

Documents written by `create_document` go to `~/Downloads/ScreenTutor` (the sandbox grants Downloads read/write for this) and are opened in their default app. URLs are limited to http and https.

The sandbox grants client and server networking because WebRTC ICE must bind a local peer socket before connecting to OpenAI. ScreenTutor does not run an application-level HTTP server or accept commands over that entitlement.

Completed user and assistant captions are retained as plain-text JSONL in ScreenTutor's sandboxed Application Support directory. The directory and files use owner-only permissions (`0700` and `0600`); ScreenTutor does not add application-level encryption. The logs contain transcript text, provider correlation IDs, and tool names with success/failure status—not audio, screenshots, window titles, tool arguments, coordinates, or result payloads. Use Conversation History… > Reveal JSONL to find them. Hide the on-screen transcript when people nearby should not see it.

The selected model, custom tutor instructions, and reasoning effort are stored locally in `UserDefaults`. They are sent to OpenAI as part of each new Realtime session and are not written to conversation-history JSONL.

Muting disables only ScreenTutor's local WebRTC microphone track. It does not close the peer connection, stop tutor playback, mute the Mac globally, or block OBS from using the microphone. New conversation and Quit disconnect the session. After a network disconnect, ScreenTutor reconnects on the next microphone action and restores completed turns from local history into a new Realtime session.

The desk observer is billed by OpenRouter per request (one image plus a few hundred output tokens; with Gemini Flash Lite a request typically takes 2–4 seconds). `gpt-realtime-2.1`, `gpt-realtime-2.1-mini`, and `gpt-4o-mini-transcribe` are cloud API models and incur their respective OpenAI API usage charges. At current standard rates, flagship audio costs $32 input / $64 output per 1M audio tokens; mini costs $10 input / $20 output. Text and captured images are also billed. The auxiliary input transcript does not sit in the direct speech-to-speech answer path, but it is separately billed. ScreenTutor is not offline or free to run.

The current BYOK design is intended for personal development: the long-lived key is stored in Keychain and used only by the native HTTPS request that creates the WebRTC call; it is never placed in SDP, source, or `UserDefaults`. A distributed product should put credentials behind a backend and issue short-lived client tokens instead of shipping a standard API key to clients.

## Contributing

Bug reports, accessibility improvements, documentation, focused tests, and well-scoped implementation changes are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md). Report security issues through the process in [SECURITY.md](SECURITY.md), not a public issue.

## Protocol references

- [Realtime WebRTC guide](https://developers.openai.com/api/docs/guides/realtime-webrtc)
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
