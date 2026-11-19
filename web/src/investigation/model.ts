import type { Workspace } from '../domain/models';
import type { QueueComparison } from './experiment';

export const investigationId = 'guided-mm1-investigation';
export const applicationId = `${investigationId}:application`;
export type Stage = 'explain' | 'predict' | 'experiment' | 'revise' | 'apply' | 'complete';
export type ResponseStage = Exclude<Stage, 'experiment' | 'complete'>;
export interface LearnerResponse {
  text: string;
  medium: 'text' | 'voice';
  at: string;
  choice?: 'yes' | 'no';
}
export interface Submission extends Omit<LearnerResponse, 'at'> {
  stage: ResponseStage;
}
export interface ExperimentJob {
  id: string;
  status: 'queued' | 'running' | 'ready' | 'failed' | 'cancelled';
  result?: QueueComparison;
  error?: string;
}
export interface Investigation {
  stage: Stage;
  responses: Partial<Record<ResponseStage, LearnerResponse>>;
  experiment: ExperimentJob | null;
  applicationAssisted: boolean;
}
export const prompts: Record<Stage, string> = {
  explain:
    'If arrivals stay below service capacity, does that make waiting negligible? Explain your current view.',
  predict:
    'Compare arrival rates of 4 and 4.75 customers/min with service at 5/min. Which system will have more customers on average, and why?',
  experiment: 'Two runs are being compared. What would a short simulation be unable to tell us?',
  revise:
    'Compare the results with your prediction. What would you revise, and what can this finite run establish?',
  apply:
    'A service desk receives 6 customers/min and serves 5/min. Can an M/M/1 model have a finite stationary mean? Choose yes or no and explain.',
  complete:
    'Your fresh application is saved. A later, different question is needed to check retention.',
};
export const applicationHint =
  'Compare the arrival rate with service capacity. Can the server clear demand over time?';
export const isInvestigation = (id: string | null | undefined) =>
  id === investigationId || id === applicationId;
export const getInvestigation = (workspace: Workspace) => workspace.investigations[investigationId];

export function presentedInvestigation(workspace: Workspace): Investigation | undefined {
  const state = getInvestigation(workspace);
  return state?.stage === 'revise' && workspace.canvas?.pendingActivityIds.includes(investigationId)
    ? { ...state, stage: 'experiment' }
    : state;
}

export function investigationContext(workspace: Workspace) {
  const state = presentedInvestigation(workspace);
  if (!state || !isInvestigation(workspace.selectedActivityId)) return null;
  return JSON.stringify({
    kind: 'guided-investigation',
    stage: state.stage,
    prompt: prompts[state.stage],
    responseExcerpts: Object.fromEntries(
      Object.entries(state.responses).map(([stage, response]) => [
        stage,
        {
          text: response.text.slice(0, 160),
          medium: response.medium,
          choice: response.choice,
        },
      ]),
    ),
    draftExcerpt: workspace.drafts[`${investigationId}:${state.stage}`]?.slice(0, 160),
    plan: 'M/M/1, initially empty, seed 42; arrival rates 4 and 4.75/min, service 5/min, 200 simulated minutes each.',
    experiment: state.experiment && {
      status: state.experiment.status,
      error: state.experiment.error,
      presented: !workspace.canvas?.pendingActivityIds.includes(investigationId),
      runs: workspace.canvas?.pendingActivityIds.includes(investigationId)
        ? undefined
        : state.experiment.result?.runs.map(({ points: _, ...run }) => run),
    },
    applicationAssisted: state.applicationAssisted,
    assessment:
      'Only the fresh yes/no choice is checked. Explanation ungraded; retention not checked.',
  });
}
