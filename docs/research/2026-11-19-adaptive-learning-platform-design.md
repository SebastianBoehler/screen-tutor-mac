# An evidence-based adaptive learning platform for advanced university study

Research/design brief · 19 November 2026 · application snapshot: `e2c6a91`.

## Recommendation and scope

Build a system that helps a learner develop and demonstrate a specified capability, then checks whether it lasts
and transfers. The central product is the learner's evolving evidence of competence, supported by a teaching canvas.
The AI conversation is one way to guide that process, not the measure of success.

The intended user includes a Master's student with uneven prerequisites across topics. Start from demonstrated
knowledge, not degree title, perceived intelligence, learning-style labels or the fluency of one chat answer.
The architecture can span subjects; the competencies, tasks, reference solutions and validators must remain
domain-specific. A proof, a statistical model critique and a laboratory procedure require different evidence.

**Status:** research-informed proposal. It is not implemented by this document or validated as a complete system.
**Promise to test:** better independent, delayed performance on meaningful tasks for the supported learner population.
“Everyone can master any topic” is a mission aspiration, not a justified efficacy claim or a certification standard.
Assume an honest student seeking to learn. Assessment is formative; preventing outside assistance is not the product goal.
For the live voice/execution design, see [voice and agent interaction patterns](2026-11-19-voice-and-agent-teaching-patterns.md).

Sources: [learning/neuroscience/assessment audit](2026-11-19-learning-science-evidence.md) and
[recent AI-tutoring/ML audit](2026-11-19-ai-tutoring-evidence.md). Source IDs P/N/M refer to the first audit.
Design decisions below are reasoned proposals; studies did not test this exact combination or ScreenTutor.

## 1. What learning requires

Encoding connects attended material with existing representations. Practice changes the accessibility and organization
of knowledge; repeated exposure, correct recognition, coherent explanation and independent application are different
events. Biological plasticity includes changes in connection strengths and connectivity. Consolidation unfolds over
time, including sleep. None of those mechanisms supplies a browser-readable measure of understanding. [N1–N2]

Use behavioral learning research to choose instructional tasks, and neuroscience to constrain implausible claims.
Do not infer dopamine, brain state, neurodivergence or intelligence from response latency, gaze or chat style.
Do not market a universal study-block length, “rewiring score,” or brain-based mastery guarantee.
Rest and accessibility options should help students participate; they are not medical interventions.

## 2. Define the capability before choosing the artifact

Every unit needs a short, source-backed learning contract:

| Field | Example: Modellierung und Simulation |
| --- | --- |
| Target capability | Choose, analyze and critically assess a single-server queue model |
| Prerequisites | Rate units; conditional reasoning; probability distributions; long-run averages |
| Conditions | Named allowed references/tools; one server; specified arrival/service assumptions |
| Success criteria | Correct model choice, calculation, justification, limitations and uncertainty |
| Evidence task | Unseen scenario requiring a model decision and explanation, not formula reproduction alone |
| Scope of inference | This queue-model family and tested contexts; not “all simulation mastered” |

At Master's level, include derivation, comparison of methods, counterexamples, evaluating evidence, identifying
limitations and designing a defensible analysis. Difficulty is not just larger numbers or longer text. [M1–M2]

For another domain, replace the contract rather than merely changing vocabulary: a history task needs evidence
evaluation; a programming task needs specification-sensitive behavior and reasoning; a practical skill may need
observation by a qualified person. The platform must say when its digital evidence is insufficient.

## 3. Diagnose the smallest relevant gap

1. Ask what the student wants to be able to do and when that capability is needed.
2. Present a small authentic task or a few prerequisite probes; allow “I have not learned this.”
3. Inspect the response for evidence of specific knowledge and misconceptions, including alternative valid methods.
4. When an error has several plausible causes, ask a discriminating follow-up before assigning remediation.
5. Show the working interpretation and let the learner correct it: “The rate calculation looks sound;
   I need another example to tell whether the model assumptions are clear.”

