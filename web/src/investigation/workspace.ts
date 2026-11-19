import { now, uid, type Workspace, type Activity } from '../domain/models';
import { exampleCourse } from '../domain/canvasExamples';
import {
  applicationId,
  applicationHint,
  getInvestigation,
  investigationId,
  prompts,
  type ExperimentJob,
  type Investigation,
  type Submission,
} from './model';

function save(workspace: Workspace, state: Investigation): Workspace {
  return {
    ...workspace,
    investigations: { ...workspace.investigations, [investigationId]: state },
  };
}
function activity(courseId: string, application = false): Activity {
  return {
    id: application ? applicationId : investigationId,
    courseId,
    createdAt: now(),
    mode: 'learn',
    title: application ? 'Apply it: demand beyond capacity' : 'Investigate spare capacity',
    concept: 'Queue growth near service capacity',
    body: 'Illustrative M/M/1 investigation; unlinked to uploaded course sources.',
    question: prompts[application ? 'apply' : 'explain'],
    choices: [],
    answer: '',
    hint: '',
    explanation: '',
    diagram: null,
    interactive: null,
    sourceIds: [],
  };
}
export function openInvestigation(workspace: Workspace): Workspace {
  const state = getInvestigation(workspace);
  if (state) {
    const id =
      state.stage === 'apply' || state.stage === 'complete' ? applicationId : investigationId;
    const existing = workspace.activities.find((item) => item.id === id)!;
    return { ...workspace, selectedCourseId: existing.courseId, selectedActivityId: id };
  }
  const course = exampleCourse(workspace);
  const courseId = course.id;
  return save(
    {
      ...workspace,
      courses: workspace.courses.some((item) => item.id === courseId)
        ? workspace.courses
        : [...workspace.courses, course],
      interactions: [
        ...workspace.interactions,
        {
          id: uid(),
          courseId,
          activityId: investigationId,
          at: now(),
          kind: 'explore',
          text: 'Opened assisted, ungraded queue investigation.',
          verdict: 'ungraded',
          assisted: true,
        },
      ],
      activities: [...workspace.activities, activity(courseId)],
      selectedCourseId: courseId,
      selectedActivityId: investigationId,
    },
    { stage: 'explain', responses: {}, experiment: null, applicationAssisted: false },
  );
}
export function submitInvestigation(workspace: Workspace, input: Submission): Workspace {
  const state = getInvestigation(workspace);
  if (input.stage === 'revise' && workspace.canvas?.pendingActivityIds.includes(investigationId))
    throw new Error('The comparison is prepared but not yet shown. Open it before revising.');
  const expectedId = state?.stage === 'apply' ? applicationId : investigationId;
  if (!state || state.stage !== input.stage || workspace.selectedActivityId !== expectedId)
    throw new Error(
      'The investigation has moved on. Inspect the current question before submitting.',
    );
  if (
    typeof input.text !== 'string' ||
    !input.text.trim() ||
    input.text.length > 1200 ||
    !['text', 'voice'].includes(input.medium)
  )
    throw new Error('Explain your reasoning in 1–1,200 characters.');
  if (input.stage === 'apply' && !['yes', 'no'].includes(input.choice ?? ''))
    throw new Error('Choose yes or no before saving your explanation.');
  const next = {
    ...state,
    responses: {
      ...state.responses,
      [input.stage]: {
        text: input.text.trim(),
        medium: input.medium,
        at: now(),
        ...(input.choice ? { choice: input.choice } : {}),
      },
    },
  };
  if (input.stage === 'explain') return save(workspace, { ...next, stage: 'predict' });
  if (input.stage === 'predict')
    return save(workspace, {
      ...next,
      stage: 'experiment',
      experiment: { id: uid(), status: 'queued' },
    });
  if (input.stage === 'revise') {
    const root = workspace.activities.find((item) => item.id === investigationId)!;
    return save(
      {
        ...workspace,
        activities: workspace.activities.some((item) => item.id === applicationId)
          ? workspace.activities
          : [...workspace.activities, activity(root.courseId, true)],
        selectedActivityId: applicationId,
      },
      { ...next, stage: 'apply' },
    );
  }
  const task = workspace.activities.find((item) => item.id === applicationId)!;
  return save(
    {
      ...workspace,
      interactions: [
        ...workspace.interactions,
        {
          id: uid(),
          courseId: task.courseId,
          activityId: applicationId,
          at: now(),
          kind: 'attempt',
          text: `Choice: ${input.choice}. Explanation (ungraded): ${input.text.trim()}`,
          verdict: input.choice === 'no' ? 'correct' : 'incorrect',
          assisted: state.applicationAssisted,
        },
      ],
    },
    { ...next, stage: 'complete' },
  );
}
export function updateExperiment(
  workspace: Workspace,
  id: string,
  update: Omit<ExperimentJob, 'id'>,
): Workspace {
  const state = getInvestigation(workspace);
  const job = state?.experiment;
  if (!state || state.stage !== 'experiment' || !job || job.id !== id) return workspace;
  if (job.status === 'cancelled' || job.status === 'failed') {
    if (update.status !== 'queued') return workspace;
  } else if (update.status === 'queued' || job.status === 'ready') return workspace;
  if (update.status === 'ready' && !update.result)
    throw new Error('The experiment returned no result.');
  return save(workspace, {
    ...state,
    stage: update.status === 'ready' ? 'revise' : 'experiment',
    experiment: { id: update.status === 'queued' ? uid() : id, ...update },
  });
}
export function giveInvestigationHint(workspace: Workspace): Workspace {
  const state = getInvestigation(workspace);
  if (!state || state.stage !== 'apply' || workspace.selectedActivityId !== applicationId)
    throw new Error('Hints are available on the fresh application question.');
  if (state.applicationAssisted) return workspace;
  const task = workspace.activities.find((item) => item.id === applicationId)!;
  return save(
    {
      ...workspace,
      interactions: [
        ...workspace.interactions,
        {
          id: uid(),
          courseId: task.courseId,
          activityId: applicationId,
          at: now(),
          kind: 'hint',
          text: applicationHint,
          verdict: 'ungraded',
          assisted: true,
        },
      ],
    },
    { ...state, applicationAssisted: true },
  );
}
