# Live voice plus execution agents: a teaching interaction model

Design clarification · 19 November 2026. Assume an honest student who wants to learn.
Companion to the [academic platform brief](2026-11-19-adaptive-learning-platform-design.md).
These are proposed interactions, not shipped features or measured educational effects.

## The opportunity

A live tutor can discuss the student's reasoning while background tools or specialist agents prepare an experiment,
check a source, inspect a derivation or construct a contrasting case. The student's explanation can change what the
system builds; the resulting artifact can then change the next question. Conversation and execution form a shared
investigation instead of alternating between a chatbot answer and a separate exercise.

The goal is not more autonomous work for its own sake. Give the system mechanical preparation and checking;
retain the intellectual decisions that constitute the student's learning objective.

## What is technically supported versus implemented here

- Current OpenAI documentation describes GPT-Live as a full-duplex conversational interface with a separate backend
  for reasoning/tools. Client delegation can connect an application-owned workflow; Responses delegation manages
  a configured backend. The conversation can continue while backend work runs. This supports the architecture,
  not a claim of teaching effectiveness or a measured latency for ScreenTutor. [T1–T2]
- The current web app uses `gpt-realtime-2.1`, not GPT-Live. Its voice tools inspect an activity, request a compiled
  activity and submit an attempt. Inspecting live simulation state is already represented in code. [C1–C2]
- Web activities accept three compiled model families, not arbitrary generated programs. There is no web execution
  sandbox, background specialist-job scheduler or OS bridge. The native Mac computer agent is a separate prototype. [C3–C4]
- Adopting a new voice API would require integration and evaluation; this document does not silently migrate models.

## A minimal division of work

| Component | Responsibility | What it must not take over |
| --- | --- | --- |
| Conversational tutor | Listen, clarify, ask one useful question, connect speech to the canvas | Invent completed computations or speak over thinking |
| Experiment tool/agent | Execute an agreed comparison; return parameters, method, result and limits | Supply the student's hypothesis when generating it is the target skill |
| Source/checking tool/agent | Verify a specific claim against a source or mathematical check | Turn agreement between agents into ground truth |
| Learning policy | Select the next pedagogical action and record the evidence | Treat every utterance or tool success as mastery |

These are roles, not a requirement to launch several LLMs for each turn. Prefer a deterministic tool for calculations
and known simulations; use a model when interpretation or construction needs one. Present one coherent tutor and
one shared canvas rather than several competing agent chat windows.

## Six interaction patterns

### 1. The student's explanation becomes an inspectable model

Student: “Arrivals become faster, so the server also finishes faster.”
Tutor: “Do you mean the server changes its service rate, or that it stays busy more often?”
Canvas: show the two quantities separately; preserve the student's wording until the student confirms its meaning.
Next: ask the student to predict a result, then run the relevant comparison.

**Learning opportunity:** turn ambiguous language into an explicit model that can be tested and revised.
Do not silently repair the claim and then credit the learner with the corrected reasoning.

### 2. The tutor runs a discriminating experiment while the student reasons

Student predicts whether changing variability at a fixed mean changes waiting time.
While the tutor asks what mechanism could cause that change, an execution agent prepares two reproducible runs.
Reveal the comparison after the prediction; ask the student to reconcile the result with the original explanation.

**Learning opportunity:** connect an explanation with consequences. A comparison must distinguish the candidate
models and expose finite-run uncertainty. This variability experiment requires a model extension beyond the current M/M/1 widget.

### 3. The student designs; the agent executes

For a modeling task, the student chooses variables, assumptions, comparisons and stopping criteria.
The agent runs the specified computation and produces the agreed figure. The student interprets and critiques it.
For an implementation-learning task, reverse the boundary: the student writes the algorithm and the agent supplies
test cases or checks. The same automated action can be useful support or removal of the target practice.

**Learning opportunity:** devote effort to the intended competence, rather than tool setup or repeated boilerplate.

### 4. A short, responsive oral examination

Invite the student to explain an idea in their own words, then ask a question contingent on the actual explanation.
Change one assumption, ask for a counterexample, or request a consequence. Allow drawing, equations and pauses.
The background checker compares the relevant reasoning with an explicit rubric and returns uncertainty privately
to the tutor. The tutor chooses the next useful probe rather than reading a checklist aloud.

**Learning opportunity:** distinguish memorized phrasing from flexible reasoning. Paraphrase alone is insufficient.
Assess the subject reasoning, not accent, speaking speed, eloquence or readiness to interrupt.

### 5. The student critiques an argument or paper

The student chooses between two interpretations of a source. A source agent retrieves the exact passages and a
checker identifies which assumptions support each interpretation. The tutor asks what evidence would change
the student's judgment. The student revises the claim or proposes a further analysis.

**Learning opportunity:** develop scholarly judgment, not only answer production. Label a deliberately flawed
argument as a practice artifact; distinguish source text, generated interpretation and observed result.

### 6. A teach-back that produces the next transfer task

