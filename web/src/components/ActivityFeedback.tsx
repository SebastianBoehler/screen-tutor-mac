import { lazy, Suspense } from 'react';
import type { Activity, Interaction } from '../domain/models';
import { isCanvasExample } from '../domain/exampleContent';
const RichText = lazy(() => import('./RichText'));

export function ActivityFeedback({
  activity,
  events,
  busy,
  onNext,
}: {
  activity: Activity;
  events: Interaction[];
  busy: boolean;
  onNext(): void;
}) {
  const revealed = events.some((item) => item.kind === 'reveal');
  const hinted = events.some((item) => item.kind === 'hint');
  const assisted = events.some((item) => item.assisted || item.kind !== 'attempt');
  const attempt = events.filter((item) => item.kind === 'attempt').at(-1);
  const exam = activity.mode === 'exam' && !activity.reviewedAt;
  return (
    <>
      {assisted && <p className="assistance-label">Assisted practice</p>}
      {hinted && !revealed && (
        <aside className="hint">
          <strong>Hint</strong>
          <Suspense fallback={null}>
            <RichText text={activity.hint} />
          </Suspense>
        </aside>
      )}
      {attempt && !revealed && (
        <p className="attempt-status" role="status">
          {isCanvasExample(activity.id)
            ? 'Reasoning saved locally · assisted and ungraded. Compare it with the hint or revealed explanation.'
            : exam
              ? 'Answer saved. Ask for a review when you finish.'
              : attempt.verdict === 'ungraded'
                ? 'Attempt saved. Feedback is in the conversation.'
                : attempt.verdict === 'correct'
                  ? `${attempt.assisted ? 'Assisted success' : 'Successful independent check'} · revisit later to test retention.`
                  : 'Attempt recorded. Use the feedback to revise your reasoning.'}
        </p>
      )}
      {revealed && (
        <div className="answer">
          <strong>Answer</strong>
          <Suspense fallback={null}>
            <RichText text={`${activity.answer}\n\n${activity.explanation}`} />
          </Suspense>
          {!isCanvasExample(activity.id) && (
            <button className="secondary" disabled={busy} onClick={onNext}>
              Try a new example
            </button>
          )}
        </div>
      )}
    </>
  );
}
