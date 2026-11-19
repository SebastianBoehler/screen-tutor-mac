import { useEffect, useRef, useState } from 'react';
import type { InteractiveSpec } from './schema';
import { applyArtifactControl, registerArtifactControl } from './control';
import {
  clearLiveInteractive,
  initialInteractiveState,
  setLiveInteractive,
  type InteractiveState,
} from './state';

export function useInteractiveSession(
  id: string,
  spec: InteractiveSpec | null,
  saved: InteractiveState | undefined,
  onSave: (value: InteractiveState) => void,
  onExplore: () => void,
  active: boolean,
) {
  const [state, setState] = useState(() => saved ?? (spec ? initialInteractiveState(spec) : null));
  const current = useRef(state);
  const dirty = useRef(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const callbacks = useRef({ onSave, onExplore });
  callbacks.current = { onSave, onExplore };
  const flush = () => {
    if (timer.current) clearTimeout(timer.current);
    timer.current = null;
    if (dirty.current && current.current) {
      dirty.current = false;
      callbacks.current.onSave(current.current);
    }
  };
  useEffect(() => {
    if (!active) flush();
  }, [active]);
  useEffect(() => {
    if (current.current) setLiveInteractive(id, current.current);
    const hide = () => {
      if (document.hidden) flush();
    };
    document.addEventListener('visibilitychange', hide);
    return () => {
      flush();
      clearLiveInteractive(id);
      document.removeEventListener('visibilitychange', hide);
    };
  }, [id]);
  useEffect(() => {
    if (!spec) return;
    return registerArtifactControl(id, (command) => {
      if (!current.current) throw new Error('The artifact is unavailable.');
      const next = applyArtifactControl(spec, current.current, command);
      if (!current.current.explored) callbacks.current.onExplore();
      current.current = next;
      dirty.current = false;
      setLiveInteractive(id, next);
      setState(next);
      callbacks.current.onSave(next);
      window.dispatchEvent(new CustomEvent('screentutor:open-artifact', { detail: id }));
      return JSON.stringify({ activityId: id, state: next });
    });
  }, [id, spec]);
  const change = (value: InteractiveState) => {
    const explored = { ...value, explored: true };
    if (!current.current?.explored) callbacks.current.onExplore();
    current.current = explored;
    dirty.current = true;
    if (!timer.current) timer.current = setTimeout(flush, 1000);
    setLiveInteractive(id, explored);
    setState(explored);
  };
  return { state, change, flush };
}