Treat a short diagnostic as uncertain evidence, not complete placement. Its length should depend on decision
stakes and remaining uncertainty; “three questions” is a prototype choice, not a scientific universal.
Recheck the interpretation through later tasks. Maintain unknown separately from incorrect.
Do not require repeated basic exercises when an advanced authentic task already supplies stronger evidence.

## 4. Choose the next learning interaction

| Observed evidence | Proposed next action | What must remain distinguishable |
| --- | --- | --- |
| Prerequisite missing | Teach a focused prerequisite with a worked example, then a small application | Instruction versus a diagnostic score |
| Partial understanding | Ask for a prediction, comparison or explanation of the consequential step | Plausible language versus valid reasoning |
| Specific misconception | Contrast a correct and near-miss case; ask the learner to revise | Error repair versus exposure to the answer |
| Ready for generation | Have the learner derive, model, code, explain or critique | Learner work versus generated work |
| Correct with help | Fade support and give a genuinely new independent task | Assisted success versus independent evidence |
| Correct independently now | Schedule a later check and change context or problem structure | Immediate success versus retention/transfer |
| Tired, blocked or access barrier | Offer a pause, a different response medium or human help | Participation conditions versus subject knowledge |

Retrieval, spacing and interleaving belong alongside conceptual explanation and generative application. [P1–P3]
Use a brief attempted solution before instruction when it productively exposes a gap; give explicit teaching when
necessary. Productive struggle is not an instruction to withhold help indefinitely. [P7]
Feedback should identify the consequential gap and elicit a revision; it need not reveal the whole answer. [P4]

## 5. The canvas interaction

The main view should make four things legible: **goal, current task, learner work, next action**.
Use one focal artifact, with relevant assumptions and labels beside the object they explain. Select a table,
diagram, equation, simulation, source passage or code task because it serves the capability. [P5]

- Keep compact previews and expand-in-place for complex models, while keeping the question and learner work reachable.
- Put essential model limits in concise visible text. An expand action should reveal a working surface, not hide
  assumptions that determine whether an answer is valid.
- Keep voice/chat supplemental. Point feedback to the student's equation, claim or diagram region.
- Stop animations and narration when the learner needs to think; allow replay, pause and persistent work.
- Preserve the attempt before showing feedback. Put the feedback next to the relevant work and support revision.
- Use a clear primary action: predict, compare, test, revise or submit. Avoid several competing “next” actions.
- Offer keyboard access, readable formulas, captions, text alternatives and appropriate response media. [M1, M3]
- Give a recommended next task with a short reason and an override. This combines guidance with agency. [P6]

These are design hypotheses to test with students. Minimal appearance and “one artifact” are useful constraints,
not experimentally established universal layouts. Complex authentic work may need multiple coordinated views.

## 6. Ask questions that expose a mental model

Avoid relying on “Do you understand?”, confidence alone, answer recognition or repeatedly asking “Why?” without
a clear target. A question should reveal evidence needed for the next teaching decision.

| Purpose | Example question | Evidence sought |
| --- | --- | --- |
| Prediction | “Keep μ fixed. What happens to average queue length as λ approaches μ, and why?” | Direction and spare-capacity reasoning |
| Explanation | “Why is μ − λ in the denominator important here?” | Causal/mathematical connection |
| Discrimination | “Two services have equal mean rates but different service-time distributions. Can this formula describe both?” | Recognition of assumptions |
| Error diagnosis | “A report uses a finite steady-state mean when λ ≥ μ. What is the first invalid step?” | Boundary awareness |
| Method selection | “Which quantities would you measure before choosing this queue model?” | Conditional knowledge and planning |
| Transfer | “A call center adds a second agent. Which assumptions and analysis must change?” | Structural transfer rather than number substitution |
| Evaluation | “The simulation and formula disagree. How would you distinguish transient behavior from a model error?” | Verification strategy and uncertainty |
| Self-regulation | “What evidence would convince you your explanation is wrong?” | Ability to test one's own knowledge |

