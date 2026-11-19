import { CanvasGuide } from '../canvas/CanvasGuide';
import { lazy, Suspense } from 'react';
import type { Activity, Interaction, Material } from '../domain/models';
import { isCanvasExample } from '../domain/exampleContent';
import { Mechanism } from './Mechanism';
import { ActivityFeedback } from './ActivityFeedback';
import type { InteractiveState } from '../interactive/state';
import { useInteractiveSession } from '../interactive/useInteractiveSession';
const InteractiveArtifact = lazy(() =>
  import('../interactive/InteractiveArtifact').then((module) => ({
    default: module.InteractiveArtifact,
  })),
);
const RichText = lazy(() => import('./RichText'));

interface Props {
  activity: Activity;
  interactions: Interaction[];
  materials: Material[];
  draft: string;
  busy: boolean;
  voiceConnected: boolean;
  active: boolean;
  exploration?: InteractiveState;
  onInteractiveState(value: InteractiveState): void;
  onExplore(): void;
  onDraft(value: string): void;
  onAttempt(): void;
  onHint(): void;
  onReveal(): void;
  onNext(): void;
  onSource(materialId: string, page: number): void;
}
export function ActivityCanvas(props: Props) {
  const { activity, interactions, draft, busy } = props;
  const titleId = `activity-title-${activity.id}`;
  const reasoningId = `reasoning-${activity.id}`;
  const events = interactions.filter((item) => item.activityId === activity.id);
  const revealed = events.some((item) => item.kind === 'reveal');
  const hinted = events.some((item) => item.kind === 'hint');
  const assisted = events.some((item) => item.assisted || item.kind !== 'attempt');
  const exam = activity.mode === 'exam' && !activity.reviewedAt;
  const interactive = useInteractiveSession(
    activity.id,
    activity.interactive,
    props.exploration,
    props.onInteractiveState,
    props.onExplore,
    props.active,
  );
  const canExplore = !exam || assisted;
  return (
    <article
      className="lesson canvas-guided"
      id={`activity-${activity.id}`}
      aria-labelledby={titleId}
    >
      <CanvasGuide
        activityId={activity.id}
        active={props.active}
        voiceConnected={props.voiceConnected}
      />
      <header className="activity-heading">
        <h1 id={titleId}>{activity.title}</h1>
        {exam && (
          <span className="mode-label">
            {assisted ? 'Practice exam · assisted' : 'Unaided practice'}
          </span>
        )}
      </header>
      {isCanvasExample(activity.id) && !activity.body.startsWith('Illustrative example') && (
        <p className="example-label">
          Illustrative example · unlinked to course sources · ungraded
        </p>
      )}
      {activity.body.trim() && (
        <Suspense fallback={<p className="muted">Loading activity…</p>}>
          <RichText text={activity.body} />
        </Suspense>
      )}
      {activity.diagram && <Mechanism diagram={activity.diagram} />}
      {activity.interactive &&
        interactive.state &&
        (canExplore ? (
          <Suspense fallback={<p role="status">Loading exploration…</p>}>
            <InteractiveArtifact
              spec={activity.interactive}
              state={interactive.state}
              active={props.active}
              activityId={activity.id}
              voiceConnected={props.voiceConnected}
              onChange={interactive.change}
              onCheckpoint={interactive.flush}
            />
          </Suspense>
        ) : props.voiceConnected ? (
          <p className="model-note">
            Answer aloud to the live tutor. The tutor can record your response.
          </p>
        ) : (
          <button className="secondary exploration-gate" onClick={props.onExplore}>
            Open exploration (assisted)
          </button>
        ))}
      <section className="prediction" aria-label="Your answer">
        <Suspense fallback={<p>{activity.question}</p>}>
          <RichText text={activity.question} />
        </Suspense>
        {activity.choices.length > 0 ? (
          <fieldset className="choices">
            <legend className="sr-only">Choose your prediction</legend>
            {activity.choices.map((choice, index) => (
              <label className={`choice ${draft === choice ? 'selected' : ''}`} key={index}>
                <input
                  type="radio"
                  name={activity.id}
                  checked={draft === choice}
                  disabled={busy || revealed}
                  onChange={() => props.onDraft(choice)}
                />
                <span>{choice}</span>
              </label>
            ))}
          </fieldset>
        ) : (
          <>
            <label className="sr-only" htmlFor={reasoningId}>
              Your answer or reasoning
            </label>
            <textarea
              id={reasoningId}
              value={draft}
              onChange={(event) => props.onDraft(event.target.value)}
              disabled={busy || revealed}
              placeholder="Explain your reasoning…"
              rows={2}
              maxLength={6000}
            />
          </>
        )}
        <div className="row wrap between activity-actions">
          {(!props.voiceConnected || activity.choices.length > 0) && (
            <button
              className="primary"
              disabled={busy || revealed || !draft.trim()}
              onClick={() => {
                interactive.flush();
                props.onAttempt();
              }}
            >
              {isCanvasExample(activity.id)
                ? 'Save my reasoning'
                : exam
                  ? 'Save my answer'
                  : 'Check my reasoning'}
            </button>
          )}
          {!revealed && (
            <div className="row wrap">
              <button className="text-button" disabled={busy} onClick={props.onHint}>
                {hinted ? 'Hint shown' : 'A small hint'}
              </button>
              <button className="text-button" disabled={busy} onClick={props.onReveal}>
                Reveal answer
              </button>
            </div>
          )}
        </div>
        <ActivityFeedback activity={activity} events={events} busy={busy} onNext={props.onNext} />
      </section>
      {activity.sourceIds.length > 0 && (
        <footer className="sources">
          {activity.sourceIds.map((id) => {
            const [materialId, page] = id.split(':');
            const material = props.materials.find((item) => item.id === materialId);
            return (
              material && (
                <button
                  key={id}
                  className="source-link"
                  onClick={() => props.onSource(materialId, Number(page))}
                >
                  {material.name} · p. {page}
                </button>
              )
            );
          })}
        </footer>
      )}
    </article>
  );
}
