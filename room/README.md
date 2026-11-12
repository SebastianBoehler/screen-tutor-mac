# Study Room

Group mode for ScreenTutor: a LiveKit video room where a small study group joins with microphones and the cameras above their desks, and a voice tutor joins as a participant. The tutor listens to the group, looks at each learner's paper, and writes formulas, diagrams and tasks on a board that everyone sees.

```
 Browser (each learner)            LiveKit (Cloud or local)            Tutor agent (Python)
 mic + desk camera  ─────────────▶  room  ◀───────────────────────────  OpenAI Realtime voice
 video grid, captions               data topic "study"                  desk watcher per learner
 shared board, tasks, desk status ◀──────────────────────────────────── board / tasks / desks
```

## What the tutor does

- **Listens to the group.** OpenAI Realtime hears one learner at a time; the agent follows LiveKit's active speaker (with a short debounce, never cutting someone off mid-sentence) and tells the model who it is now hearing.
- **Teaches like ScreenTutor solo mode**, using the LecturePilot-derived policy (attempt first, least support, faded steps, transfer, honest mastery), plus group rules: address people by name, rotate questions, do not let the fastest person answer for everyone, let learners explain to each other.
- **Watches every desk camera.** The same on-device change gate as the Mac app decides when a page changed; then the frame goes to an OpenRouter vision model (default `google/gemini-3.5-flash-lite`, zero data retention). The tutor can `look_at_desk(name)` for the actual image or read `desk_notes`. Confident errors, stalls and finished tasks can make the tutor speak up to that learner (45 s cooldown, only while nobody is talking).
- **Shared board and tasks.** `show_on_board` renders Markdown, KaTeX math and Mermaid diagrams for everyone; `assign_task` pins a task for one learner or everyone; `finish_task` records independent / assisted / abandoned.
- **No computer control.** The room tutor can never click on anyone's Mac; that stays opt-in and local in the ScreenTutor app.

## Run it

Needs [uv](https://docs.astral.sh/uv/), [bun](https://bun.sh), and credentials in `room/.env.local` (see `.env.example`), or point `STUDY_ROOM_ENV_FILE` at an existing env file:

```bash
cp room/.env.example room/.env.local   # then fill in the keys
room/dev.sh                            # agent + web on http://localhost:3000
```

- **LiveKit Cloud:** set `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` from your project. The agent registers as `study-tutor`, and every room token carries an explicit dispatch for it, so other agents on the same project are not affected.
- **Fully local:** `brew install livekit`, run `livekit-server --dev`, and use `LIVEKIT_URL=ws://localhost:7880`, `LIVEKIT_API_KEY=devkey`, `LIVEKIT_API_SECRET=secret`.
- `OPENAI_API_KEY` is required for the voice; `OPENROUTER_API_KEY` enables desk observation. If the voice fails (for example a rejected key), the room shows a status line and the board and desk notes keep working.

Open the page, enter your name, share the room code or invite link, and pick your desk camera (an iPhone via Continuity Camera shows up as a normal browser camera). For people outside your network, deploy `room/web` (for example to Vercel with the same env vars) and run the agent anywhere that can reach LiveKit; browsers need HTTPS for camera access on anything but localhost.

## Layout

| Path | Purpose |
| --- | --- |
| `agent/agent.py` | LiveKit agent: session, speaker following, tools, sync, interjections |
| `agent/desk_watch.py` | Per-learner frame capture, change gate, OpenRouter observer |
| `agent/prompts.py` | Group tutor instructions and observer prompt |
| `agent/test_desk_watch.py` | `cd room/agent && .venv/bin/python -m unittest test_desk_watch.py` |
| `web/src/app/api/token/route.ts` | Room tokens with explicit `study-tutor` dispatch |
| `web/src/app/room/[code]/page.tsx` | Video grid, captions, controls, sync |
| `web/src/components/` | Shared board (Markdown + KaTeX + Mermaid), tasks, desk status |
| `web/src/lib/protocol.ts` | Message types on the `study` data topic |
