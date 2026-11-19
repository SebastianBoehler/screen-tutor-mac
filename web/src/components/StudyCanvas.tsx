import { useEffect, useRef } from 'react';
import type { useLearning } from '../services/useLearning';
import { isInvestigation } from '../investigation/model';
import { ActivityCanvas } from './ActivityCanvas';
import { InvestigationCanvas } from '../investigation/InvestigationCanvas';

export function StudyCanvas({
  app,
  onNext,
  onSource,
}: {
  app: ReturnType<typeof useLearning>;
  onNext(): void;
  onSource(id: string, page: number): void;
}) {
  const { activity, workspace, update } = app;
  const seen = useRef(new Set<string>());
  const prepared = useRef(new Set<string>());
  const previousCourse = useRef<string | undefined>(undefined);
  useEffect(() => {
    if (!activity || isInvestigation(activity.id)) return;
    for (const id of workspace.canvas?.pendingActivityIds ?? []) prepared.current.add(id);
    const isNew = !seen.current.has(activity.id);
    const courseChanged = previousCourse.current !== activity.courseId;
    previousCourse.current = activity.courseId;
    for (const item of workspace.activities) seen.current.add(item.id);
    if (isNew || courseChanged || prepared.current.delete(activity.id))
      document.getElementById(`activity-${activity.id}`)?.scrollIntoView({ block: 'start' });
  }, [activity?.id, workspace.activities, workspace.canvas?.pendingActivityIds]);
  if (!activity) return null;
  if (app.investigation.active)
    return (
      <InvestigationCanvas
        workspace={workspace}
        update={update}
        voiceConnected={app.voice.connected}
        onSubmit={app.investigation.submit}
        onHint={app.investigation.hint}
        onControl={app.investigation.control}
      />
    );
  return (
    <div className="study-document">
      {workspace.activities
        .filter(
          (item) =>
            item.courseId === activity.courseId &&
            !isInvestigation(item.id) &&
            !workspace.canvas?.pendingActivityIds.includes(item.id),
        )
        .map((item) => (
          <div
            key={item.id}
            onFocusCapture={() => {
              if (
                item.id !== workspace.selectedActivityId &&
                (!app.tutor.busy || app.tutor.background)
              )
                app.selectActivity(item.id);
            }}
            onPointerDownCapture={() => {
              if (
                item.id !== workspace.selectedActivityId &&
                (!app.tutor.busy || app.tutor.background)
              )
                app.selectActivity(item.id);
            }}
          >
            <ActivityCanvas
              activity={item}
              interactions={workspace.interactions}
              materials={workspace.materials.filter(
                (material) => material.courseId === item.courseId,
              )}
              draft={workspace.drafts[item.id] ?? ''}
              busy={app.tutor.busy && !app.tutor.background}
              requestBusy={app.tutor.busy}
              voiceConnected={app.voice.connected}
              active={item.id === workspace.selectedActivityId}
              exploration={workspace.interactiveStates[item.id]}
              onInteractiveState={(state) => app.saveExploration(item.id, state)}
              onExplore={() => app.event('explore', item.id)}
              onDraft={(text) =>
                update((value) => ({ ...value, drafts: { ...value.drafts, [item.id]: text } }))
              }
              onAttempt={() => app.checkReasoning(item.id)}
              onHint={() => app.event('hint', item.id)}
              onReveal={() => app.event('reveal', item.id)}
              onNext={onNext}
              onSource={onSource}
            />
          </div>
        ))}
    </div>
  );
}
