import { useEffect, useRef, type RefObject } from 'react';
import type { Workspace } from '../domain/models';
import { canPresent, presentView, setCanvasHeld } from './pacing';

type Update = (change: (value: Workspace) => Workspace) => void;
export function useCanvasPacing(
  workspace: Workspace,
  current: RefObject<Workspace>,
  update: Update,
  enabled: boolean,
) {
  const timing = useRef({
    visibleAt: performance.now(),
    quietAt: performance.now(),
    speaking: false,
    dragging: false,
  });
  useEffect(() => {
    timing.current.visibleAt = performance.now();
  }, [workspace.selectedActivityId, workspace.canvas?.presentedAt, enabled]);
  useEffect(() => {
    const inside = (event: Event) =>
      event.target instanceof Element && !!event.target.closest('.main-content');
    const touch = (event: Event) => {
      if (inside(event)) timing.current.quietAt = performance.now();
    };
    const down = (event: Event) => {
      if (inside(event)) {
        timing.current.dragging = true;
        touch(event);
      }
    };
    const up = () => {
      timing.current.dragging = false;
      timing.current.quietAt = performance.now();
    };
    const focus = () => {
      timing.current.quietAt = performance.now();
    };
    document.addEventListener('pointerdown', down);
    document.addEventListener('pointerup', up);
    document.addEventListener('pointercancel', up);
    document.addEventListener('focusin', focus);
    const blur = () => queueMicrotask(focus);
    document.addEventListener('focusout', blur);
    document.addEventListener('input', touch);
    document.addEventListener('wheel', touch, { passive: true });
    return () => {
      document.removeEventListener('pointerdown', down);
      document.removeEventListener('pointerup', up);
      document.removeEventListener('pointercancel', up);
      document.removeEventListener('focusin', focus);
      document.removeEventListener('focusout', blur);
      document.removeEventListener('input', touch);
      document.removeEventListener('wheel', touch);
    };
  }, []);
  const pending = workspace.canvas?.pendingActivityIds.find((id) =>
    workspace.activities.some(
      (item) => item.id === id && item.courseId === workspace.selectedCourseId,
    ),
  );
  useEffect(() => {
    if (!enabled || !pending) return;
    const timer = setInterval(() => {
      const now = performance.now(),
        time = timing.current;
      const focused = document.activeElement;
      const editing =
        focused instanceof HTMLElement &&
        !!focused.closest('.main-content, .composer') &&
        (focused.isContentEditable ||
          focused instanceof HTMLTextAreaElement ||
          (focused instanceof HTMLInputElement &&
            ['text', 'search', 'email', 'url', 'tel', 'number'].includes(focused.type))) &&
        ('value' in focused ? !!String(focused.value).trim() : !!focused.textContent?.trim());
      if (document.hidden || document.getSelection()?.isCollapsed === false) return;
      if (
        canPresent({
          held: !!current.current.canvas?.held,
          speaking: time.speaking,
          interacting: time.dragging || editing,
          visibleFor: now - time.visibleAt,
          quietFor: now - time.quietAt,
        })
      )
        update((value) => presentView(value, pending));
    }, 200);
    return () => clearInterval(timer);
  }, [enabled, pending, current, update]);
  return {
    held: !!workspace.canvas?.held,
    pending: workspace.activities.find((item) => item.id === pending),
    hold: (held: boolean) => update((value) => setCanvasHeld(value, held)),
    show: () => {
      if (pending) update((value) => presentView(value, pending));
    },
    turn: (speaking: boolean) => {
      timing.current.speaking = speaking;
      timing.current.quietAt = performance.now();
    },
  };
}
