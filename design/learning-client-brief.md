# Learning client visual brief

## Current direction

The learner studies through a rich, interactive canvas. Voice and camera notes support the
canvas. Conversation text is secondary. The user rejected the initial native UI and requested
visual mockups before more implementation. Web-first is the accepted direction. Do not continue
polishing the rejected shell as the final design.

## Product

- A personal learning harness that uses course materials, reasoning memory and independent
  learning evidence to guide a student.
- One concept, mechanism or question at a time. Small explanations build from the student's
  actual reasoning. Hints follow an attempt and fade after independent success.
- H5P-like interactions: prediction, reveal, matching, short quizzes, interactive diagrams and
  step construction. The canvas is an activity surface, not a transcript in a large card.
- Multi-course library, source references, a manageable plan, spaced review, a student-selected
  rest window and an inspectable learning memory.
- First release: users bring their own OpenAI/OpenRouter keys. Official ChatGPT plan sharing
  currently supports eligible Responses requests, not the Realtime voice path; sign-in is deferred.
- Tablet-friendly layout and touch interaction are architecture requirements from the start.
  Remote agent hosting and dedicated mobile clients remain future options.

## Tablet, notes and adaptation boundaries

- Use responsive activity layouts, keyboard and touch input, and accessible controls. Essential
  actions must not depend on hover, precise dragging or a permanently visible sidebar.
- Keep source material, lecture notes, study activities and learning evidence distinct. Future
  lecture note capture should produce editable notes with course, lecture and source provenance.
  A tutor interpretation must not silently become an authoritative course source.
- Keep the learning session independent of client layout. A narrower screen changes presentation,
  not the current question, learner attempt or activity state.
- Start with a general student workflow. Adapt scaffolding and difficulty from actual attempts,
  explanations and explicit preferences. Do not infer fixed learning styles or immutable ability.
- Separate unaided retrieval, assisted attempts, answer reveals and self-ratings. Give students
  inspectable, correctable memory; do not label a concept mastered from a reveal or self-rating.
- Use brief goals, useful feedback and visible learning progress for engagement. No punitive
  streaks, competitive rankings or pressure to study through the student's protected rest window.
- Retrieval practice, spacing, feedback and scaffold fading are design principles to substantiate
  in the implementation. These mockups do not establish educational efficacy.

## Implementation success checks after visual selection

- The same activity works with keyboard and touch at desktop and portrait-tablet widths,
  without clipped controls or a required horizontal scroll. Resizing preserves an entered answer.
- A learner can submit an attempt, request a hint and reveal an answer. Each event remains
  distinguishable in learning history; revealing an answer cannot award mastery.
- A generated activity retains links to its course sources. Future note-derived material must
  retain the original note and distinguish it from a tutor-generated interpretation.
- Students can inspect and correct reasoning memory. A new course does not inherit another
  course's mastery evidence merely because terminology overlaps.
- Progress feedback celebrates evidence of learning and explains the next manageable step.
  A missed day does not erase progress or override the student's rest window.
- Measure initial load, first audio and time to an interactive artifact separately on actual
  devices. A desktop design image is not tablet validation or a performance benchmark.

## Visual requirements

- Minimal, precise and welcoming; closer to LecturePilot and T3 Code than a generic SaaS dashboard.
- Canvas open by default. Voice controls and a compact composer remain in a stable location.
- Consistent type, alignment, spacing, corner geometry and control treatment. One quiet accent.
- Sidebar for courses and a few destinations; secondary panels open only when useful.
- The populated teaching artifact carries the visual hierarchy. No feature inventory, gradient
  background, ornamental cards, sparkles, invented logo or fake activity data.
- Three distinct, high-fidelity mockups of a complete, populated study viewport, not wireframes.

## Directly inspected references

- `/Users/sebastianboehler/Documents/GitHub/lecture-pilot/docs/assets/lecturepilot-lesson-ui.jpg`
- `/Users/sebastianboehler/Documents/GitHub/lecture-pilot/docs/assets/lecturepilot-lesson-canvas.jpg`
- LecturePilot `apps/web/src/theme.css`: quiet warm surfaces, readable typography, restrained blue.
- Alife Moodle card styles: shared edges, consistent spacing, content-first hierarchy.
- T3 Code desktop client: stable navigation, restrained chrome, primary work surface, compact
  composer, optional secondary context. Its actual client and public rich-reply sources were read.

## Reference implementation findings

T3 visual replies are theme-aware, responsive and expandable. Client-measured content height
prevents nested scrolling. User interaction inside rich content must not trigger forced follow
scrolling. The learning harness should additionally receive explicit interaction events so it
can distinguish an attempt, a reveal and a self-rating.

Official sources:
- https://github.com/pingdotgg/t3code/blob/main/docs/user/html-renders.md
- https://github.com/pingdotgg/t3code/blob/main/apps/web/src/components/chat/HtmlRenderFrame.tsx
- https://github.com/pingdotgg/t3code/blob/main/packages/shared/src/htmlRender.ts
- https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations

## Speed requirements

Keep initial page code small; load rich renderers on demand. Stream voice and responses. Retrieve
relevant course excerpts rather than attaching an entire library every turn. Preserve artifact
identity during updates. Measure page load, first audio and time to usable artifact independently.

## Visual directions to explore

### Guided concept canvas

One large interactive diagram, one prediction prompt and one stable voice/composer bar. Slim
course navigation and a source reference. The diagram dominates, with minimal surrounding chrome.

### Interactive lesson page

A focused, beautifully typeset lesson with an embedded H5P-style activity. Diagram, explanation
and prediction read as one learning sequence. Quiet course navigation; conversation stays secondary.

### Concept workbench

A spatial mechanism built from three meaningful interactive steps. A student manipulates one
relationship and explains the outcome. The workbench carries the learning; controls remain calm.

## Implementation decision

The user authorized implementation on 18 November 2026 after image generation was blocked by an
unavailable API key. The working direction is the focused interactive lesson: canvas first, compact
conversation controls, quiet course navigation and a coherent system-font visual language.

The React client lives in `web/`. Browser tests cover desktop, tablet and phone viewport layouts;
actual tablet hardware and provider-backed voice remain separate validation tasks. Mockup prompts
are retained as design context. No generated image is being presented as an implemented feature.
