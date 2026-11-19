import { z } from 'zod';

const voiceSubmission = z
  .object({
    stage: z.enum(['explain', 'predict', 'revise', 'apply']),
    text: z.string().trim().min(1).max(1200),
    choice: z.enum(['yes', 'no']).optional(),
  })
  .strict();
export function parseVoiceSubmission(value: unknown) {
  const parsed = voiceSubmission.safeParse(value);
  if (!parsed.success)
    throw new Error(
      'Provide the current stage and the learner’s own explanation (1–1,200 characters).',
    );
  return { ...parsed.data, medium: 'voice' as const };
}
