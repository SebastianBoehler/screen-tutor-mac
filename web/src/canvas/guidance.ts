import { z } from 'zod';

export const cueTargets = [
  'artifact',
  'plot',
  'parameters',
  'result',
  'question',
  'diagram',
  'parameter:slope',
  'parameter:intercept',
  'parameter:rate',
  'parameter:time',
  'parameter:learningRate',
  'parameter:arrivalRate',
  'parameter:serviceRate',
] as const;
export const guidanceSchema = z.discriminatedUnion('action', [
  z.object({ action: z.literal('clear'), activityId: z.string().min(1).max(120) }).strict(),
  z
    .object({
      action: z.enum(['point', 'highlight']),
      activityId: z.string().min(1).max(120),
      target: z.enum(cueTargets),
      label: z.string().trim().min(1).max(80),
    })
    .strict(),
]);
export const holdCanvasSchema = z.object({ held: z.boolean() }).strict();
export type GuidanceCommand = z.infer<typeof guidanceSchema>;
export type CanvasChange = { parameter: string; before: number; after: number; restarted: boolean };
const guides = new Map<
  string,
  (command: GuidanceCommand, change?: CanvasChange) => Promise<string>
>();
export function registerCanvasGuide(
  id: string,
  handler: (command: GuidanceCommand, change?: CanvasChange) => Promise<string>,
) {
  guides.set(id, handler);
  return () => {
    if (guides.get(id) === handler) guides.delete(id);
  };
}
export function guideCanvas(command: GuidanceCommand, change?: CanvasChange) {
  const handler = guides.get(command.activityId);
  if (!handler) throw new Error('This activity is not available for canvas guidance.');
  return handler(command, change);
}
