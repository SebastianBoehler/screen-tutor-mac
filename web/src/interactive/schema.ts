import { z } from 'zod';

/** Only compiled teaching models run. Provider data cannot supply code or URLs. */
export const interactiveSchema = z.discriminatedUnion('kind', [
  z
    .object({
      kind: z.literal('flashcard'),
      front: z.string().min(1).max(500),
      back: z.string().min(1).max(1000),
    })
    .strict(),
  z
    .object({
      kind: z.literal('fill-blank'),
      before: z.string().max(500),
      after: z.string().max(500),
      answer: z.string().min(1).max(120),
    })
    .strict(),
  z
    .object({
      kind: z.literal('linear'),
      slope: z.number().min(-5).max(5).multipleOf(0.1),
      intercept: z.number().min(-5).max(5).multipleOf(0.1),
    })
    .strict(),
  z
    .object({
      kind: z.literal('exponential'),
      rate: z.number().min(0.1).max(8).multipleOf(0.1),
      time: z.number().min(0).max(10).multipleOf(0.1),
      unit: z.enum(['seconds', 'minutes']),
    })
    .strict(),
  z
    .object({
      kind: z.literal('gradient-descent'),
      position: z.number().min(-4).max(4).multipleOf(0.1),
      learningRate: z.number().min(0.01).max(1.2).multipleOf(0.01),
    })
    .strict(),
  z
    .object({
      kind: z.literal('queue'),
      arrivalRate: z.number().min(0.25).max(20).multipleOf(0.25),
      serviceRate: z.number().min(0.25).max(20).multipleOf(0.25),
    })
    .strict(),
]);
export type InteractiveSpec = z.infer<typeof interactiveSchema>;
