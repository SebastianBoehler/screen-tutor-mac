import { z } from 'zod';
import { interactiveSchema, type InteractiveSpec } from './schema';
import { createQueue } from './queueEngine';
import type { InteractiveState } from './state';

export const controlSchema = z.discriminatedUnion('action', [
  z
    .object({ action: z.literal('reveal_flashcard'), activityId: z.string().min(1).max(120) })
    .strict(),
  z
    .object({
      action: z.literal('set_parameter'),
      activityId: z.string().min(1).max(120),
      parameter: z.string().min(1).max(40),
      value: z.number().finite(),
    })
    .strict(),
]);
export type ArtifactControl = z.infer<typeof controlSchema>;

export const controllableParameters: Record<string, string[]> = {
  linear: ['slope', 'intercept'],
  exponential: ['rate', 'time'],
  'gradient-descent': ['learningRate'],
  queue: ['arrivalRate', 'serviceRate'],
};

export function applyArtifactControl(
  spec: InteractiveSpec,
  state: InteractiveState,
  command: ArtifactControl,
): InteractiveState {
  if (command.action === 'reveal_flashcard') {
    if (spec.kind !== 'flashcard' || state.kind !== 'flashcard')
      throw new Error('The selected artifact is not a flashcard.');
    return { ...state, revealed: true, explored: true };
  }

  if (spec.kind !== state.kind || !controllableParameters[state.kind]?.includes(command.parameter))
    throw new Error('That parameter is not available on the selected artifact.');
  const updatedSpec = interactiveSchema.safeParse({ ...spec, [command.parameter]: command.value });
  if (!updatedSpec.success)
    throw new Error('The value is outside the parameter range or increment.');
  if (state.kind === 'queue') {
    const arrivalRate = command.parameter === 'arrivalRate' ? command.value : state.arrivalRate;
    const serviceRate = command.parameter === 'serviceRate' ? command.value : state.serviceRate;
    return {
      ...state,
      arrivalRate,
      serviceRate,
      simulation: createQueue(arrivalRate, serviceRate),
      explored: true,
    };
  }
  return { ...state, [command.parameter]: command.value, explored: true } as InteractiveState;
}

const controls = new Map<string, (command: ArtifactControl) => string>();
export function registerArtifactControl(id: string, handler: (command: ArtifactControl) => string) {
  controls.set(id, handler);
  return () => {
    if (controls.get(id) === handler) controls.delete(id);
  };
}
export function controlArtifact(command: ArtifactControl) {
  const handler = controls.get(command.activityId);
  if (!handler) throw new Error('The selected artifact is not available in the canvas.');
  return handler(command);
}
