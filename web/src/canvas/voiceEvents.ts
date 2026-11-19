import type { RefObject } from 'react';
import type { Workspace } from '../domain/models';
import { studyContext } from '../domain/retrieval';
import { presentedInvestigation, isInvestigation } from '../investigation/model';
import { controlArtifact, controllableParameters } from '../interactive/control';
import { getLiveInteractive } from '../interactive/state';
import type { VoiceEvents } from '../services/voice';
import type { useTutor } from '../services/useTutor';
import { guideCanvas, type GuidanceCommand } from './guidance';

export function canvasPresentation(workspace: Workspace) {
  const prepared = workspace.activities.filter(
    (item) =>
      item.courseId === workspace.selectedCourseId &&
      workspace.canvas?.pendingActivityIds.includes(item.id),
  );
  return {
    held: !!workspace.canvas?.held,
    preparedViews: prepared.map((item) => item.title),
    pendingViews: prepared.length,
  };
}

export function canvasVoiceEvents({
  current,
  hold,
  send,
  investigation,
  turn,
  error,
}: {
  current: RefObject<Workspace>;
  hold(held: boolean): void;
  send: RefObject<ReturnType<typeof useTutor>['send']>;
  investigation: NonNullable<VoiceEvents['investigation']>;
  turn(speaking: boolean): void;
  error(message: string): void;
}): Pick<
  VoiceEvents,
  | 'inspect'
  | 'activity'
  | 'controlArtifact'
  | 'guideCanvas'
  | 'holdCanvas'
  | 'investigation'
  | 'turn'
> {
  let preparing = false;
  const selected = (id: string) => {
    const value = current.current;
    const active = value.activities.find(
      (item) => item.id === id && item.courseId === value.selectedCourseId,
    );
    if (!active || id !== value.selectedActivityId)
      throw new Error('The selected activity changed. Inspect the canvas again.');
    if (
      active.mode === 'exam' &&
      !active.reviewedAt &&
      !value.interactions.some((item) => item.activityId === id && item.assisted)
    )
      throw new Error('Canvas assistance is locked during unaided practice.');
    return active;
  };
  return {
    turn,
    investigation,
    holdCanvas: (held) => {
      hold(held);
      return JSON.stringify(canvasPresentation(current.current));
    },
    inspect: () => {
      const value = current.current;
      const active = value.activities.find((item) => item.id === value.selectedActivityId);
      const context = studyContext(value, active?.concept ?? '', active?.mode ?? 'learn');
      return JSON.stringify({
        activity: active?.title,
        activityId: active?.id,
        question: context.activity?.question,
        artifact: active?.interactive ?? null,
        exploration: context.exploration ? JSON.parse(context.exploration) : null,
        assisted: context.assisted,
        presentation: { ...canvasPresentation(value), preparing },
        guidanceTargets: isInvestigation(active?.id)
          ? [
              'question',
              ...(presentedInvestigation(value)?.stage === 'revise'
                ? ['artifact', 'plot', 'result']
                : []),
            ]
          : [
              'question',
              ...(active?.diagram ? ['diagram'] : []),
              ...(active?.interactive ? ['artifact'] : []),
              ...(active?.interactive && controllableParameters[active.interactive.kind]
                ? [
                    'plot',
                    'parameters',
                    'result',
                    ...controllableParameters[active.interactive.kind].map(
                      (name) => `parameter:${name}`,
                    ),
                  ]
                : []),
            ],
      });
    },
    guideCanvas: (command) => {
      selected(command.activityId);
      return guideCanvas(command);
    },
    controlArtifact: async (command) => {
      const active = selected(command.activityId);
      if (!active.interactive)
        throw new Error('The selected activity has no interactive artifact.');
      const state = getLiveInteractive(active.id) ?? current.current.interactiveStates[active.id];
      const before =
        command.action === 'set_parameter' && state
          ? Reflect.get(state, command.parameter)
          : undefined;
      const result = controlArtifact(command);
      if (command.action === 'set_parameter' && typeof before === 'number') {
        const target = `parameter:${command.parameter}` as Extract<
          GuidanceCommand,
          { action: 'point' | 'highlight' }
        >['target'];
        await guideCanvas(
          {
            action: 'point',
            activityId: active.id,
            target,
            label: `${command.parameter}: ${before} → ${command.value}`,
          },
          {
            parameter: command.parameter,
            before,
            after: command.value,
            restarted: state?.kind === 'queue',
          },
        );
      }
      return result;
    },
    activity: async (request, attempt) => {
      if (isInvestigation(current.current.selectedActivityId))
        return 'Use the guided investigation stage tools for this activity.';
      if (attempt)
        return send.current(request, {
          attempt,
          assisted: true,
          inputChannel: 'voice',
          presentation: 'defer',
        });
      if (preparing)
        return 'A view is already being prepared. Continue the discussion without claiming it is ready.';
      preparing = true;
      void send
        .current(request, { inputChannel: 'voice', presentation: 'defer' })
        .catch((failure: Error) => error(failure.message))
        .finally(() => {
          preparing = false;
        });
      return 'View preparation started in the background. It is not ready yet. Continue listening or discussing the current idea; inspect before describing the result. Presentation waits for a quiet pause and respects Hold view.';
    },
  };
}
