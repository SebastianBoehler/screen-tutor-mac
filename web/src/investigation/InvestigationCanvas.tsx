import { useEffect, useRef, useState } from 'react';
import type { Workspace } from '../domain/models';
import { CanvasGuide } from '../canvas/CanvasGuide';
import { presentView } from '../canvas/pacing';
import { ComparisonArtifact } from './ComparisonArtifact';
import {
  applicationHint,
  presentedInvestigation,
  investigationId,
  prompts,
  type Submission,
} from './model';

export function InvestigationCanvas({
  workspace,
  update,
  onSubmit,
  onHint,
  onControl,
  voiceConnected,
}: {
  workspace: Workspace;
  update(change: (value: Workspace) => Workspace): void;
  onSubmit(input: Submission): void;
  onHint(): void;
  onControl(status: 'queued' | 'cancelled'): void;
  voiceConnected: boolean;
}) {
  const state = presentedInvestigation(workspace)!;
  const stage = state.stage;
  const heading = useRef<HTMLHeadingElement>(null);
  const [error, setError] = useState('');
  const key = `${investigationId}:${stage}`;
  const text = workspace.drafts[key] ?? '';
  const choice = workspace.drafts[`${key}:choice`] ?? '';
  const draft = (id: string, value: string) =>
    update((workspace) => ({
      ...workspace,
      drafts: { ...workspace.drafts, [id]: value },
    }));
  useEffect(() => {
    setError('');
    heading.current?.focus();
  }, [stage]);
  const stages = ['explain', 'predict', 'experiment', 'revise', 'apply'];
  const step = stage === 'complete' ? 5 : stages.indexOf(stage) + 1;
  const responding = stage !== 'experiment' && stage !== 'complete';
  const job = state.experiment;
  return (
    <article className="investigation-canvas canvas-guided" aria-label="Guided queue investigation">
      <CanvasGuide
        key={`${workspace.selectedActivityId}:${stage}`}
        activityId={workspace.selectedActivityId!}
        active
        voiceConnected={voiceConnected}
      />
      <header>
        <p className="muted">
          Guided investigation · {stage === 'complete' ? 'Completed' : `Step ${step} of 5`}
        </p>
        <h1 ref={heading} tabIndex={-1}>
          {stage === 'apply' || stage === 'complete'
            ? 'Apply it: demand beyond capacity'
            : 'Investigate spare capacity'}
        </h1>
        <p className="muted">Illustrative M/M/1 example · unlinked to uploaded course sources.</p>
      </header>
      {(stage === 'explain' || stage === 'predict') && (
        <p className="investigation-plan">
          Explain → predict → compare two runs → revise → try a fresh question. Reasoning stays
          yours; the app runs the simulation.
        </p>
      )}
      {stage === 'revise' && job?.result && (
        <>
          <ComparisonArtifact result={job.result} activityId={workspace.selectedActivityId!} />
          <blockquote>
            <strong>Your prediction</strong>
            <p>{state.responses.predict?.text}</p>
          </blockquote>
        </>
      )}
      <section className="investigation-question" aria-labelledby="investigation-prompt">
        <h2 id="investigation-prompt">{prompts[stage]}</h2>
        {stage === 'experiment' && (
          <div className="investigation-job">
            <p role="status">
              {job?.status === 'ready'
                ? 'Comparison prepared. Waiting for a quiet pause or for you to open it.'
                : job?.status === 'failed'
                  ? 'Experiment failed.'
                  : job?.status === 'cancelled'
                    ? 'Experiment cancelled. Your prediction is saved.'
                    : 'Running two local simulations…'}
            </p>
            <p className="muted">
              Arrival rates 4 and 4.75/min · service 5/min · 200 simulated minutes each.
            </p>
            {job?.error && <p role="alert">{job.error}</p>}
            {job?.status === 'ready' ? (
              <button
                className="secondary"
                onClick={() => update((value) => presentView(value, investigationId))}
              >
                Show comparison
              </button>
            ) : job?.status === 'cancelled' || job?.status === 'failed' ? (
              <button className="secondary" onClick={() => onControl('queued')}>
                Retry experiment
              </button>
            ) : (
              <button className="secondary" onClick={() => onControl('cancelled')}>
                Cancel experiment
              </button>
            )}
          </div>
        )}
        {responding && (
          <form
            onSubmit={(event) => {
              event.preventDefault();
              try {
                onSubmit({
                  stage,
                  text,
                  medium: 'text',
                  ...(choice === 'yes' || choice === 'no' ? { choice } : {}),
                });
              } catch (error) {
                setError((error as Error).message);
              }
            }}
          >
            {stage === 'apply' && (
              <fieldset>
                <legend>Can a finite stationary mean exist?</legend>
                {(['yes', 'no'] as const).map((value) => (
                  <label key={value}>
                    <input
                      type="radio"
                      name="stationary-mean"
                      value={value}
                      checked={choice === value}
                      onChange={() => draft(`${key}:choice`, value)}
                    />{' '}
                    {value === 'yes' ? 'Yes' : 'No'}
                  </label>
                ))}
              </fieldset>
            )}
            {!voiceConnected && (
              <>
                <label htmlFor="investigation-reasoning">
                  {stage === 'apply' ? 'Explain your answer' : 'Your reasoning'}
                </label>
                <textarea
                  id="investigation-reasoning"
                  rows={4}
                  maxLength={1200}
                  value={text}
                  onChange={(event) => draft(key, event.target.value)}
                  placeholder="Write your own explanation, or explain it to the live tutor."
                />
              </>
            )}
            {voiceConnected && (
              <p className="muted">
                Explain your reasoning aloud to the live tutor. It can save your response and
                advance the investigation.
              </p>
            )}
            <div className="row wrap">
              {!voiceConnected && (
                <button
                  className="primary"
                  disabled={!text.trim() || (stage === 'apply' && !choice)}
                >
                  {stage === 'explain'
                    ? 'Save and predict'
                    : stage === 'predict'
                      ? 'Save prediction and run'
                      : stage === 'revise'
                        ? 'Save revision and try a fresh question'
                        : 'Check my choice'}
                </button>
              )}
              {stage === 'apply' && !state.applicationAssisted && (
                <button type="button" className="secondary" onClick={onHint}>
                  Get a hint
                </button>
              )}
            </div>
            {stage === 'apply' && state.applicationAssisted && (
              <p role="status">Hint: {applicationHint}</p>
            )}
            <p className="muted">
              {stage === 'apply'
                ? 'Only your yes/no choice is checked. Your explanation is saved, ungraded. A hint marks this check assisted.'
                : 'Assisted exploration · saved locally · no mastery credit. Live voice is optional.'}
            </p>
          </form>
        )}
        {error && <p role="alert">{error}</p>}
        {stage === 'complete' && (
          <div className="investigation-complete" role="status">
            <p>
              <strong>
                {state.responses.apply?.choice === 'no' ? 'Choice correct.' : 'Choice incorrect.'}
              </strong>{' '}
              With arrivals above service capacity, no finite stationary mean exists.
            </p>
            <p>
              Explanation saved, not assessed. Retention not checked.{' '}
              {state.applicationAssisted
                ? 'This check used a hint.'
                : 'This check used no recorded hint.'}
            </p>
            <blockquote>
              <p>{state.responses.apply?.text}</p>
            </blockquote>
          </div>
        )}
      </section>
      <p className="investigation-voice muted">
        The tutor can inspect this stage and real results. Speaking alone is not assistance.
      </p>
    </article>
  );
}
