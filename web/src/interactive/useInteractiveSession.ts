import { useEffect, useRef, useState } from 'react';
import type { InteractiveSpec } from './schema';
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
) {
  const [state, setState] = useState(() => saved ?? (spec ? initialInteractiveState(spec) : null));
  const current = useRef(state);
  const dirty = useRef(false);
  const callbacks = useRef({ onSave, onExplore });
  callbacks.current = { onSave, onExplore };
  const flush = () => {
    if (dirty.current && current.current) {
      dirty.current = false;
      callbacks.current.onSave(current.current);
    }
  };
  useEffect(() => {
    if (current.current) setLiveInteractive(id, current.current);
    // Rendering runs locally at interaction speed; durable checkpoints are bounded to once/second.
    const timer = setInterval(flush, 1000);
    const hide = () => {
      if (document.hidden) flush();
    };
    document.addEventListener('visibilitychange', hide);
    return () => {
      clearInterval(timer);
      flush();
      clearLiveInteractive(id);
      document.removeEventListener('visibilitychange', hide);
    };
  }, [id]);
  const change = (value: InteractiveState) => {
    const explored = { ...value, explored: true };
    if (!current.current?.explored) callbacks.current.onExplore();
    current.current = explored;
    dirty.current = true;
    setLiveInteractive(id, explored);
    setState(explored);
  };
  return { state, change, flush };
}
