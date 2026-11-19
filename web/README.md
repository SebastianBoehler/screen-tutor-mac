# ScreenTutor learning client

A canvas-first React/TypeScript app, with a small Bun API server. No database service, agent framework
or account is required. The existing native Mac and group-room projects are separate programs.

## Run

```bash
bun install --frozen-lockfile
bun run dev
```

Open http://127.0.0.1:5173. An empty canvas opens an illustrative queue example without credentials.
Use **Examples** to try the other supported displays. For the tutor, import a document or write a
lecture note in your course, and add your provider key in **Connections** before starting a lesson.

- Text and rich activities: OpenAI `gpt-5.4-mini` or OpenRouter `google/gemini-3.5-flash`.
- Live voice: OpenAI `gpt-realtime-2.1`, microphone permission and browser audio playback.
- Note photos: start the camera, capture a frame, then send it. Attaching a photo also works.
- OpenRouter requests require providers that support structured output and zero data retention;
  incompatible routing produces an error instead of silently switching models or providers.

Keys entered in Connections remain in JavaScript memory until reload. Alternatively, copy
`.env.example` to `.env` and set the keys for your local server. Never commit that file.
The current app does not use ChatGPT sign-in or subscription billing.

Production mode uses the same loopback-only server and one origin:

```bash
bun run build
bun run start
```

Open http://127.0.0.1:4318. This is a local build, not an authenticated remote service.
Changing origins also changes the browser’s storage partition; dev and production workspaces are
separate. Export your workspace before clearing site data. The export contains private learning data.
There is no account sync, automatic backup or restore importer yet.

## Data and permissions

The workspace contains courses, extracted source pages, learner-authored notes, activities,
answers, interaction events, conversation text and editable memory. It lives in IndexedDB on this
browser origin, without application-level encryption. Keys and note photos are excluded.

The app sends bounded relevant excerpts, recent conversation, current activity and course-scoped
learning context when you ask the tutor. Original PDF files are not uploaded. A camera preview stays
local; the current frame is sent only after explicit sharing. Live voice streams microphone audio
to OpenAI while connected; muting disables the microphone track, disconnecting releases it.
A full browser reload ends voice. Voice-supported attempts are conservatively recorded as assisted.

The local API binds to `127.0.0.1`, rejects foreign origins/hostnames and requires a custom request
header for mutations. Provider endpoints are fixed. There is no OS-action bridge. Generated
activities are schema-validated; raw HTML is sanitized and math uses untrusted mode. These boundaries
do not protect against malicious software already running as your local user or a compromised browser.

## Architecture

| Module | Responsibility |
| --- | --- |
| `src/domain/` | Serializable learning data, retrieval, reply validation and review rules |
| `src/services/` | IndexedDB, provider streaming, voice lifecycle, document/photo import |
| `src/components/` | Focused teaching and workspace surfaces |
| `src/interactive/` | Compiled models, validated specs, local state and mathematical engines |
| `src/styles/` | Shared tokens and component styles; no parallel styling system |
| `server/` | Local origin checks, bounded request validation and fixed provider calls |
| `test/unit/` | Evidence, source isolation, request validation and provider boundaries |
| `test/e2e/` | Browser-level learning flow and explicit failure behavior |

A learning activity has stable identity and state independent of viewport layout. Touch and keyboard
use the same controls. Essential actions do not require hover, a precise drag or a visible sidebar.
Documents and rich renderers load on demand. The initial app uses system fonts; there are no CDN scripts.

Text streams from the provider, but an activity becomes interactive only after its full JSON passes
validation. This avoids displaying incomplete questions or unstable controls during generation.
`useTutor` measures request-to-validated-activity time; `VoiceSession` measures connection-start-to-first
playback. These are separate from initial page load and are not public performance guarantees.

## Interactive activities

The tutor can return one compiled interactive model in `activity.interactive`:

| Kind | Controls and visual | Model scope |
| --- | --- | --- |
| `exponential` | Arrival-rate/time sliders and survival curve | Constant-rate Poisson arrivals |
| `gradient-descent` | Learning-rate/start sliders, one-step/reset actions and trajectory | One-dimensional quadratic loss, `L(x)=x²` |
| `queue` | Arrival/service sliders, play/pause, step/reset and queue history | FCFS M/M/1, initially empty, rates per minute |

These are executable local teaching components, not arbitrary generated code. Specs validate numeric
bounds and slider increments. Provider data cannot supply scripts, formulas to evaluate, URLs or OS
commands. A new model family needs a schema entry, compiled component and mathematical tests.

Interactive models and process diagrams start as compact previews with **Expand / Collapse** inside
the canvas. Model notes remain visible in the expanded model, without disclosure sections.
The built-in examples have stable IDs and preserve separate drafts and simulation state. Reopening
one does not duplicate it. Saved example reasoning remains assisted and ungraded; no provider call
or mastery credit is involved. Existing occupied canvases remain selected when the app reloads.

Example requests after adding course material: “Use the queue simulator to explain what happens
as arrival rate approaches service rate,” or “Show an exponential waiting-time curve I can change.”

Exploration records assistance, not correctness or mastery. An exam model stays closed until the
learner explicitly opens assisted exploration. Questions should test a prediction or new setting,
rather than ask for an answer already displayed by a widget.

The finite queue run uses a reproducible random generator and retains its complete continuation
state. Rate changes restart it; play starts only on request, pauses when the document is hidden,
and stops after 2,000 events. The plot retains the last 160 events. Finite-run estimates stay distinct
from stationary M/M/1 theory; no stationary distribution is claimed when arrival rate >= service rate.

Rendering updates locally while durable workspace checkpoints happen at most once per second.
Leaving the activity, hiding the document, pausing/stepping, or submitting an answer flushes current
state. Reload resumes paused. Text requests and the voice `inspect_activity` tool read live model
state, including changes newer than the latest checkpoint. Moving a slider does not send a provider
request. Existing version-one workspaces migrate to version two while preserving their learning data.

## Validate

```bash
bun run typecheck
bun run test
bun run build
bunx playwright install chromium
bun run test:e2e
```

Browser tests use a controlled provider stream. They exercise actual import, IndexedDB, rendering,
attempt/hint/reveal events, editable memory, review planning and reload behavior at desktop, tablet
and phone widths. They do not establish provider availability, teaching correctness or hardware support.

Optional private PDF import check (file stays on this machine):

```bash
STUDY_TEST_PDF='/absolute/path/to/your-course.pdf' bun run test:e2e --project=desktop
```

For a real session, verify source citations and mathematical reasoning, then test an unseen unaided
question after a delay. Report hardware, browser, assistance and failures separately. See the
[learning evaluation contract](../docs/learning-design.md).

Current local evidence and limitations: [validation report](../docs/web-validation.md).
