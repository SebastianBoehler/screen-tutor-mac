import type { Activity, Interaction, Workspace } from './models';

const day = 86_400_000;
export function evidenceFor(activityId: string, interactions: Interaction[]) {
  const events = interactions.filter((item) => item.activityId === activityId);
  const independent = events.filter(
    (item) => item.kind === 'attempt' && item.verdict === 'correct' && !item.assisted,
  );
  return {
    events,
    independent,
    assisted: events.some((item) => item.assisted || item.kind !== 'attempt'),
  };
}

/** A transparent expanding review heuristic, not a validated memory model or mastery claim. */
export function nextReview(activity: Activity, interactions: Interaction[]): Date | null {
  const { events } = evidenceFor(activity.id, interactions);
  const attempts = events.filter((item) => item.kind === 'attempt' && item.verdict !== 'ungraded');
  if (!attempts.length) return null;
  const latest = attempts.at(-1)!;
  const successfulDays = new Set<string>();
  for (const attempt of [...attempts].reverse()) {
    if (attempt.assisted || attempt.verdict !== 'correct') break;
    successfulDays.add(attempt.at.slice(0, 10));
  }
  const interval = [1, 3, 7, 14, 30][Math.min(Math.max(successfulDays.size - 1, 0), 4)];
  return new Date(new Date(latest.at).getTime() + interval * day);
}
export function isRestWindow(date: Date, start: string, end: string) {
  const minute = date.getHours() * 60 + date.getMinutes();
  const parse = (time: string) => Number(time.slice(0, 2)) * 60 + Number(time.slice(3));
  const a = parse(start),
    b = parse(end);
  return a < b ? minute >= a && minute < b : minute >= a || minute < b;
}
export function reviewPlan(workspace: Workspace, at = new Date()) {
  return workspace.activities
    .flatMap((activity) => {
      const due = nextReview(activity, workspace.interactions);
      return due ? [{ activity, due }] : [];
    })
    .sort((a, b) => a.due.getTime() - b.due.getTime())
    .map((item, index) => ({
      ...item,
      dueNow: item.due <= at,
      withinBudget: index < Math.floor(workspace.settings.dailyMinutes / 10),
    }));
}
