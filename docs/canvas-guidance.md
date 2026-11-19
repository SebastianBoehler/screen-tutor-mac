# A steady shared canvas during voice

The learner chose automatic presentation at a natural pause, with **Hold view**.
Small parameter changes happen in place. Earlier activities, drafts and simulations remain saved.

## Interaction

- Live voice requests the existing configured generator in the background. The tool acknowledges
  preparation promptly; it does not describe an uncompleted result as ready. No extra model or provider is introduced.
- Prepared activities persist without changing the selected activity. They stay out of the document
  until presented. A **Show prepared view** action lets the learner open one immediately.
- Automatic presentation runs only during a connected voice session on the study page. It waits
  for both speakers to stop, no text editing/dragging/selection, 1.2 seconds of quiet, and at least
  eight seconds since the selected activity appeared. These are initial UX heuristics, not validated
  comprehension thresholds. **Hold view** has no time limit and persists across reload.
- The tutor can point or highlight a named canvas region. A labeled tutor cursor is separate from
  the learner's real cursor. It stays attached to the artifact; it does not move the learner's mouse.
- Parameter edits show their before/after values and briefly mark the affected plot and results.
  The final result remains visible. Changing queue rates explicitly restarts that finite run.
- Pointer arrival and change emphasis stop within a second. Reduced-motion settings remove these
  animations while retaining the cue and numeric change. Cues are transient presentation state;
  they are not independent mastery evidence.

## Boundaries

The voice model chooses a small set of validated anchors and parameter commands. It cannot provide
arbitrary selectors, scripts, mouse coordinates or operating-system control. Tools reject stale
activity IDs and unaided exam assistance. Navigation during preparation discards obsolete replies.
The generator, network and actual voice provider still determine end-to-end latency; no seconds-level
provider latency is claimed without a live-key measurement.
