# Daily study workspace

The main product is a native learning client: live voice alongside a conversation and an organized
canvas of rich learning artifacts. Native Mac controls and live overlays remain optional tools.

## First usable workflow

1. Create a course and import local PDFs, Markdown or text. Persist imported files and a local
   full-text index. Report unsupported and unreadable files explicitly; never seed example courses.
2. Select the course and start voice. The tutor receives the course inventory and searches local
   material through a tool. Search results carry material/page references. Do not claim all
   materials have been read or invent source citations.
3. Talk or type while showing paper through the existing desk camera. Establish a concrete goal,
   diagnose prerequisites, then use the least help needed and verify independent recall.
4. Generate rich artifacts in the conversation and on the canvas. Each has an ID, title, content,
   and section; Markdown supports math, diagrams, tables and code. Updating an ID updates the
   existing artifact. The tutor can organize sections and focus one artifact. No infinite-canvas
   navigation, arbitrary executable model code, or fixed catalogue of visual templates.
5. Practice or request a mock exam based on the selected course. Exam questions appear as a
   persistent artifact; withhold solutions during the attempt, then review and record evidence.
6. Preserve the course workspace and artifacts across restarts. Let learners revisit and copy
   artifacts and see sources. Show real empty, loading and error states.

## Interface

Use native macOS navigation, controls and keyboard shortcuts. A course/sidebar area anchors the
workspace; conversation and canvas share the main window. Keep voice/camera controls stable.
Provide a focused artifact view and an organized overview. The empty state asks the learner to
import real material or start a goal; it does not contain mock learning content.

## Public project quality

New source files stay below 300 lines. Share rendering between inline artifacts and the canvas;
remove superseded duplicate board logic. Avoid unrelated formatting. Keep local data and keys out
of git. CI regenerates the Xcode project and runs build/tests. Explain requirements, local setup,
privacy boundaries, architecture, current limitations and ways to contribute without inflated claims.

## Acceptance

- Course import persists, duplicate imports do not duplicate content, search is course-scoped and
  returns correct page references, and failures remain visible.
- Artifact updates retain identity, organization retains content, and a restart restores artifacts.
- Voice tool schemas and dispatch support course search, artifacts and adaptive tutoring.
- Native service/overlay checks continue to pass; real OS permission failures remain explicit.
- Inspect the running main window, its empty state, import flow, rendered math/diagram and resizing.
- Run the complete test suite and CI-equivalent project generation check.
