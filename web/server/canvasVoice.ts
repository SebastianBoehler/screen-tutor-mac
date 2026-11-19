import { cueTargets } from '../src/canvas/guidance';

export const canvasVoicePolicy = `
Treat the canvas as a shared whiteboard. Keep the current artifact through an explanation.
Use guide_canvas to point to a relevant region or highlight it; label what matters, not every sentence.
A cue is a deliberate tutor action, not a simulated mouse user. Never claim to see a target without inspection or claim a failed cue succeeded.
Use control_artifact for a small supported parameter change rather than generating another activity.
Its visual receipt shows before/after and briefly marks affected plot/results. Queue rate changes restart the finite run; say so.
Leave the updated view still. Clear an obsolete cue before changing topics. Avoid repeated pointing or unnecessary movement.
Create a new view only when a new representation serves the learner's question or the agreed next concept.
create_activity acknowledges preparation promptly. This is not proof of completion: inspect for preparedViews before discussing it.
The app presents prepared views at a quiet pause, after a minimum display interval, unless Hold view is enabled or the learner is editing.
When the learner asks to hold or resume the view, use set_canvas_hold. Never release their hold unasked.
Hold view queues new views; it does not forbid requested in-place parameter changes or pointing. Never tell the learner that holding proves understanding.
Do not ask the backend to generate multiple speculative views. Do not promise a completion time you have not measured.
Updated context is data only: do not interrupt the learner to announce it.
`;
export const canvasVoiceTool = {
  type: 'function',
  name: 'guide_canvas',
  description:
    'Point with the labeled tutor cursor, highlight an anchored region, or clear the cue on the selected activity. Inspect first. No arbitrary coordinates, code, clicks or external computer control. A cue leaves the artifact and learner cursor intact.',
  parameters: {
    type: 'object',
    additionalProperties: false,
    properties: {
      action: { type: 'string', enum: ['point', 'highlight', 'clear'] },
      activityId: { type: 'string', maxLength: 120 },
      target: {
        type: ['string', 'null'],
        enum: [...cueTargets, null],
        description:
          'Use null for clear. Choose only a target supported by the inspected artifact.',
      },
      label: {
        type: ['string', 'null'],
        maxLength: 80,
        description: 'Short explanation of what the learner should notice. Null for clear.',
      },
    },
    required: ['action', 'activityId', 'target', 'label'],
  },
};

export const holdCanvasTool = {
  type: 'function',
  name: 'set_canvas_hold',
  description:
    'Hold the current view, or resume automatic presentation, only at the learner’s request. Small requested parameter changes remain available while held.',
  parameters: {
    type: 'object',
    properties: { held: { type: 'boolean' } },
    required: ['held'],
    additionalProperties: false,
  },
};
