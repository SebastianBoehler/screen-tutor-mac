# ScreenTutor

[![CI](https://github.com/SebastianBoehler/screen-tutor-mac/actions/workflows/ci.yml/badge.svg)](https://github.com/SebastianBoehler/screen-tutor-mac/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A personal learning canvas: your course material, a voice tutor, and space to work things out.

ScreenTutor is an open-source, bring-your-own-key learning client. The **web client in `web/`**
is the current direction: rich activities first, conversation alongside them, and layouts that
adapt to desktop, tablet and phone widths. The native macOS prototype remains available separately.

## Start locally

Requires [Bun](https://bun.sh) 1.3 or later and a modern browser.

```bash
cd web
bun install --frozen-lockfile
bun run dev
```

Open **http://127.0.0.1:5173**. An empty canvas opens an illustrative queue example without credentials.
For the tutor, import a PDF/text/Markdown document or write a lecture note in your course, then enter
your API key under **Connections**. Keys entered in the client last only until reload.
OpenAI powers live voice; OpenAI or OpenRouter can generate text and activities. Providers bill your
own account. A ChatGPT subscription does not cover this Realtime voice connection.

See [the web guide](web/README.md) for production builds, privacy, tests and architecture.

## The learning loop

1. Choose one concrete goal from your course material.
2. Predict, recall or explain before seeing the answer.
3. Get a small cue, feedback or one worked step when needed.
4. Try a different example, then revisit the concept after a delay.

The canvas supports Markdown, mathematics, causal diagrams, choice questions and free recall.
Interactive activities include exponential waiting-time curves, gradient-descent steps, and a
playable M/M/1 queue simulation. Sliders update local calculations immediately.
Artifacts start as compact previews and expand within the canvas. **Examples** opens five locally
saved, ungraded demonstrations, including a process diagram and rendered mathematics with a table.
Source links open the extracted course page. Lecture notes remain editable learner-authored sources.
Course-scoped memory records revisable teaching hypotheses linked to actual attempts.

Independent checks, assisted attempts, answer reveals and model exploration remain separate. A cross-course review
queue uses expanding intervals and a daily budget, with a student-selected rest window. The client
does not award mastery for viewing content, self-ratings or repeated same-day success.

These are research-informed design choices, **not evidence that this app improves learning**.
See [the learning design and evaluation contract](docs/learning-design.md).

## Status and boundaries

This is an early local build, not a hosted multi-user service. Browser data stays in IndexedDB;
relevant excerpts and conversation go to your selected provider when you ask the tutor. Camera
preview stays local until you explicitly share a frame. API keys are not written to the workspace.

The web client has no terminal, filesystem, Accessibility or computer-control tool. Generated rich
content uses a validated schema and sanitized renderers. Remote hosting, account sync, handwriting
capture, and native tablet apps are future work. Actual iPad/Safari and microphone-to-speaker
behavior still need hardware validation.

## Project map

| Path | Purpose |
| --- | --- |
| [`web/`](web/README.md) | Solo learning client and loopback-only provider API |
| [`ScreenTutor/`](docs/native-macos.md) | Native macOS voice, desk camera, Accessibility and overlay prototype |
| [`room/`](room/README.md) | Separate group-study experiment |
| [`docs/site/`](docs/site/index.html) | Static landing page, prepared for GitHub Pages |
| [`docs/learning-design.md`](docs/learning-design.md) | Pedagogy, evidence rules and evaluation limits |

## Contribute

Start with [CONTRIBUTING.md](CONTRIBUTING.md). Focused fixes, teaching-flow reviews, accessibility,
real-device checks and source-grounded learning activities are welcome. Keep private course files,
photos, API keys and transcripts out of issues and commits. See [SECURITY.md](SECURITY.md) for reports.

[MIT License](LICENSE) · [Code of Conduct](CODE_OF_CONDUCT.md)