After supported learning, the student gives a short explanation without the earlier worked solution in view.
The tutor selects one consequential gap. A task-construction agent proposes a new case that tests that gap;
validate its solution before use. Later, revisit the skill in a different setting with less support.

**Learning opportunity:** turn the student's own explanation into the basis for targeted practice and later checking.
Do not confuse immediate conversational repair with retained independent capability.

## A concrete queue-theory session

1. The learner claims that λ below μ is enough to make waiting negligible.
2. The tutor asks the learner to compare spare capacity in two stable systems, without first displaying the answer.
3. A background job prepares matched runs at λ=4 and λ=4.75 with μ=5, including finite-run observations and theory.
4. The learner explains the prediction while preparation continues. The tutor can clarify a term without giving the result.
5. Reveal both runs. Ask the learner which part of the initial claim needs revision and what short runs cannot establish.
6. Ask a fresh spoken/written application question, then schedule a later check on model choice or assumptions.

The current queue engine can underpin the stable-rate comparison; coordinated background runs and conversational
selection of experiments are proposed additions. Comparing different service distributions is a further model family.

## Support is about content, not medium

| Interaction | Proposed evidence interpretation |
| --- | --- |
| Student speaks an answer; tutor listens and asks neutral clarification | Potential independent evidence for the tested skill |
| Tutor supplies the key reasoning or resolves a conceptual gap | Supported learning; test a fresh application later |
| Agent performs a calculation the task explicitly allows | Record the tool; judge the reasoning the learner was meant to perform |
| Agent writes the algorithm the student was meant to learn to implement | The implementation was assisted, even if the student can explain the output |
| Tutor asks an unannounced leading question that reveals the method | Assistance, not an independent success disguised as dialogue |

Agree when a short check begins. Not every spontaneous remark should become a grade, and productive conversation
must remain a place to make mistakes. “Let me explain that back” should feel like collaboration, not surveillance.
Current web voice submissions are always marked assisted; supporting the finer distinctions above requires a
deliberate change to policy and evidence recording, not merely a different spoken prompt. [C1–C2]

## Coordination needed for a usable experience

- Keep one conversational voice. Background results do not each announce themselves.
- Ask a pedagogically useful question while work runs, or allow silence; do not fill latency with redundant speech.
- Distinguish preparation, a verified result and a result actually presented to the student.
- Link jobs to the current task and artifact revision. Cancel or discard obsolete results after a correction or topic change.
- Keep student work separate from agent-produced changes. Propose updates without overwriting an unfinished response.
- Treat incomplete speech transcripts and ambiguous handwriting as provisional; confirm before acting on their meaning.
- Use execution receipts and real data; a tutor must not narrate a simulation as completed before a result arrives.
- Suppress answer-bearing results during a prediction/check until the appropriate learner action.
- Treat API full duplex as a transport/conversation capability, not permission to interrupt concentration continually.

OpenAI's delegation/control documentation supports concurrent work and application-owned task state. Handling
stale work, turn ownership and presentation timing remains application work. [T2–T3]

## Research grounding and validation

Self-explanation, feedback use and appropriate representations motivate these proposals; see P3–P5 in the
[learning-science audit](2026-11-19-learning-science-evidence.md). Those studies did not validate this exact voice-agent system.
The [AI audit](2026-11-19-ai-tutoring-evidence.md) also separates proactive interaction from demonstrated learning gains.

Test one pattern against the same content/time with a simpler interaction. Measure later independent reasoning
and transfer, plus interruptions, workload, correction errors, abandoned tasks and time cost. Keep speaking fluency
separate from subject competence. A richer dialogue or more completed agent jobs is not itself a learning outcome.

## Sources and inspected implementation

- **T1 — Official capability:** [OpenAI voice agents: full duplex](https://developers.openai.com/api/docs/guides/voice-agents#build-a-full-duplex-voice-agent).
  Fetched 19 November 2026. Technical capability documentation, not educational-outcome evidence.
- **T2 — Official execution model:** [GPT-Live delegation and tools](https://developers.openai.com/api/docs/guides/live-delegation).
  Inspected delegation modes, application ownership, parallel tools and continuation semantics.
- **T3 — Official coordination:** [Server-side controls](https://developers.openai.com/api/docs/guides/voice-server-controls).
  Inspected sideband ownership and concurrent-work/stale-result guidance.
- **C1 — Current voice session:** [web/server/voice.ts](../../web/server/voice.ts), model, tools and conservative assistance policy.
- **C2 — Current dispatch:** [web/src/services/useLearning.ts](../../web/src/services/useLearning.ts), voice attempt callback;
  [voice.ts](../../web/src/services/voice.ts), tool dispatch and reconnection-generation checks.
- **C3 — Current compiled models:** [interactive/schema.ts](../../web/src/interactive/schema.ts), three bounded model families.
- **C4 — Separate native executor:** [ComputerAgent.swift](../../ScreenTutor/Computer/ComputerAgent.swift).
