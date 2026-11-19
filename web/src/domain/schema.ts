import { z } from 'zod';
import { interactiveSchema } from '../interactive/schema';

const short = z.string().max(240);
const diagramSchema = z.object({
  nodes: z
    .array(z.object({ label: short, detail: z.string().max(500) }))
    .min(2)
    .max(5),
  links: z
    .array(
      z.object({
        from: z.number().int().min(0).max(4),
        to: z.number().int().min(0).max(4),
        label: short,
      }),
    )
    .max(6),
});

export const activitySchema = z.object({
  title: short,
  concept: short,
  body: z.string().max(7000),
  question: z.string().min(1).max(1500),
  choices: z.array(short).max(5),
  answer: z.string().max(3000),
  hint: z.string().max(1000),
  explanation: z.string().max(3000),
  diagram: diagramSchema.nullable(),
  interactive: interactiveSchema.nullable(),
  sourceIds: z.array(z.string().max(120)).max(8),
});

export const replySchema = z.object({
  message: z.string().min(1).max(4000),
  activity: activitySchema.nullable(),
  assessment: z.object({
    verdict: z.enum(['correct', 'partial', 'incorrect', 'ungraded']),
    feedback: z.string().max(2500),
  }),
  memory: z.string().max(700).nullable(),
});
export type ActivityContent = z.infer<typeof activitySchema>;
export type TutorReply = z.infer<typeof replySchema>;
export type Verdict = TutorReply['assessment']['verdict'];

export const contextSchema = z.object({
  course: z.string().max(240),
  goal: z.string().max(1000),
  mode: z.enum(['learn', 'exam']),
  sources: z
    .array(
      z.object({
        id: z.string().max(120),
        label: short,
        text: z.string().max(5000),
      }),
    )
    .max(8),
  memories: z.array(z.string().max(1000)).max(12),
  evidence: z.string().max(3000),
  activity: activitySchema.nullable(),
  activityId: z.string().max(120).nullable(),
  assisted: z.boolean(),
  revealed: z.boolean(),
  exploration: z.string().max(2400).nullable(),
});
export type TutorContext = z.infer<typeof contextSchema>;
export const tutorRequestSchema = z.object({
  provider: z.enum(['openai', 'openrouter']),
  context: contextSchema,
  messages: z
    .array(
      z.object({
        role: z.enum(['user', 'assistant']),
        content: z.string().min(1).max(8000),
      }),
    )
    .min(1)
    .max(16),
  image: z
    .string()
    .max(700_000)
    .regex(/^data:image\/jpeg;base64,[A-Za-z0-9+/=]+$/)
    .optional(),
});
export type TutorRequest = z.infer<typeof tutorRequestSchema>;
