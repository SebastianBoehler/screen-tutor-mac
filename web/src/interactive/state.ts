import type { InteractiveSpec } from './schema';
import { createQueue, queueSummary, type QueueState } from './queueEngine';
import { loss, survivalProbability } from './mathematics';

export type InteractiveState =
  | { kind: 'exponential'; rate: number; time: number; explored: boolean }
  | {
      kind: 'gradient-descent';
      position: number;
      learningRate: number;
      trail: number[];
      explored: boolean;
    }
  | {
      kind: 'queue';
      arrivalRate: number;
      serviceRate: number;
      simulation: QueueState;
      explored: boolean;
    };

export function initialInteractiveState(spec: InteractiveSpec): InteractiveState {
  switch (spec.kind) {
    case 'exponential':
      return { kind: spec.kind, rate: spec.rate, time: spec.time, explored: false };
    case 'gradient-descent':
      return {
        kind: spec.kind,
        position: spec.position,
        learningRate: spec.learningRate,
        trail: [spec.position],
        explored: false,
      };
    case 'queue':
      return {
        kind: spec.kind,
        arrivalRate: spec.arrivalRate,
        serviceRate: spec.serviceRate,
        simulation: createQueue(spec.arrivalRate, spec.serviceRate),
        explored: false,
      };
  }
}
// Read-through session state lets a tutor inspect a running simulation before the next checkpoint.
const liveStates = new Map<string, InteractiveState>();
export const setLiveInteractive = (id: string, value: InteractiveState) =>
  liveStates.set(id, value);
export const clearLiveInteractive = (id: string) => liveStates.delete(id);
export const getLiveInteractive = (id: string) => liveStates.get(id);
export function summarizeInteractive(state: InteractiveState): string {
  switch (state.kind) {
    case 'exponential':
      return JSON.stringify({
        model: state.kind,
        rate: state.rate,
        time: state.time,
        probability: survivalProbability(state.rate, state.time),
        explored: state.explored,
      });
    case 'gradient-descent':
      return JSON.stringify({
        model: state.kind,
        position: state.position,
        learningRate: state.learningRate,
        loss: loss(state.position),
        steps: state.trail.length - 1,
        explored: state.explored,
      });
    case 'queue':
      return JSON.stringify({
        model: 'M/M/1; rates per minute; finite run initially empty',
        arrivalRate: state.arrivalRate,
        serviceRate: state.serviceRate,
        ...queueSummary(state.simulation, state.arrivalRate, state.serviceRate),
        explored: state.explored,
      });
  }
}
