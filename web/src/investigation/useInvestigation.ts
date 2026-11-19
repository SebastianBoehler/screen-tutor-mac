import { useEffect, useRef, type RefObject } from 'react';
import { queueView } from '../canvas/pacing';
import type { Workspace } from '../domain/models';
import {
  getInvestigation,
  investigationContext,
  investigationId,
  isInvestigation,
  type Submission,
} from './model';
import {
  giveInvestigationHint,
  openInvestigation,
  submitInvestigation,
  updateExperiment,
} from './workspace';
import type { QueueComparison } from './experiment';

type Update = (change: (value: Workspace) => Workspace) => void;
export function useInvestigation(
  workspace: Workspace,
  current: RefObject<Workspace>,
  update: Update,
  ready: boolean,
  voiceConnected = false,
) {
  const voiceMode = useRef(voiceConnected);
  voiceMode.current = voiceConnected;
  const state = getInvestigation(workspace);
  const job = state?.experiment;
  const executing = job?.status === 'queued' || job?.status === 'running';
  useEffect(() => {
    if (!ready || !job || !executing) return;
    const id = job.id;
    let active = true;
    let worker: Worker | undefined;
    let timeout: ReturnType<typeof setTimeout> | undefined;
    const finish = (result: { result?: QueueComparison; error?: string }) => {
      if (!active) return;
      active = false;
      clearTimeout(timeout);
      worker?.terminate();
      update((value) => {
        const next = updateExperiment(
          value,
          id,
          result.result
            ? { status: 'ready', result: result.result }
            : { status: 'failed', error: result.error || 'The experiment returned no result.' },
        );
        return next !== value &&
          result.result &&
          value.selectedActivityId === investigationId &&
          (voiceMode.current || value.canvas?.held)
          ? queueView(next, investigationId)
          : next;
      });
    };
    try {
      worker = new Worker(new URL('./experiment.worker.ts', import.meta.url), { type: 'module' });
      worker.onmessage = (event: MessageEvent<{ result?: QueueComparison; error?: string }>) =>
        finish(event.data);
      worker.onerror = () =>
        finish({ error: 'The experiment worker failed. Retry the comparison.' });
      timeout = setTimeout(
        () => finish({ error: 'The experiment timed out. Retry the comparison.' }),
        15_000,
      );
      update((value) => updateExperiment(value, id, { status: 'running' }));
      worker.postMessage({ id });
    } catch (error) {
      finish({ error: error instanceof Error ? error.message : 'The experiment could not start.' });
    }
    return () => {
      active = false;
      clearTimeout(timeout);
      worker?.terminate();
    };
    // Running is persisted, but changing queued to running must not restart this worker.
  }, [ready, job?.id, executing, update]);
  return {
    active: isInvestigation(workspace.selectedActivityId),
    state,
    open: () => update(openInvestigation),
    submit: (input: Submission) => update((value) => submitInvestigation(value, input)),
    hint: () => update(giveInvestigationHint),
    control: (status: 'queued' | 'cancelled') => {
      const activeJob = getInvestigation(current.current)?.experiment;
      if (activeJob) update((value) => updateExperiment(value, activeJob.id, { status }));
    },
    voice: (input: Submission | 'hint') => {
      if (!isInvestigation(current.current.selectedActivityId))
        throw new Error('Open the guided investigation first.');
      update((value) =>
        input === 'hint' ? giveInvestigationHint(value) : submitInvestigation(value, input),
      );
      return investigationContext(current.current)!;
    },
  };
}
