import { ArrowUpRight, CheckCircle2, Moon } from 'lucide-react';
import type { Workspace } from '../domain/models';
import { evidenceFor, isRestWindow, reviewPlan } from '../domain/progress';

export function Plan({
  workspace,
  update,
  onReview,
}: {
  workspace: Workspace;
  update(change: (value: Workspace) => Workspace): void;
  onReview(activityId: string): void;
}) {
  const plan = reviewPlan(workspace);
  const independent = workspace.activities.filter(
    (activity) => evidenceFor(activity.id, workspace.interactions).independent.length > 0,
  ).length;
  const resting = isRestWindow(
    new Date(),
    workspace.settings.restStart,
    workspace.settings.restEnd,
  );
  return (
    <section className="page-content">
      <span className="eyebrow">Across your courses</span>
      <h1>A little progress. Room to rest.</h1>
      <p className="page-intro">
        Space your practice over time. Successful checks are evidence to build on, rather than a
        final claim of mastery.
      </p>
      <div className="progress-summary">
        <CheckCircle2 size={22} />
        <strong>{independent}</strong>
        <span>concepts with a successful independent check</span>
      </div>
      <form className="plan-preferences" onSubmit={(event) => event.preventDefault()}>
        <label>
          Daily review budget
          <select
            value={workspace.settings.dailyMinutes}
            onChange={(event) =>
              update((value) => ({
                ...value,
                settings: {
                  ...value.settings,
                  dailyMinutes: Number(event.target.value),
                },
              }))
            }
          >
            {[10, 20, 30, 45, 60].map((minutes) => (
              <option value={minutes} key={minutes}>
                {minutes} minutes
              </option>
            ))}
          </select>
        </label>
        <label>
          Rest from
          <input
            type="time"
            value={workspace.settings.restStart}
            onChange={(event) => {
              const restStart = event.target.value;
              if (restStart)
                update((value) => ({
                  ...value,
                  settings: { ...value.settings, restStart },
                }));
            }}
          />
        </label>
        <label>
          Until
          <input
            type="time"
            value={workspace.settings.restEnd}
            onChange={(event) => {
              const restEnd = event.target.value;
              if (restEnd)
                update((value) => ({
                  ...value,
                  settings: { ...value.settings, restEnd },
                }));
            }}
          />
        </label>
      </form>
      <p className="rest-note">
        <Moon size={16} />
        {resting
          ? 'You are inside your rest window. Reviews can wait.'
          : `Rest protected from ${workspace.settings.restStart} to ${workspace.settings.restEnd}.`}
      </p>
      <h2 className="list-title">Your next reviews</h2>
      {!plan.length && (
        <div className="empty-inline">
          <p>After your first assessed attempt, reviews appear here across all your courses.</p>
        </div>
      )}
      {plan.map((item) => (
        <div className="review-row" key={item.activity.id}>
          <div className="grow">
            <strong>{item.activity.concept}</strong>
            <p className="muted">
              {workspace.courses.find((course) => course.id === item.activity.courseId)?.name} ·{' '}
              {item.dueNow
                ? 'Due for a check'
                : item.due.toLocaleDateString(undefined, {
                    day: 'numeric',
                    month: 'short',
                  })}
            </p>
          </div>
          <span className="muted">{item.withinBudget ? '~10 min' : 'Beyond today’s budget'}</span>
          <button
            className="icon-button"
            aria-label={`Review ${item.activity.concept}`}
            onClick={() => onReview(item.activity.id)}
          >
            <ArrowUpRight size={18} />
          </button>
        </div>
      ))}
      <h2 className="list-title">Course goals</h2>
      {workspace.courses.map((course) => (
        <div className="goal-row" key={course.id}>
          <strong>{course.name}</strong>
          <p>{course.goal || 'Add a goal from your study canvas.'}</p>
          {course.examDate && (
            <p className="muted">
              Exam: {new Date(course.examDate + 'T12:00:00').toLocaleDateString()}
            </p>
          )}
        </div>
      ))}
      <p className="footnote">
        Review dates use an expanding interval heuristic. Time estimates are planning aids. This
        schedule does not measure sleep or predict exam results.
      </p>
    </section>
  );
}
