# Study Room

Group mode for ScreenTutor: a small study group joins a video room from their browsers with their microphones and the cameras above their desks. A voice tutor listens to the whole group, looks at each learner's paper, and writes formulas, diagrams and tasks on a board that everyone sees.

There is no media server, agent framework or SDK. The only thing you need is an OpenAI API key.

```
 Browser (each learner)                 Room server (Bun, ~1 file per concern)       OpenAI
 ───────────────────────                ─────────────────────────────────────       ──────
 desk camera ◀── WebRTC, peer to peer ──▶ other learners' browsers
 mic → 24 kHz PCM16 ── WebSocket ──────▶  mixer (sum + speaker energy) ── WebSocket ──▶ Realtime (gpt-realtime-2.1)
 speaker ◀─────────── tutor PCM ───────── relay                         ◀─ audio, tool calls
 desk change gate → JPEG on change ────▶  desk observer ─────────────── HTTPS ──────▶ Responses (gpt-5.4-mini)
 board, tasks, desks ◀── room state ───── tools: board, tasks, look_at_desk
```

- **Video** goes directly between browsers (full mesh, up to 6 people). The server only relays the WebRTC signaling messages. Desk cameras are sent as "detail" content at up to 2.5 Mbit/s so handwriting stays readable.
- **Voice**: every browser sends its microphone as raw 24 kHz PCM over the room WebSocket. The server mixes all of them into one stream for one Realtime session per room, over a raw WebSocket, so the API key never reaches a browser. The tutor's audio is sent back to every browser, which plays it through a local WebRTC loopback so the browser's echo canceller removes it from the microphone.
- **Who said what**: the mixer tracks how loud each learner was during a turn. When the Realtime voice activity detector commits a turn, the server inserts `[room] Heard: Anna, Ben` right after it.
- **When the tutor answers**: with one learner, always. With several learners, the server waits for the transcript and answers only when someone addresses the tutor ("Tutor, …"), when someone presses **Ask tutor**, or within 25 s of the tutor's last words. Otherwise the turn stays in context as group discussion.
- **Desks**: each browser runs the same change gate as the Mac app on its own camera. It computes a 64×48 fingerprint once a second and sends a photo only when the page has materially changed and the image has been still for 1.5 s, or when an active task has shown no progress for 90 s. The server asks a fast vision model for a structured observation (summary, LaTeX transcription, progress, a located issue, an optional interjection). `look_at_desk(name)` asks that learner's browser for a fresh photo and gives it to the Realtime model as an image.
- **Teaching** follows ScreenTutor's LecturePilot-derived policy (attempt first, least support, faded steps, transfer, honest mastery), plus group rules: address people by name, rotate questions, let learners explain to each other, and keep derivations on the board.
- **No computer control.** The room tutor never touches anyone's computer. Computer control stays opt-in and local in the Mac app.

## Run it

Needs [Bun](https://bun.sh) ≥ 1.3.

```bash
cd room
cp .env.example .env.local   # set OPENAI_API_KEY
bun install                   # dev-only: TypeScript types, no runtime dependencies
bun run dev                   # http://localhost:3000
```

Open the page, enter your name, share the invite link, and pick your desk camera. An iPhone via Continuity Camera shows up as a normal browser camera. `?fake=1` on a room URL replaces the camera and microphone with a synthetic desk (paper with a growing derivation) and silence, for testing without devices.

Optional settings (see `.env.example`):

- `OPENROUTER_API_KEY` or a `DESK_OBSERVER_MODEL` containing a slash switches the observer to OpenRouter, e.g. `google/gemini-3.5-flash-lite`.
- `STUDY_TUTOR_MODEL` sets the Realtime model.
- `ICE_SERVERS` adds a TURN server for learners on networks that block peer-to-peer connections.

Without `OPENAI_API_KEY` the room still works as a video room with desk notes (if an OpenRouter key is set), and the header says the tutor's voice is off.

To reach learners outside your network, deploy the server anywhere Bun runs, behind HTTPS (browsers only allow cameras on HTTPS or localhost), with `bun run start`.

## Why not GPT-Live or a media server?

- **GPT-Live-1** (`/v1/live/sessions`) is OpenAI's newer full-duplex voice model, with hosted delegation to a Responses model for reasoning and tools. It accepts only audio and text, though, and the tutor's core job is to look at handwritten work. The Realtime API takes images and function tools in the same session, so it stays the voice layer for now. Swapping the voice layer only touches `src/server/tutor.ts`.
- **A media server** (LiveKit, mediasoup and similar) is what lets rooms grow past about 6 people, record them, or join over phone lines. A study group doesn't need any of that, so peer-to-peer video plus a 40 ms audio mixer is enough.

## Layout

| Path | Purpose |
| --- | --- |
| `server.ts` | Entry point; reads env and starts the server |
| `src/server/app.ts` | `Bun.serve`: pages, `/ws/:room` WebSocket, room registry |
| `src/server/room.ts` | Participants, signaling relay, turn policy, tools, desk observations, interjections |
| `src/server/tutor.ts` | Raw Realtime WebSocket client: session, audio in/out, barge-in truncation, tool loop |
| `src/server/mixer.ts` | 40 ms PCM mixer with per-speaker energy |
| `src/server/observer.ts` | Desk observer over OpenAI Responses or OpenRouter |
| `src/server/prompts.ts` | Tutor and observer prompts |
| `src/client/room.ts` | Room page: media, controls, rendering |
| `src/client/mesh.ts` | Peer-to-peer WebRTC with perfect negotiation |
| `src/client/audio.ts` | AudioWorklet microphone capture and echo-cancelled tutor playback |
| `src/client/desk.ts`, `src/shared/deskGate.ts` | Desk change gate (same thresholds as the Swift `DeskChangeGate`) |
| `src/client/markdown.ts` | Board rendering: marked + KaTeX + Mermaid, raw HTML escaped |
| `src/shared/protocol.ts` | Message types on the room WebSocket |
| `test/` | `bun test`: gate, mixer, observer parsing, and a full room flow against a fake Realtime server |
