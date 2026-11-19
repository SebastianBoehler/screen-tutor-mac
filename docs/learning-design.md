# Learning design and evidence contract

ScreenTutor is a general learning client. Its current policy is research-informed; its own effects
on student learning have not been evaluated. Product behavior tests are not learning-outcome studies.

## Principles and implementation

| Principle | Design behavior | Practical limit |
| --- | --- | --- |
| Retrieval practice | Attempt or predict before revealing an answer | Generated questions and grading can be wrong |
| Spacing | Expanding review dates after assessed attempts | Heuristic intervals, not a fitted memory model |
| Scaffold fading | Cue → partial example → one worked step → new unaided task | Model instructions require behavioral evaluation |
| Self-explanation | Ask for reasoning and connect to observed prior knowledge | Fluent explanations do not establish retention |
| Task-focused feedback | Identify the reasoning gap, then return the next step | Feedback quality depends on sources and the model |
| Self-regulation | Concrete goals, visible evidence and a manageable review budget | Rest windows are user preferences, not sleep measurement |
| Multimedia coherence | One concept per activity, nearby labels and restrained visuals | Correct diagrams require content review |
| Adaptive support | Course-scoped, editable hypotheses linked to actual attempts | No fixed learning styles or intelligence labels |

Core references:

- Roediger & Karpicke (2006), retrieval practice: https://doi.org/10.1111/j.1467-9280.2006.01693.x
- Cepeda et al. (2006), distributed practice review: https://doi.org/10.1037/0033-2909.132.3.354
- Dunlosky et al. (2013), learning-technique review: https://doi.org/10.1177/1529100612453266
- Renkl & Atkinson (2003), fading worked examples: https://doi.org/10.1207/S15326985EP3801_3
- Chi et al. (1994), self-explanation: https://doi.org/10.1207/s15516709cog1803_3
- Shute (2008), formative feedback review: https://doi.org/10.3102/0034654307313795
- Pashler et al. (2008), learning-style evidence: https://doi.org/10.1111/j.1539-6053.2009.01038.x
- Mayer (2021), *Multimedia Learning*, third edition, Cambridge University Press.

These sources motivate design choices; they do not validate this specific implementation or imply
one teaching policy works equally well in every subject. The earlier [research landscape](research/2026-11-13-landscape-and-learning-science.md)
contains additional product context and should be refreshed before making time-sensitive claims.

## Evidence rules

- An attempt, hint, reveal, interactive exploration and provider assessment remain distinguishable.
- Only an assessed correct attempt without recorded help can count as an independent check.
- Repeating the same activity on the same day cannot lengthen its review interval repeatedly.
- Manipulating a model records assisted exploration. A new unaided transfer question is needed to assess independent understanding.
- Revealing an answer or requesting help does not award mastery. Voice-supported attempts are
  conservatively assisted because the app cannot reliably infer how much the voice tutor helped.
- The current dashboard counts concepts with successful independent checks. It does not label
  them mastered or predict exam grades. Model assessments remain provisional evidence.
- Practice-exam attempts remain ungraded during the attempt. An explicit Review exam action ends that phase. Asking for help changes assistance
  status. Exam answer withholding partly depends on model compliance and needs adversarial testing.
- Learner notes retain their provenance. A generated interpretation is not an official source.
- Memory is an inspectable teaching hypothesis with an actual attempt reference, not a diagnosis.
- Engagement should come from useful feedback and visible progress. No punitive streaks,
  leaderboards, inflated mastery percentages or rewards for merely opening content.

## Validation before efficacy claims

First establish feasibility: source fidelity, correct worked examples, understandable feedback,
voice interruption, accessible touch controls, data retention and recovery from provider failures.
Record failures, hints, reveals and request-to-usable-activity time, not just successful sessions.

For learning outcomes, compare time-matched topics against the student’s usual study method.
Use unseen unaided questions immediately and after a delay; keep assisted completion separate.
A small personal pilot can inform usability and feasibility. It cannot establish general efficacy.

## Future tablet notes

The browser model separates source documents, editable lecture notes, activities and learning
history. Future pen capture should add editable strokes and legible transcription with timestamps
and source provenance. It should not change the evidence rules or silently send a live camera feed.
Remote agents and account sync need an explicit authentication, credential and data-isolation design.
Neither capability ships in the current local client.
