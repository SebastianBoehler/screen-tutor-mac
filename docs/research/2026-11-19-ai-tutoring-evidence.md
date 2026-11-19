# ScreenTutor: AI tutoring, independent mastery, and inclusive learning

Search and verification date: **19 November 2026**. Research only; no ScreenTutor efficacy claim.
Working assumption: optimize what learners can do independently later, while preserving access to useful help.
Success check: distinguish assistance, immediate tests, delayed retention, transfer, and simulated learners in every claim.

## Scope and reading key

Twelve selected primary studies follow, plus the requested IZA synthesis and Simons talk check.
Live searches covered the six previously cited studies, adaptive sequencing, knowledge tracing, assessment,
spacing neuroscience, and newly published learner experiments. This is a selective evidence audit, not a systematic review.
Primary full texts and relevant methods/results were inspected; search snippets served only to locate sources.
**Supported** means the cited passage supports the narrow claim; **partially supported** requires qualification;
**contradicted** means the broader proposed interpretation conflicts with the evidence; **unverified** means insufficient access/evidence.
SD means standard deviation; pp means percentage points. Neither is interchangeable with percent improvement.
Publication status below describes the inspected record, not a guarantee that no other version exists.

**Decision:** preserve separate records for assisted success and independent evidence. Test adaptive sequencing,
but treat automated mastery estimates and proactive camera feedback as hypotheses requiring learner validation.
The positive studies do not establish that unrestricted chat, more interruptions, or a larger model improves durable learning.

## Selected primary studies

### 1. Bastani et al. — guardrails and the assistance–learning gap

