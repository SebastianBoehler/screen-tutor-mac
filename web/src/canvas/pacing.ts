import { now, type Workspace } from '../domain/models';

export interface CanvasPacing {
  held: boolean;
  pendingActivityIds: string[];
  presentedAt?: string;
}
// UX guardrails, not a measure of comprehension. Hold view has no time limit.
export function canPresent(state: {
  held: boolean;
  speaking: boolean;
  interacting: boolean;
  visibleFor: number;
  quietFor: number;
}) {
  return (
    !state.held &&
    !state.speaking &&
    !state.interacting &&
    state.visibleFor >= 8000 &&
    state.quietFor >= 1200
  );
}
export function setCanvasHeld(workspace: Workspace, held: boolean): Workspace {
  return {
    ...workspace,
    canvas: {
      ...workspace.canvas,
      held,
      pendingActivityIds: workspace.canvas?.pendingActivityIds ?? [],
    },
  };
}
export function presentView(workspace: Workspace, id: string): Workspace {
  if (
    !workspace.canvas?.pendingActivityIds.includes(id) ||
    !workspace.activities.some(
      (item) => item.id === id && item.courseId === workspace.selectedCourseId,
    )
  )
    return workspace;
  return {
    ...workspace,
    selectedActivityId: id,
    canvas: {
      ...workspace.canvas,
      presentedAt: now(),
      pendingActivityIds: workspace.canvas.pendingActivityIds.filter((item) => item !== id),
    },
  };
}

export function queueView(workspace: Workspace, id: string): Workspace {
  if (workspace.canvas?.pendingActivityIds.includes(id)) return workspace;
  return {
    ...workspace,
    canvas: {
      ...workspace.canvas,
      held: !!workspace.canvas?.held,
      pendingActivityIds: [...(workspace.canvas?.pendingActivityIds ?? []), id],
    },
  };
}
