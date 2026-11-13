# ScreenTutor: landscape, learning science, and what to build next

Checked: 2026-11-13. A product and research note, not an efficacy claim. Nothing
here shows that ScreenTutor improves learning; that needs its own controlled
evaluation (see [How to find out whether it works](#how-to-find-out-whether-it-works)).

Where a claim rests only on vendor material or a secondary blog, it is marked
*(vendor)* or *(secondary)*. The AI-tutoring trials summarised here partly reuse
LecturePilot's checked note
[`docs/research/2026-09-06-ai-tutoring-controlled-studies.md`](https://github.com/SebastianBoehler/lecture-pilot/blob/main/docs/research/2026-09-06-ai-tutoring-controlled-studies.md).

## Summary

- **No product in this survey combines all of ScreenTutor's ingredients.** These are:
  - a voice tutor with a teaching policy
  - continuous understanding of handwritten paper under a desk camera, with proactive, step-level feedback
  - drawing on the learner's own screen
  - a video it can drive (pause, replay, loop)
  - opt-in computer control
  - a shared group room

  General assistants (ChatGPT, Gemini, Copilot, Claude) have the vision and voice but no tutoring loop on paper. Tutors (Khanmigo, the study modes, Jane Street's skill) have the pedagogy but live in a chat window. Camera homework apps mostly hand out answers.
- **Assistance is not learning.** Practice performance with AI help can rise sharply while unaided exam performance falls (Bastani et al., PNAS 2025). In a 2026 university RCT, giving students a course-integrated AI tutor lowered final grades by 0.37 SD (Liu et al., 2026). Well-designed, scoped tutors did better: Kestin et al. 2025 and the LearnLM/Eedi 2025 trial.

  So the design target is independent performance later, not task completion now.
- **The strongest, most replicated levers from learning science are not features most AI tutors ship:**
  - retrieval practice
  - spacing
  - interleaving
  - self-explanation
  - faded worked examples
  - pretesting before instruction
  - elaborated but not answer-giving feedback
  - signalling and segmenting in multimedia

  ScreenTutor's new overlay and video player map directly onto signalling and segmenting, and its desk observer onto step-level feedback. The biggest gap is anything that spans sessions: a learner model, spaced review, and delayed unaided checks.
- **Proactive help on paper looks acceptable and useful, but its learning advantage isn't proven.** In a 2026 randomized study of a phone-camera calculus tutor, proactive messages were rated supportive (5.5/7) rather than intrusive (2.5/7). They doubled error identification, but post-test differences between conditions were not significant (Kotalwar et al., 2026).

## 1. Competitive landscape

| Product | Kind | Sees | Voice | Draws on your screen | Acts on the computer | Teaching stance | Group | Open / price |
|---|---|---|---|---|---|---|---|---|
| **ScreenTutor** (this repo) | Mac menu-bar tutor | Desk camera continuously (change-gated), any window or display on request | Full-duplex (OpenAI Realtime) | Yes: box, circle, underline, arrow, spotlight and notes, placed via on-device OCR and a fast vision model | Opt-in: clicks, typing, a background agent; opens apps, URLs and documents | LecturePilot policy: attempt first, least support, faded steps, honest outcomes | Browser study room, peer-to-peer video, one tutor | Open source, BYO keys |
| [Clicky](https://github.com/farzaa/clicky) (Farza) | Mac cursor buddy | Screen | Yes | Animated cursor flies to coordinates the model returns | No | General helper, not a tutoring policy | No | MIT; new work private |
| ChatGPT voice + Study Mode | General assistant with a study mode | Camera and screen share on mobile; files | Yes | No | Agent / Atlas browser | Socratic study mode *(secondary: its menu placement changed in 2026)* | No | Paid tiers |
| Gemini Live + Guided Learning | General assistant with a learning mode | Camera and screen share on Android, in Chrome | Yes | No | Browser agent features | Guided Learning (Aug 2025), built on LearnLM | No | Paid tiers |
| Claude (Learning mode) | General assistant with a learning mode | Files, images; Claude for Chrome | Yes (beta) | No | Claude for Chrome (browser) | Learning mode, aimed at higher education | No | Paid tiers |
| [Microsoft Copilot Vision](https://support.microsoft.com/en-us/Microsoft-Copilot/using-copilot-vision-with-microsoft-copilot) | OS assistant | A shared app window or the whole desktop (Windows and Mac) | Yes | **Highlights** show where to click | Explicitly does not click, type or scroll | Task help, not tutoring | No | Free with Copilot |
| Codex computer use | Coding and automation agent | Screen and accessibility tree | No | Own cursor | Yes: background apps on the Mac (closed helper) | None (not a tutor) | No | Codex CLI is open source; computer-use helper is closed |
| [Khanmigo](https://www.edtechinnovationhub.com/news/khan-academy-brings-gemini-powered-visual-tutoring-into-classrooms-for-2026) | K–12 tutor on Khan content | Its own exercises; interactive visuals (Gemini, 2026) | Some | Inside its own canvas | No | Socratic hints, no answers | Classroom tools | About $4/month *(secondary)* |
| [Jane Street `socratic-tutor`](https://github.com/janestreet/agent_skills/tree/main/socratic-tutor) | Agent skill (Markdown) | Whatever the host model sees | Host-dependent | No | No | Strictest: diagnostic, skill map 0–5, two independent checks per level, unannounced spaced review, teach-back for level 5, no flattery | No | MIT, about 8k stars (Nov 2026) |
| Paper-camera tutors (Knowable, alai, Chiron) *(vendor)* | iPad/phone apps | Handwriting via camera or Pencil | Some | In-app | No | Check each step, question the first wrong one | No | Freemium |
| Photomath / Gauth | Camera solvers | Photo of a problem | No | No | No | Shows full solutions (answer-first) | No | Freemium |
| Cluely, Highlight-style overlays | Screen-aware assistants | Screen and audio | Some | Panels | Some | None; Cluely markets itself for interviews and meetings | No | Paid |
| Kotalwar et al. 2026 ([arXiv:2610.26411](https://arxiv.org/abs/2610.26411)) | Research platform | Live phone camera of handwritten maths | No (text) | No | No | Reactive vs proactive conditions | No | Released platform, prompts and 256k images |
| Own siblings: [LecturePilot](https://github.com/SebastianBoehler/lecture-pilot), [ChalkPilot](https://github.com/SebastianBoehler/chalk-pilot) | Course workspace; whiteboard plus room camera | Course sources; a physical board | ChalkPilot: voice | Teaching canvas on a separate display | No | Source-grounded checkpoints, exam readiness, learner memory | No | Apache-2.0 |

**Where ScreenTutor is differentiated**
- the tutoring loop on physical paper
- marks drawn directly over any app instead of in a chat window
- video the tutor can drive
- the same pedagogy solo and in a group room

**Where others are ahead:**
- **Jane Street's skill:** cross-session mastery tracking and strict evaluation.
- **LecturePilot, Khanmigo:** grounding in a course's own material.
- **Microsoft, Google, OpenAI:** distribution, mobile camera use, and polish.
- **Codex:** reliability of computer use, through accessibility actions and a non-sandboxed helper.

## 2. What the AI-tutoring trials say

| Study | Design | Result | Lesson for ScreenTutor |
|---|---|---|---|
| Bastani et al., *PNAS* 2025 ([paper](https://hamsabastani.github.io/education_llm.pdf)) | About 1,000 Turkish high-school students, GPT-4 "Base" vs "Tutor" vs control | Practice +48% (Base) and +127% (Tutor). Unaided exam: −17% for Base; Tutor no different from control | Guardrails prevent harm but do not by themselves produce gains. Measure unaided performance. |
| Kestin et al., *Sci. Rep.* 2025 ([doi](https://doi.org/10.1038/s41598-025-97652-6)) | 194 Harvard physics students, crossover vs in-class active learning | More learning in less time; higher engagement | It worked with instructor-authored, content-rich prompts and pre-vetted solutions. Ground the tutor in course material. |
| LearnLM / Eedi 2025 ([arXiv:2512.23633](https://arxiv.org/abs/2512.23633)) | 165 UK secondary students; experts supervised LearnLM's drafts | 76.4% of drafts approved with minimal edits. Novel problems: 66.2% vs 60.7% for human-only tutoring | A pedagogy-tuned model can match supervised human tutoring on transfer. |
| Liu et al., EdWorkingPaper 26-1598, Oct 2026 ([paper](https://edworkingpapers.com/ai26-1598)) | 2,379 undergraduates, 30 instructors, access randomized by section | Final grades −0.37 SD; LMS participation −0.90 SD; larger losses for first-generation students | Displacement: an always-available tutor can replace existing practice. Point learners back to course work and do not substitute for it. |
| Tutor CoPilot, Wang et al. 2024 ([arXiv:2410.03017](https://arxiv.org/html/2410.03017v2)) | About 900 human tutors, 1,800 K–12 students | +4 pp exit-ticket mastery; +9 pp for lower-rated tutors | AI helping a human teacher is a strong pattern, relevant to the group room's tutor-as-moderator role. |
| Kotalwar et al., Oct 2026 ([arXiv:2610.26411](https://arxiv.org/abs/2610.26411)) | 117 adults, related-rates calculus; text-reactive vs visual-reactive vs visual-proactive | Gains from pre to post (3.34 → 4.60 of 9) but no significant differences between conditions. Proactive: 41% of messages identified errors (vs 20–22%); rated supportive 5.5/7 and intrusive 2.5/7 | Proactivity changes *what* the tutor says (more error repair). Its design guidance matches ScreenTutor's observer (details in §3). |

Synthesis: purpose-built, scoped, grounded tutoring can help. Unconstrained access and substitution can hurt. Nothing here validates ScreenTutor itself.

## 3. Learning-science findings and what they mean here

Status: ✅ has it · ◐ partly · ✗ missing.

| Finding | Key evidence | Design implication | Status |
|---|---|---|---|
| **Retrieval practice:** recalling beats re-reading | Roediger & Karpicke 2006; Adesope et al. 2017 meta (g ≈ 0.61); Dunlosky et al. 2013 rate it "high utility" | Open sessions with recall questions answered on paper; close with "write what you learned" from memory | ✗ |
| **Spacing:** distributed beats massed practice | Cepeda et al. 2006 meta; Dunlosky et al. 2013 | Review queue across sessions (≈1, 3, 7, 21 days), tied to tasks the learner did | ✗ |
| **Interleaving:** mix problem types | Rohrer & Taylor 2007; Brunmair & Richter 2019 meta (g ≈ 0.42, strongest in maths) | Transfer tasks should mix earlier skills, not repeat the last one | ◐ (`assign_task` exists; no mixing) |
| **Worked examples, then fading;** expertise reversal | Renkl & Atkinson 2003; Kalyuga et al. 2003 | The scaffold ladder (prompt → cue → faded example → worked step) and removing help as competence grows | ✅ in policy; no learner model to decide when to fade |
| **Self-explanation** | Chi et al. 1989/1994; Bisra et al. 2018 meta (g ≈ 0.55) | Ask "why does this line follow?" on paper; the observer can check written explanations | ◐ |
| **Pretesting and productive failure** | Richland, Kornell & Kao 2009; Kapur 2008; Sinha & Kapur 2021 meta | Before a video or explanation, ask a prediction question first, then reveal | ◐ (policy asks for an attempt; the video flow does not) |
| **Feedback:** elaborated, task-focused, sometimes delayed; about a third of feedback interventions hurt | Kluger & DeNisi 1996; Hattie & Timperley 2007; Shute 2008; Wisniewski et al. 2020 meta (d ≈ 0.48) | Point to where the error is, not to the self ("great try"). Hold minor slips until the learner has moved on. | ✅ (observer waits until the learner has "moved past"); add anti-flattery rule |
| **Step-level tutoring rivals human tutors** | VanLehn 2011: human ≈ 0.79, step-based ≈ 0.76, answer-based ≈ 0.31 | Check each written step, not only the final answer. This is the desk observer's core value. | ✅ |
| **Mastery learning** | Bloom 1984; Kulik et al. 1990 meta | Raise a level only on independent evidence (Jane Street: two checks, one unprompted) | ◐ (honest outcomes per task; no skill map) |
| **Metacognition:** fluency illusions; delayed judgements are more accurate | Bjork, Dunlosky & Kornell 2013; Soderstrom & Bjork 2015 | Ask "how sure are you, 1–5?" before checking; show calibration over time | ✗ |
| **Multimedia signalling** | Mayer 2021 (signalling, spatial and temporal contiguity) | Marks appear as the tutor names them, next to the target, never covering it | ✅ new overlay; ◐ timing is per mark, not synced to speech |
| **Segmenting;** interpolated tests in video | Mayer 2021; Szpunar, Khan & Schacter 2013 (fewer lapses, better final recall) | Pause at chapter ends for a recall question; avoid long passive watching | ◐ (the player can do it; no protocol) |
| **Redundancy:** don't read on-screen text aloud | Mayer 2021 | Speak briefly about the board, don't recite it | ✅ in prompt |
| **ICAP:** interactive > constructive > active > passive | Chi & Wylie 2014 | Prefer generating (writing, predicting, explaining) over watching or listening | ◐ |
| **Peer instruction** | Crouch & Mazur 2001 | Group room: each person answers alone, then discusses, then re-answers | ✗ (group rules exist; no structured protocol) |
| **Learning styles matching** has no support | Pashler et al. 2008 | Never ask "visual or verbal learner?" | ✅ explicitly in prompt |
| **Proactive help on paper** | Kotalwar et al. 2026 | Repair first; wait by default (a pause is not being stuck); a quiet period after each message; learner requests take priority; stop once a worked solution has been shown | ◐ (cooldowns and idle checks exist; add "stop after worked solution" and "wait while writing changes") |

## 4. What to build next

Ordered by expected learning value per unit of effort.

### P0: make learning visible across sessions

**Status (2026-11-13): built.** Items 1–5 are in the app:
- **Code:**
  - `ScreenTutor/Learning/` (level rules, spacing, interleaving, scoreboards, persistence)
  - tools `start_topic` / `record_evidence` / `show_progress` / `review_due`
  - `assign_task` kinds (`practice`, `warm_up`, `exit_ticket`)
  - auto-pausing lesson player
- **Tests:** unit tests, plus a live auto-pause test.
- **Not yet done:** testing with real learners. FSRS-style scheduling remains future work.

1. **Learner model and skill map.**
   - **What:** per topic, 4–10 subskills, each at level 0–5 (Jane Street's scale), stored locally.
   - **Raising a level:** only on two independent checks, at least one unprompted recall.
   - **Lowering a level:** after a failed review.
   - **Display:** shown on the Tutor Board on request.
   - **Implementation:** feeds the existing honest task outcomes and LecturePilot-style "assisted vs independent" evidence.
2. **Spaced, interleaved retrieval warm-up.**
   - **When:** session start.
   - **How:** 2–4 questions answered on paper, drawn from due skills and mixed across topics. The desk observer checks the answers.
   - **Scheduling:** a simple expanding schedule first; FSRS-style later.
3. **Two scoreboards.**
   - **Kept separate:** assisted completion vs an **unseen, unaided exit task** at the end of a session, plus an optional delayed check at the next session.
   - **Why:** this is the metric that separates Bastani's Base from Tutor, and it guards against the displacement effect in Liu et al.
4. **Video teaching protocol.**
   - **Before:** a prediction question.
   - **During:** auto-pause at chapter boundaries for one recall question.
   - **After:** a self-explanation on paper.
   - **Mechanism:** `control_video` already supports this; it needs a timeline of planned pauses plus prompt rules.
5. **Diagnostic-first sessions and "just tell me".**
   - **Diagnostic:** 3–5 placement questions when a new topic starts.
   - **Override:** an explicit command, logged as assisted.

### P1: sharper feedback and grounding

6. **Course grounding via LecturePilot.**
   - **What:** import a course's slides and problem sheets, ground explanations in them, and draw tasks from them.
   - **Why:** this follows Kestin's and Bastani's success conditions: vetted solutions and common errors per problem.
7. **Observer upgrades from Kotalwar et al.:**
   - wait while the writing is still changing
   - stop proactive notes once a worked solution has been shown
   - focus proactive notes on errors, not next steps
   - an "offer to check" mode
   - a `zoom_desk(region)` crop at full camera resolution for small handwriting
8. **Confidence before checking.** A 1–5 rating before the tutor reveals correctness, and a calibration line on the board over time.
9. **Overlay timing synced to speech.**
   - **Now:** marks appear on a fixed stagger.
   - **Next:** emit marks when the tutor's transcript reaches the phrase that names them (temporal contiguity).
   - **Tracking:** follow scrolled content through accessibility anchors (needs the sandbox off).
10. **Group room protocols.**
    - **Peer instruction:** answer alone on paper → pair discussion → re-answer.
    - **Jigsaw:** each learner explains one part.
    - **Moderation:** the tutor rotates turns (Tutor CoPilot shows the "AI supports the human" pattern works).

### P2: reach and convenience

11. **Writing:** live co-writing in Word or Pages through AppleScript, export to Anki and Notion, and a session summary written by the learner rather than generated.
12. **Evaluation harness:** simulated students (LecturePilot's StudentSim), latency p50/p95, and A/B of proactivity levels.
13. **Privacy:** the default stays OCR on device and zero-retention routing; add a local vision model option for the observer.

### Deliberately not building

- **Answer-first solving** of photographed problems: the camera-solver pattern. Bastani's Base arm shows the risk.
- **An always-on general chatbot** that replaces course work. Liu et al. show the risk; tie sessions to the learner's course and point back to it.
- **Praise-heavy feedback, streaks and badges** as the main motivator. The feedback literature warns against self-focused feedback; keep motivation task-focused.
- **Learning-style personalization.**

## How to find out whether it works

A small study design, reusing LecturePilot's evaluation contract:

1. **Comparator:** the same time-matched study block, with ScreenTutor vs the learner's normal tools. Randomize the order across topics in a crossover design.
2. **Outcome:**
   - **Primary:** an unseen, unaided transfer test, the same day and again after one week.
   - **Secondary:** assisted completion, calibration, and time on task.
3. **Logging:** every hint level used, every proactive message, and whether the learner asked for it. Report failed sessions and latency.
4. **Pre-registration:** register the proactivity comparison (off / gentle / active). Kotalwar et al. estimate about 330 participants for 80% power on the prior-knowledge interaction, so a solo pilot should aim at feasibility, not significance.

## References

- Adesope, O. O., Trevisan, D. A., & Sundararajan, N. (2017). Rethinking the use of tests: A meta-analysis of practice testing. *Review of Educational Research*.
- Bastani, H., et al. (2025). Generative AI without guardrails can harm learning. *PNAS*. [Manuscript](https://hamsabastani.github.io/education_llm.pdf)
- Bisra, K., et al. (2018). Inducing self-explanation: A meta-analysis. *Educational Psychology Review*.
- Bjork, R. A., Dunlosky, J., & Kornell, N. (2013). Self-regulated learning: Beliefs, techniques, and illusions. *Annual Review of Psychology*.
- Bloom, B. S. (1984). The 2 sigma problem. *Educational Researcher*.
- Brunmair, M., & Richter, T. (2019). Similarity matters: A meta-analysis of interleaved learning. *Psychological Bulletin*.
- Cepeda, N. J., et al. (2006). Distributed practice in verbal recall tasks: A review and quantitative synthesis. *Psychological Bulletin*.
- Chi, M. T. H., et al. (1994). Eliciting self-explanations improves understanding. *Cognitive Science*.
- Chi, M. T. H., & Wylie, R. (2014). The ICAP framework. *Educational Psychologist*.
- Crouch, C. H., & Mazur, E. (2001). Peer instruction: Ten years of experience and results. *American Journal of Physics*.
- Dunlosky, J., et al. (2013). Improving students' learning with effective learning techniques. *Psychological Science in the Public Interest*.
- Hattie, J., & Timperley, H. (2007). The power of feedback. *Review of Educational Research*.
- Jane Street (2026). `socratic-tutor` agent skill. [GitHub](https://github.com/janestreet/agent_skills/tree/main/socratic-tutor)
- Kalyuga, S., Ayres, P., Chandler, P., & Sweller, J. (2003). The expertise reversal effect. *Educational Psychologist*.
- Kapur, M. (2008). Productive failure. *Cognition and Instruction*.
- Kestin, G., et al. (2025). AI tutoring outperforms in-class active learning. *Scientific Reports*. [doi:10.1038/s41598-025-97652-6](https://doi.org/10.1038/s41598-025-97652-6)
- Kluger, A. N., & DeNisi, A. (1996). The effects of feedback interventions on performance. *Psychological Bulletin*.
- Kotalwar, N., et al. (2026). Exploring visual access and proactive AI tutoring for handwritten mathematics. [arXiv:2610.26411](https://arxiv.org/abs/2610.26411)
- Kulik, C.-L. C., Kulik, J. A., & Bangert-Drowns, R. L. (1990). Effectiveness of mastery learning programs: A meta-analysis. *Review of Educational Research*.
- LearnLM Team & Eedi (2025). AI tutoring can safely and effectively support students: An exploratory RCT in UK classrooms. [arXiv:2512.23633](https://arxiv.org/abs/2512.23633)
- Liu, J., et al. (2026). The effects of course-integrated AI tutoring on student performance and engagement. EdWorkingPaper 26-1598. [Link](https://edworkingpapers.com/ai26-1598)
- Mayer, R. E. (2021). *Multimedia Learning* (3rd ed.). Cambridge University Press.
- Pashler, H., McDaniel, M., Rohrer, D., & Bjork, R. (2008). Learning styles: Concepts and evidence. *Psychological Science in the Public Interest*.
- Renkl, A., & Atkinson, R. K. (2003). Structuring the transition from example study to problem solving. *Educational Psychologist*.
- Richland, L. E., Kornell, N., & Kao, L. S. (2009). The pretesting effect. *Journal of Experimental Psychology: Applied*.
- Roediger, H. L., & Karpicke, J. D. (2006). Test-enhanced learning. *Psychological Science*.
- Rohrer, D., & Taylor, K. (2007). The shuffling of mathematics problems improves learning. *Instructional Science*.
- Shute, V. J. (2008). Focus on formative feedback. *Review of Educational Research*.
- Sinha, T., & Kapur, M. (2021). When problem solving followed by instruction works. *Review of Educational Research*.
- Soderstrom, N. C., & Bjork, R. A. (2015). Learning versus performance. *Perspectives on Psychological Science*.
- Szpunar, K. K., Khan, N. Y., & Schacter, D. L. (2013). Interpolated memory tests reduce mind wandering and improve learning of online lectures. *PNAS*.
- VanLehn, K. (2011). The relative effectiveness of human tutoring, intelligent tutoring systems, and other tutoring systems. *Educational Psychologist*.
- Wang, R. E., et al. (2024). Tutor CoPilot. [arXiv:2410.03017](https://arxiv.org/html/2410.03017v2)
- Wisniewski, B., Zierer, K., & Hattie, J. (2020). The power of feedback revisited. *Frontiers in Psychology*.

Product sources:
- [Copilot Vision support page](https://support.microsoft.com/en-us/Microsoft-Copilot/using-copilot-vision-with-microsoft-copilot)
- [Khanmigo and Gemini (EdTech Innovation Hub)](https://www.edtechinnovationhub.com/news/khan-academy-brings-gemini-powered-visual-tutoring-into-classrooms-for-2026)
- [Clicky](https://github.com/farzaa/clicky)
- [Codex computer use, MacRumors](https://www.macrumors.com/2026/05/22/codex-use-mac-apps-when-locked/)
- [Codex helper issue](https://github.com/openai/codex/issues/21846)
- [Study modes compared (secondary)](https://glasp.co/articles/ai-study-modes-compared)
- [Paper-camera tutor apps (vendor comparison)](https://tryalai.app/compare/handwriting-tutor-apps)