- **Identity/status:** *Generative AI without guardrails can harm learning: Evidence from high school mathematics*.
  PNAS, published 25 June 2025; [DOI 10.1073/pnas.2422633122](https://doi.org/10.1073/pnas.2422633122).
  [Open full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC12232635/), version of record; peer reviewed.
- **Population/design:** nearly 1,000 Turkish high-school students, grades 9–11; classroom-randomized arms;
  four 90-minute sessions. GPT Base versus teacher-informed GPT Tutor versus notes/textbook control.
- **Timing/assistance:** assisted practice, followed within each session by a closed-book, closed-laptop exam;
  exam problems were conceptually similar to practice. This is immediate independent performance, not delayed retention.
- **Finding:** practice scores rose 48% and 127% relative to control. Base reduced exam score by 0.054/1
  (17% relative); Tutor's exam coefficient was −0.004, with no demonstrated improvement over control.
- **Limits:** one school; teacher-designed tasks; guardrails bundled hints, solutions, and common-error knowledge.
  The trial does not isolate which safeguard mattered or establish broad transfer.
- **Locator/support:** Experimental Design; Main Results, Table 1. **Supported** for assistance–exam divergence;
  “GPT Tutor improves independent scores over no-AI control” remains **unverified**, rather than established by a null result.

### 2. Kestin et al. — structured physics lessons

- **Identity/status:** *AI tutoring outperforms in-class active learning: an RCT introducing a novel research-based
  design in an authentic educational setting*. Scientific Reports, 3 June 2025; peer reviewed.
  [DOI/full text 10.1038/s41598-025-97652-6](https://doi.org/10.1038/s41598-025-97652-6), version of record inspected.
- **Population/design:** 194 eligible Harvard physics students; two lessons in consecutive weeks, crossover;
  custom GPT-4 tutor at home versus established classroom active learning, with identical content/worksheets.
- **Timing/assistance:** immediate post-lesson quizzes; no delayed retention test. The home setting does not
  establish independently invigilated, tool-free assessment equivalent to a closed-room exam.
- **Finding:** median post-score 4.5 versus 3.5; reported adjusted effect 0.63 SD. Median tutor time was
  49 minutes versus an assumed 60 minutes of classroom learning. Tutor prompts included vetted solutions.
- **Limits:** selective institution, two topics, different learning settings, ceiling effects and unequal observed
  lesson counts (142 AI, 174 classroom). Large short-term gains do not establish semester or transfer effects.
- **Locator/support:** Results: Learning gains/Time on task; Methods: Student population/Study design;
  Discussion: prompt construction. **Supported** for this short-term comparison; durable superiority **unverified**.

### 3. LearnLM Team, Google & Eedi — supervised AI and same-day transfer

- **Identity/status:** *AI tutoring can safely and effectively support students: An exploratory RCT in UK classrooms*.
  [arXiv:2512.23633v1](https://arxiv.org/html/2512.23633v1), 29 December 2025; inspected preprint, no journal reference verified.
- **Population/design:** 165 students across five UK secondary schools; seven weeks in May–June 2025.
  Students randomized to static hints or tutoring; tutoring sessions further randomized to human-only or supervised LearnLM.
- **Timing/assistance:** humans approved, edited, or replaced **every** LearnLM message. Transfer was the first
  question of the next, distinct unit **on the same day**, before that unit's error-triggered support.
- **Finding:** 76.4% of drafts needed zero/minimal edits. Adjusted transfer success: 66.2% versus 60.7% human-only;
  difference +5.5 pp, **95% credible interval −1.4 to +12.4 pp**; comparison with static hints was more clearly positive.
- **Limits:** exploratory, session-level analysis, baseline adjustment, selected next-unit continuers; no delayed test.
  Neither nonsignificance nor a positive posterior mean establishes equivalence or superiority to humans.
- **Locator/support:** Methods: Procedure/Analysis; Appendix F.3.2, Tables F.5–F.6. **Supported** for supervised
  same-day outcomes; autonomous safety and LearnLM superiority over human tutors are **unverified**.

### 4. Wang et al. — Tutor CoPilot assists human tutors

- **Identity/status:** *Tutor CoPilot: A Human-AI Approach for Scaling Real-Time Expertise*.
  [arXiv:2410.03017v3](https://arxiv.org/html/2410.03017v3), revised 10 October 2026; first submitted 3 October 2024.
  Inspected preregistered working paper; no peer-reviewed journal version verified.
- **Population/design:** 900 tutors initially randomized; **783 active tutors and 1,013 students** in analyses,
  grades 3–6 in one US district. AI suggestions plus human tutoring versus usual human tutoring; seven-week implementation.
- **Timing/assistance:** session-end exit tickets, on which tutors were instructed not to help; immediate independent
  topic checks. Students could encounter tutors from both arms across sessions; no causal year-end achievement estimate.
- **Finding:** unconditional exit-ticket passing increased about 4 pp, from 62% to 66%; about 9 pp with lower-rated tutors.
- **Limits:** tutor-level randomization, changing tutor–student matches, tutor training bundled with access;
  largest subgroup is defined by tutor rating, not evidence of equal benefits across learner demographics.
- **Locator/support:** Methods: Randomization and Participants; Table 1; RQ2; Appendix B and tutoring-moment taxonomy.
  **Supported** for immediate checks with human delivery. The abstract's 900/1,800 is not the analyzed sample.

### 5. Liu et al. — course-integrated access can disappoint

- **Identity/status:** *The Effects of Course-Integrated AI Tutoring on Student Performance and Engagement:
  A Randomized University Trial*. [EdWorkingPaper 26-1598](https://edworkingpapers.com/ai26-1598), October 2026;
  manuscript dated 30 September; [DOI 10.26300/y3f8-vh05](https://doi.org/10.26300/y3f8-vh05). Working paper, full PDF inspected.
- **Population/design:** 2,379 US public-university undergraduates, 30 instructors; instructor-level randomization
  within same/similar-course blocks. Course-grounded GPT-4o assistant access versus no course-assistant access.
- **Timing/assistance:** semester-end **course grades**, combining assessment types; not a standardized unaided test.
- **Finding:** exact-course-match estimate −0.37 SD final grades and −0.90 SD LMS participation;
  full-sample academic estimates were less precise. Estimated losses were larger for first-generation students.
- **Limits:** roughly 15% uptake; other AI available in both arms; mostly default direct-instruction mode;
  three nonactivating instructors excluded. Displacement is plausible, not an identified causal mechanism.
- **Locator/support:** §§2.2–2.3, 5/Table 3, 6.1/Table 4 and A4, Discussion. **Supported** for this access policy;
  “all scaffolded tutors harm learning” and “RAG alone assures learning gains” are **unverified** generalizations.

### 6. Kotalwar et al. — seeing handwriting and deciding when to speak

- **Identity/status:** *Exploring Visual Access and Proactive AI Tutoring for Handwritten Mathematics*.
  [arXiv:2610.26411v1](https://arxiv.org/html/2610.26411v1), 19 October 2026; inspected preprint.
- **Population/design:** 117 adults in an online calculus study; Text-Reactive (40), Visual-Reactive (37),
  Visual-Proactive (40). All conditions received tutoring; no no-tutor comparator.
- **Timing/assistance:** one approximately 80-minute session; 35-minute assisted activity between alternate,
  counterbalanced nine-item tests **without AI assistance**. No delayed assessment.
- **Finding:** pooled scores rose 3.3→4.6/9; adjusted condition differences were not significant.
  Visual-Proactive minus Visual-Reactive: +0.66 points, 95% CI −0.23 to +1.55; Holm p=.429.
- **Limits:** pre/post improvement cannot isolate AI's effect. Support ratings (5.53/7) describe recipients
  of proactive messages, not demonstrated learning gains; prior-knowledge moderation was not robust.
- **Locator/support:** §§4.2–4.3, 5.1.3/Table 4, 5.3/Table 5, 6.3, 7. **Supported** for feasibility and changed
  interaction; visual/proactive learning superiority **unverified**, not evidence that conditions are equivalent.

### 7. Chung et al. — the paper behind the Simons mastery-learning talk

- **Identity/status:** *Effective Personalized AI Tutors via LLM-Guided Reinforcement Learning*.
  [Author full PDF](https://hamsabastani.github.io/llmRL_doe.pdf); [arXiv:2608.16907v1](https://arxiv.org/html/2608.16907v1);
  [SSRN DOI 10.2139/ssrn.6423358](https://doi.org/10.2139/ssrn.6423358). Working paper, full methods inspected.
- **Version caveat:** arXiv record/HTML displays **10 July 2026**, inconsistent with its 2608 identifier;
  preserve the version identifier and retrieval date; exact deposit chronology remains **unverified**.
- **Population/design:** 1,047 enrolled in ten Taipei high schools; main analysis 770, adjusted model 716.
  Five-month Python course; adaptive problem sequencing versus fixed easy-to-hard sequence, **same chatbot/content**.
- **Timing/assistance:** June 2025 in-person, closed-book written certification exam; no digital devices.
  End-of-course independent performance, not a delayed follow-up after instruction stopped.
- **Finding:** +0.156 SD unadjusted (SE .072); +0.150 adjusted (SE .067). Sequencing, not chatbot presence, was randomized.
- **Limits:** exclusions include dropout/no exam, cheating, and accelerated seniors; expanded analysis including seniors
  was smaller and nonsignificant. Engagement mediation is assumption-dependent; no “months of schooling” conversion warranted here.
- **Locator/support:** §§3–4.1, Fig. 2; Supplements E.1/F.1, Tables 6/10/12. **Supported**, conditional on analyzed population.

### 8. Oreopoulos et al. — NUMI, mastery rules, and one-week retention

- **Identity/status:** *Making AI Tutoring Productive: Evidence from a Mastery-Based Math Practice Experiment*.
  NBER Working Paper 35621, August 2026; [DOI](https://doi.org/10.3386/w35621),
  [full PDF](https://www.nber.org/system/files/working_papers/w35621/w35621.pdf); not peer reviewed.
- **Population/design:** grades 6–8, 20 Tennessee schools; over 6,000 learners. Individually randomized
  AI versus computer-assisted learning without AI, mastery versus flexible progression, and math topic.
- **Timing/assistance:** one practice period, then four-question classroom assessment about one week later;
  paper/pencil instructed, teachers prohibited from answering content questions. Digital-tool enforcement not established here.
- **Finding:** three-correct-in-a-row requirements increased platform success but did not alone improve delayed learning.
  AI within mastery: practiced Exercise 1 correctness 37.0%→40.2%, Table 9 difference .032, SE .017, p=.065, n=3,209.
- **Limits:** brief test; gain concentrated on one practiced item, not broad transfer. AI slowed progression;
  conditional accuracy selects reached attempts. Table 1 n=6,997 versus balance-table n=6,362 needs reconciliation.
- **Locator/support:** §§3.1/3.6, 4.3, 5.5, Table 9, Limitations. **Supported** for weak, narrow retention evidence;
  treating this mastery rule as validation of durable mastery is **unsupported**.

### 9. Huang et al. — interpretable dialogue knowledge tracing

- **Identity/status:** *Interpretable Difficulty-Aware Knowledge Tracing in Tutor-Student Dialogues*.
  BEA proceedings, 3–4 July 2026; peer-reviewed workshop paper, pp. 612–623.
  [DOI 10.18653/v1/2026.bea-1.43](https://doi.org/10.18653/v1/2026.bea-1.43); [full PDF](https://aclanthology.org/2026.bea-1.43.pdf).
- **Population/design:** retrospective dialogue datasets, not a learner trial. QATD2k: real Eedi tutoring,
  1,573 training/393 test dialogues; MathDial: **GPT-3.5-simulated students**, 2,235/588 dialogues.
- **Comparator/outcome:** difficulty-aware Llama-3.1-8B plus Item Response Theory versus neural/LLM tracing baselines;
  predicts next-turn correctness within tutoring. No independent delayed assessment or deployed scheduling experiment.
- **Finding:** QATD2k AUC .6525 versus .6489 for LLMKT; MathDial .7659 versus .7599.
  AUC measures ranking of correct versus incorrect responses; it is not a learner's probability of mastery.
- **Limits:** modest differences, LLM-derived correctness/concept annotations, partly simulated data;
  no demonstrated subgroup calibration or causal learning benefit from deploying this model.
- **Locator/support:** §§4.1–4.3, 5.1/Table 1, Ethics. **Supported** for offline prediction;
  “interpretable state equals validated independent mastery” is **unverified**.

### 10. Zhang et al. — reliable-looking grading can still be biased

- **Identity/status:** *Evaluating large language models for criterion-based grading from agreement to consistency*.
  npj Science of Learning, 30 December 2024; peer-reviewed version of record.
  [DOI 10.1038/s41539-024-00291-1](https://doi.org/10.1038/s41539-024-00291-1); [open text](https://pmc.ncbi.nlm.nih.gov/articles/PMC11683144/).
- **Population/design:** 31 published IELTS academic Task 2 essays; official examiner scores as benchmarks;
  progressively detailed prompts, ChatGPT 3.5, with follow-up GPT-4 and Claude 3 Haiku comparisons.
- **Timing/assistance:** offline grading, not learner intervention or assessment of retained knowledge.
- **Finding:** detailed band descriptors improved consistency; ChatGPT 3.5 absolute-agreement ICC .61
  (95% CI .02–.85), consistency ICC .77 (.57–.88). Scores remained systematically lower than examiner scores.
- **Limits:** tiny public corpus, possible training exposure, wide intervals, old model snapshots;
  nonconforming outputs were rerun. Repeatability does not establish correctness, fairness, or feedback efficacy.
- **Locator/support:** Table 1; results after Fig. 1; Methods: Essay/Procedure. **Supported** for rubric-sensitive
  performance and residual bias; generalized dependable autonomous assessment **unverified**.

### 11. Zou et al. — spacing has neural evidence, not a universal schedule

- **Identity/status:** *Benefits of spaced learning are predicted by the re-encoding of past experience in
  ventromedial prefrontal cortex*. Cell Reports 44, 115232; published online 23 January 2025, issue 25 February.
  [DOI 10.1016/j.celrep.2025.115232](https://doi.org/10.1016/j.celrep.2025.115232);
  [open author manuscript](https://pmc.ncbi.nlm.nih.gov/articles/PMC12007619/), available 18 April 2025; peer reviewed.
- **Population/design:** eight adults, 30–40 imaging sessions over 8–10 months; thousands of scene images
  repeated at different lags. Within-person comparisons of spacing and neural representations; no tutor comparator.
- **Timing/assistance:** unaided recognition at repeated encounters; lags from seconds to months;
  memory, not curricular problem solving or transfer.
- **Finding:** spacing-related neural similarity predicted later recognition; benefits depended strongly on
  successful recognition at re-encounter. Optimal spacing varied with retention interval rather than increasing without limit.
- **Limits:** eight people despite many observations; neural association does not identify a causal teaching mechanism.
  No evidence here for fixed 1/3/7/21-day schedules, learning styles, or inferring mastery from attention/brain activity.
- **Locator/support:** Fig. 1 and Results; STAR Methods. **Supported** for bounded memory findings;
  personalized ScreenTutor scheduling from this alone is **unverified**.

### 12. Ennion & McLellan — responses to challenge, published this week

- **Identity/status:** *Human tutoring, generative AI tutoring and independent internet search: A randomised
  between-subjects experiment on students' responses to academic challenge*. BJET Early View, 13 November 2026;
  [DOI/full text 10.1111/bjet.70100](https://doi.org/10.1111/bjet.70100), peer-reviewed original article.
- **Population/design:** 160 volunteers aged 16–18 at one English college; 149 analyzed after technical exclusions.
  Human tutor (52), Khanmigo Lite (50), or internet search (47); one 90-minute session.
- **Timing/assistance:** two supported mathematics sections, then immediate challenge selection;
  effort/difficulty self-reports and attempts, **not accuracy, delayed learning, or transfer**.
- **Finding:** AI users reported higher effort/difficulty than human-tutored learners in section 2;
  challenge-seeking did not differ by condition. Stress comparisons were descriptive, not inferential.
- **Limits:** one human tutor; opaque changing AI snapshot; preregistration deviations; exact analyses exploratory.
  More effort could reflect useful thinking or unproductive friction; the study cannot distinguish these through retention.
- **Locator/support:** Methods: Design/Support conditions/Data analysis; Findings: Effort/Challenge-seeking/Stress.
  **Supported** for immediate process measures; improved resilience or independent mastery **unverified**.

## Requested synthesis and lead checks

- **IZA DP 19072:** Dang & Behrman, *From Cheap Answers to Lasting Learning: AI Tutoring and Educational Inequality*,
  November 2026; [official record](https://www.iza.org/publications/dp/19072/from-cheap-answers-to-lasting-learning-ai-tutoring-and-educational-inequality),
  [44-page full working paper](https://docs.iza.org/dp19072.pdf). Synthesis/framework, **no new randomized learner sample**.
  Comparator/outcome timing vary across underlying studies. §§4–6, Table 1, Appendix A distinguish program effects,
  AI's incremental contribution, full costs, and equity. **Supported** as a decision framework; not independent replication.
  Access, disadvantaged learners' gains, and narrowing achievement gaps are separate outcomes; cost estimates omit different inputs.
- **Simons, 12 January 2026:** [official talk abstract](https://simons.berkeley.edu/talks/hamsa-bastani-upenn-2026-01-12)
  describes roughly 1,000 Python learners and +0.15 SD on an unaided exam. **Abstract-only check of the event**;
  full related study followed and audited as source 7. Do not count the talk as another trial or use its schooling conversion.
- **Latest excluded lead:** [Scientific Reports, 16 November 2026](https://doi.org/10.1038/s41598-026-79651-3),
  *Quasi-experimental evaluation of a human-centric AI tutoring and human-in-the-loop assessment system in advanced STEM education*.
  Publisher access redirected to inaccessible authentication. **Unverified/inaccessible full text**; no outcome claim adopted.

## Actionable implications — proposed designs, not validated ScreenTutor behavior

1. **Make independent evidence visible.** Show assisted completion, immediate independent checks, and delayed checks separately.
   Record task novelty, help received, assessment conditions, date, and scoring uncertainty; do not turn every correct answer into mastery.
2. **Sequence questions around evidence.** Start with a brief independent attempt; diagnose the first meaningful error;
   offer one cue, then a worked step if needed; finish with a different question without help. Revisit later.
   Sources 1/3/4/7/8 motivate components; this complete sequence still needs evaluation.
3. **Separate teaching from assessment.** Let learners request an explanation, but mark the task assisted after answer-revealing help.
   During independent checks, pause hints and corrective overlays. Ask learners to confirm ambiguous handwriting before scoring it.
4. **Test sequencing before adding sophisticated learner models.** Source 7 supports a controlled comparison with the same tutor/content.
   Source 9 supports modeling task difficulty separately from ability; it does not validate a complex model for this app's cold start.
5. **Use adaptive review cautiously.** Target retention and revise intervals using observed independent recall.
   No selected study establishes an optimal FSRS policy or universal day schedule for multi-step mathematical reasoning.
6. **Keep interventions interruptible.** Offer a visible pause/help control and wait while work is changing.
   Source 6 supports studying these choices; it does not establish that more proactive messages produce more learning.
7. **Reduce interface burden, preserve intellectual work.** Keep one current question visible; anchor feedback beside the relevant step;
   provide a short explanation and an optional expansion. These are design hypotheses, not isolated effects proven by these trials.
8. **Treat grading as an uncertain measurement.** Use explicit rubrics and vetted answers; retain the observed work and rationale.
   Require review when recognition or scoring is uncertain. Source 10 shows why agreement, bias, and repeatability need separate checks.
9. **Support access without assuming equal effects.** Offer equivalent text/voice/keyboard paths, readable feedback, replay, and learner pacing.
   These accessibility proposals require usability testing; the selected trials do not validate disability-specific efficacy.
10. **Avoid forced struggle.** Give learners a way to request more explanation or human support. Monitor abandoned tasks and frustration.
    Source 12 shows that effort and stress deserve measurement; neither is a substitute for retained learning.

## Evaluation, calibration, and remaining gaps

- **Primary proposed success measure:** unseen, unaided problems after a stated delay, with near and farther transfer scored separately.
  A one-week check is a feasible proposal, not an evidence-derived optimum; add longer follow-up before claiming durable independence.
- **Comparators:** hold content, time budget, and model fixed when testing sequencing or proactivity. Compare with existing study practice
  when testing the whole product. Human-supervised AI, autonomous AI, and human-only tutoring answer different questions.
- **Calibration:** validate predicted probabilities against later independent responses using held-out learners and topics;
  report reliability plots, Brier/log loss, false-mastery errors, and coverage when the system abstains. AUC alone is insufficient.
- **Scoring audit:** blind human raters to condition, adjudicate disagreements, and test repeated model scores and version changes.
  Generated questions also need independent checks for answer validity, ambiguity, difficulty, and prerequisite alignment.
- **Fairness:** measure access, uptake, technical failure, scoring error, and learning effects separately by relevant subgroups;
  include prior knowledge, language, disability/accommodations, and first-generation status where consent and sample size permit.
  Report subgroup uncertainty and interaction tests; a null subgroup test is not proof of fairness.
- **Generalization:** none of these studies validates ScreenTutor's combined voice, screen overlay, camera, and computer-control interface.
  Evidence is especially thin for disabled/neurodivergent learners, multilingual handwriting, adult self-study, and far transfer.
- **Research boundary:** neuroscience supports mechanisms to investigate; it does not license brain-based personalization claims.
  Simulated students can test pipelines, but cannot establish human learning, motivation, or inclusion.
- **Prior-note corrections:** Bastani is immediate, LearnLM is supervised/same-day with uncertain human comparison,
  Tutor CoPilot's analyzed counts differ from its abstract, and Liu measures mixed course grades under a specific access policy.
  The earlier note remains unchanged; these qualifications should govern future summaries.