Ask one consequential question at a time. Follow up on the actual response rather than delivering a fixed
interrogation script. A self-explanation is useful when it exposes relationships; long fluent prose is not mastery. [P3]

## 7. Separate learning, checking and review

**Explore/learn:** sources, hints, examples, simulation and dialogue are available. Record assistance without stigma.
**Independent check:** present a fresh task, state allowed tools, preserve the response, and withhold substantive
feedback until the response or small assessment block is submitted. Asking for a hint converts it to practice.
**Review:** return after a meaningful delay, vary the task, and probe method selection and transfer.

Independent means the learner performs the target reasoning under the stated conditions. It need not mean
“no references ever”: authentic research tasks may allow papers, code and formula sheets. Accessibility tools
are not automatically content assistance. Name and record these distinctions. [M1–M2]
Use explanation, spontaneous follow-up, prediction and subsequent application to probe understanding.
Keep assessment low-pressure and transparent. Speech is a response medium; whether the tutor supplied the
target reasoning determines assistance. Honest self-study does not require surveillance or proctoring.

### Proposed evidence states

| Learner-facing state | Required evidence | Still unknown |
| --- | --- | --- |
| Not checked yet | No suitable independent observation | Current competence |
| Practiced with support | Work completed with recorded assistance | Independent performance |
| Demonstrated independently | Valid new task passed under stated conditions | Durability and breadth |
| Retained at last review | Suitable independent success after a delay | Longer-term retention |
| Transfer demonstrated in… | Success in a meaningfully changed context/problem | Transfer outside tested scope |

These states are an operational proposal, not a validated scale. A skill may have mixed evidence rather than one
linear level. Show dates, tested contexts, assistance and uncertainty. Revisit after contradiction or long gaps.
Prefer “Retained on 18 November; transfer to multi-server models not checked” over “95% mastered.”

## 8. Validate mastery at two levels

**Individual claim:** does accumulated evidence support this learner performing this capability under these conditions?
Require coverage of the rubric, meaningfully varied tasks, later evidence and suitable independent scoring.
Repeated copies of the same question do not provide independent coverage. Establish stopping rules through
calibration and the consequences of false passes; no fixed count of correct answers is a universal mastery rule.

**Platform claim:** does this teaching policy cause better independent learning than a credible alternative?
An accurate predictor, satisfied student, polished artifact or passing software test cannot answer this question.
The assessment itself needs evidence of content alignment, response validity, scoring consistency and fairness. [M1]

### Scoring and evidence integrity

- Define a task rubric and validated reference before teaching from or scoring the task.
- Use exact/symbolic checks, test cases or simulation invariants where they genuinely cover the target capability.
- For explanations, proofs, critiques and design, use criterion-level scoring, counterexamples and sampled expert review.
- Let the assessor abstain or request review when the task, source or reasoning cannot be judged reliably.
- Audit false passes and false failures, including concise answers, alternative methods and language variation.
- Keep task family, prior exposure, source/version, assistance, allowed tools, criterion scores and assessor/version
  linked to the original response. Correcting a grade must correct downstream estimates too.
- Isolate unreleased assessment items/solutions from teaching context. Two LLMs agreeing is not independent ground truth.

## 9. Where machine learning belongs

Separate a **content model** (skills, prerequisites, source-backed tasks), **learner model** (evidence and uncertainty),
**teaching policy** (next action), and **assessor** (rubric-based judgment). Keep each inspectable and replaceable.
See the companion AI audit for what current real-learner studies do and do not establish.

Start with transparent evidence rules and a reviewed prerequisite map. Compare simple memory/knowledge-tracing
baselines with more complex models only after collecting appropriate data. A predicted correct response is not a
direct observation of a latent “mastery” trait. AUC alone does not establish calibration or a better teaching policy.
Use learner-separated, time-aware evaluation and hold out task families/topics when claiming cross-topic transfer.

