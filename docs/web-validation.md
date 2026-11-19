# Web validation · 19 November 2026

Local checks on the development Mac:

| Check | Result |
| --- | --- |
| Frozen Bun install | Passed |
| TypeScript and production build | Passed |
| Prettier check and Git whitespace check | Passed |
| Unit tests | 36 passed; 6,142 assertions |
| Browser flows at desktop, tablet and phone sizes | 27 passed; 3 optional private-PDF checks skipped |
| Separate real MuS chapter PDF import | Passed on 18 November; not repeated on 19 November |
| Production PDF worker/CSP and same-batch duplicate rejection | Passed with the real chapter on 18 November |
| Production root, API status and cache/security headers | Passed |
| Workflow YAML syntax | Parsed locally; GitHub Actions has not run these changes |

The browser flows cover source import, activity generation through a controlled provider stream,
answer withholding, an actual learner attempt, memory, hints/reveals, review dates, reload, lecture
notes, explicit provider errors, retained failed-message drafts and exam review. Unsafe HTML does
not execute. Voice lifecycle tests cover pending-permission cancellation, track release, mute and
late tool results after reconnection. These are not microphone/speaker hardware tests.

The private course file was read locally from the existing course folder. It was not copied into
this repository or sent to a provider during validation. The public landing screenshot uses controlled
example content, not private lecture text or real provider output.

## Interactive model validation

- Exact exponential survival probabilities and gradient steps match their analytic definitions.
- Queue event tests conserve customers, preserve time order and account for time in system.
- Serializing and resuming the queue reproduces its next event.
- A separate deterministic 100,000-event run with arrival rate 4/min and service rate 5/min produced
  mean number in system 3.9806 (theory 4) and mean time in system 0.9902 min (theory 1 min).
  This checks the implementation against a known model, not teaching efficacy or universal convergence.
- Browser flows exercise keyboard sliders, actual touch input in emulation, step/play/pause/reset,
  rate changes, unstable queues, persistence, exam gates and conservative assistance attribution.
- The voice inspection protocol returns current model state without creating another artifact.
- Empty canvases open the local queue example after IndexedDB hydration; occupied canvases remain selected.
- Five built-in examples preserve their individual drafts and model state across switches and reloads.
  Reopening is idempotent. Reasoning saves remain assisted and ungraded without provider requests.
- Models and diagrams expand inside the canvas. Collapsing retains model state; model notes use
  visible text rather than disclosure sections.
- The activity UI has no “Your turn” heading or decorative action icons, and uses stronger borders.

## Initial-load baseline

The earlier static-client build opened in 37–54 ms across five fresh headless Chromium contexts on
loopback (median 47 ms). That is historical local evidence, not an internet or physical-tablet benchmark.
The 18 November build kept model renderers in small lazy chunks. Its initial JavaScript entry was
275.55 kB (Vite gzip estimate 85.71 kB). The current build retains lazy model renderers; the local server
serves assets without HTTP compression.
Model-generation latency, physical input responsiveness and live voice latency remain unmeasured.

## Still unverified

- Real OpenAI/OpenRouter generation, teaching correctness and source fidelity on a live model.
- Microphone-to-model-to-speaker behavior, real acoustic echo cancellation and camera hardware.
- Actual iPad/Safari and mobile keyboard behavior, and access from a remote tablet.
- Educational outcomes, delayed retention and transfer with real learners.
- Public CI and GitHub Pages publication.

The secure OpenAI key request timed out. No paid provider call was made for this web validation.
Keys entered later in the running client remain in tab memory and are excluded from workspace export.
