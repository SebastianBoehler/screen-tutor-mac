import { useCallback, useEffect, useRef, useState } from 'react';
import { emptyWorkspace, type Workspace } from '../domain/models';
import { loadWorkspace, saveWorkspace } from './storage';

export function useWorkspace() {
  const [workspace, setWorkspace] = useState<Workspace>(emptyWorkspace);
  const current = useRef(workspace);
  const queue = useRef(Promise.resolve());
  const [ready, setReady] = useState(false);
  const [storageError, setStorageError] = useState('');
  const [saving, setSaving] = useState(false);
  useEffect(() => {
    let active = true;
    loadWorkspace()
      .then((value) => {
        if (active) {
          current.current = value;
          setWorkspace(value);
          setReady(true);
        }
      })
      .catch((error) => {
        if (active) setStorageError(error.message);
      });
    return () => {
      active = false;
    };
  }, []);
  const update = useCallback((change: (value: Workspace) => Workspace) => {
    const value = change(current.current);
    current.current = value;
    setWorkspace(value);
    setSaving(true);
    queue.current = queue.current
      .catch(() => {})
      .then(() => saveWorkspace(value))
      .then(() => {
        if (current.current === value) {
          setStorageError('');
          setSaving(false);
        }
      })
      .catch((error) => {
        setStorageError(error.message);
        setSaving(false);
      });
  }, []);
  useEffect(() => {
    const warn = (event: BeforeUnloadEvent) => {
      if (saving || storageError) event.preventDefault();
    };
    window.addEventListener('beforeunload', warn);
    return () => window.removeEventListener('beforeunload', warn);
  }, [saving, storageError]);
  return { workspace, current, update, ready, storageError, saving };
}