Candidate ML jobs: propose diagnostic tasks, identify possible misconceptions, estimate later recall, rank next tasks,
and detect uncertain assessments for human review. Constrain these decisions with sources, task validity and learner
agency. Do not let a tutor's own praise or self-reported confidence raise the learner's evidence state.
The optimization target should include later independent capability and time cost, not message count or assisted accuracy.

## 10. Broad participation without an untestable universal promise

“Meets you where you are” requires prerequisite repair, useful pacing, understandable language, low-bandwidth options,
accessible interaction and routes to human help. It also requires testing with students outside the initial successful group.
Offer modality preferences as choices, not fixed cognitive diagnoses. [P8, M1, M3]
Audit learning, attrition, burden, grader errors and access separately across relevant groups and starting levels.
Use consented research data and report uncertainty; tiny subgroup samples do not establish equal effectiveness.
If a learner fails repeatedly, investigate content, method, accessibility and assessment before attributing failure to ability.

## 11. A validation programme

1. **Content/assessment audit:** experts review objectives, prerequisites, item families, references and scoring.
   Check alternative solutions and model/answer leakage before exposing tasks as mastery checks.
2. **Usability/feasibility pilot:** observe representative students using their own course material. Record confusing
   actions, help requests, abandoned tasks and failures. A personal pilot informs design, not general efficacy.
3. **Scoring validation:** blinded expert ratings on held-out authentic responses; report criterion agreement,
   false passes/failures, uncertainty handling and subgroup/access differences.
4. **Controlled learning study:** preregister the population, domain, capability and comparator. Randomize to a
   credible time-matched study condition, preferably without cross-topic contamination. Use blinded scoring and
   unseen assessment items; measure delayed independent performance as the primary outcome.
5. **Retention/transfer:** choose delays relevant to the course (for example one week and a later course-relevant check),
   distinguish practiced structures from structural transfer, and record other study exposures.
6. **Analysis:** power the study for the smallest worthwhile effect and attrition; report intention-to-treat effects,
   uncertainty, time burden, harms/displacement and non-completion. Platform-selected easy tests must not be the
   only outcome. A within-student topic crossover can pilot feasibility but risks carryover and topic confounding.
7. **Policy comparison:** after validity is credible, compare diagnostic/adaptive choices and scaffold fading against
   simpler policies. Offline predictive accuracy and simulated-student gains are preliminary, not educational efficacy.

## 12. What this means for the current repository

The existing app has useful foundations: one focal activity, sources, retained learner work, explicit help/reveal events,
compiled interactive models, assisted examples and a review queue. Inspection in this research turn found:

| Current implementation | Limit for the proposed claim | Next research-driven requirement |
| --- | --- | --- |
| `web/src/domain/progress.ts` counts correct unassisted attempts | A provisional activity-level check, not a validated competence estimate | Cross-task skill evidence, retained/transfer distinctions and scoring audit |
| Same file schedules 1/3/7/14/30-day reviews | Transparent heuristic, not a fitted memory model | Validate retention predictions against simpler baselines |
| `web/src/domain/retrieval.ts` retrieves keyword-ranked chunks | Relevant text is not verified truth or a complete curriculum | Reviewed capability/prerequisite/task map with source versions |
| `web/src/domain/applyReply.ts` applies model verdicts | Schema validity does not validate grading | Criterion rubrics, abstention and independent scoring evidence |
| `web/src/domain/canvasExamples.ts` saves assisted, ungraded work | Suitable for exploration, intentionally not mastery evidence | A separate unseen check after exploration |

The immediate priority is a small, well-specified course slice with validated tasks and a genuine delayed check,
before adding more visual types or a more complicated learner model. Keep the current offline examples clearly
illustrative. Research preparation does not change the app or upgrade its learning claims.
