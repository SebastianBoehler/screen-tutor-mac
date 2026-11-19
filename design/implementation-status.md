# Implementation status · 19 November 2026

The user rejected the native UI and authorized a canvas-first web client. A local React client now
exists in `web/`; native work remains an optional prototype, not the accepted primary interface.

## Web implementation

- React, TypeScript, Vite and a loopback-only Bun provider API.
- Course-scoped local documents, batch PDF/text/Markdown import and editable lecture notes.
- Safe math/Markdown, causal diagrams, prediction choices, recall and attempt-first activities.
- BYOK streamed OpenAI/OpenRouter text, OpenAI WebRTC voice and explicit note-photo sharing.
- Separate assistance/reveal evidence, editable reasoning hypotheses, review dates and rest windows.
- Slider-driven exponential curves and gradient-descent trajectories, plus a playable M/M/1 queue.
- Live exploration inspection, bounded deterministic continuation state and conservative assistance
  tracking; existing workspaces migrate without discarding course or activity data.
- Simplified activity layout: no “Your turn” heading, fewer labels/icons and stronger borders.
- Empty-canvas prefill and five idempotent, ungraded examples. Compact artifacts expand within
  the canvas and retain their state. Model notes no longer use expandable descriptions.
- Desktop/tablet/phone layouts with stable activity identity, keyboard controls and touch targets.
- Updated setup, contributor, security and learning-design documents; web CI and a static landing
  page with a manual GitHub Pages workflow. Publication remains a separate manual action.

## Web validation

- Production build, TypeScript and formatting checks pass locally.
- 36 unit tests cover evidence, examples, source isolation, request boundaries, streaming and voice lifecycle.
- 27 browser flows pass across desktop, tablet and phone emulation, using controlled provider streams;
  3 optional private-PDF checks skip without a supplied file.
- A separate real `Modellierung und Simulation` chapter PDF import/duplicate check passed locally.
- Real provider calls, microphone-to-speaker behavior and actual tablet/Safari behavior remain
  unverified. Browser flow tests are not evidence of teaching correctness or learning efficacy.

## Prepared code, not a release

- Native Accessibility inspection, activation and anchored overlays, with stale-target checks.
- Local course PDF/text import, SQLite full-text search and source-page links.
- Persistent learning artifacts, reveal-before-rating flashcards and editable reasoning memory.
- Goal-aware tutoring policy, unaided-check guards, course-scoped workspaces and study planning.
- A replacement canvas-first native shell. This remains unapproved visually.
- Bundled local Markdown, KaTeX and Mermaid renderers, with a restricted content bridge.

## Verification so far

- Full local suite: 176 tests executed, 7 opt-in tests skipped, zero failures on 19 November.
- A separate source-to-goal-to-artifact-to-recall tool-dispatch test subsequently passed.
- The rich-renderer test verified local math/diagram rendering, hidden flashcard answers,
  reveal events and rejection of injected scripts/unsafe links.
- Real native component check passed against the disposable study fixture: native press,
  window tracking, offscreen scrolling and reappearance. The Xcode-hosted live test lacks
  its own Accessibility permission; it correctly skips instead of claiming a pass.
- Native app layouts were inspected. User feedback establishes that the design is insufficient.
- Microphone-to-model-to-speaker behavior, real-course tutoring quality and mobile behavior
  remain unverified. Passing these tests is not evidence of improved learning outcomes.

## Direction and remaining validation

Canvas-first web is accepted. Image generation was not completed because the saved key was
unavailable; the user subsequently authorized implementation without waiting for images.

The first personal course is Modellierung und Simulation, with an exam target in December. The
exact day is not confirmed. Private materials were located and used for local import validation;
they are not included in this public repository or automatically sent to a provider.

The user chose BYOK voice before ChatGPT account sign-in. Remote hosting, account sync and pen
capture remain future work. Public CI and GitHub Pages cannot be claimed verified until pushed
and run; their workflows are prepared locally.
