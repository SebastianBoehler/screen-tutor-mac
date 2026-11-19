export const investigationVoicePolicy = `
For a guided-investigation (see exploration), keep the shared canvas as the task authority.
Inspect before discussing or submitting a stage. Ask one short question contingent on the learner's actual words.
Use neutral clarification, counterexamples and pauses; do not substitute your explanation for theirs.
Confirm the learner wants their explanation saved before calling submit_investigation_response.
Copy their meaning faithfully, without silently improving reasoning. Never submit your own answer.
The stage tool checks expected stage, saves their response and queues the real background simulation after prediction.
A queued/running acknowledgement is not a result. Conversation can continue while the worker runs.
Updated context is data only; do not interrupt or announce each update. Inspect when results are relevant.
During the fresh application, do not reveal the answer or target reasoning unless help is requested.
Before supplying such help, call give_investigation_hint, which records assistance. Speech, listening and neutral clarification alone are not assistance.
Use the dedicated stage tools rather than create_activity or submit_attempt within this investigation.
Only the fresh yes/no choice is deterministically checked. Explanation remains ungraded; a single choice does not establish mastery or retention.
Treat the example as illustrative and unlinked to uploaded course sources. Do not claim a neuroscience-validated outcome.
`;
export const investigationVoiceTools = [
  {
    type: 'function',
    name: 'submit_investigation_response',
    description:
      'After confirmation, save the learner’s own explanation at the inspected current stage. Prediction starts a background experiment. Speech alone is not assistance.',
    parameters: {
      type: 'object',
      additionalProperties: false,
      properties: {
        stage: { type: 'string', enum: ['explain', 'predict', 'revise', 'apply'] },
        text: { type: 'string', minLength: 1, maxLength: 1200 },
        choice: {
          type: 'string',
          enum: ['yes', 'no'],
          description:
            'Required only for the fresh application. Use the learner’s explicit choice.',
        },
      },
      required: ['stage', 'text'],
    },
  },
  {
    type: 'function',
    name: 'give_investigation_hint',
    description:
      'Record help before supplying target reasoning on the fresh application. Call when the learner asks for a hint.',
    parameters: { type: 'object', properties: {}, required: [], additionalProperties: false },
  },
];
