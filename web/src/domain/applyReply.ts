import { now, uid, type Workspace } from './models';
import type { TutorReply } from './schema';

export function applyReply(
  workspace: Workspace,
  reply: TutorReply,
  courseId: string,
  attemptId?: string,
): Workspace {
  const attempt = workspace.interactions.find((item) => item.id === attemptId);
  const active = workspace.activities.find((item) => item.id === attempt?.activityId);
  // Exam attempts stay ungraded until the learner explicitly requests review in conversation.
  const grade =
    attempt && (active?.mode !== 'exam' || !!active.reviewedAt)
      ? reply.assessment.verdict
      : 'ungraded';
  const activity = reply.activity
    ? {
        ...reply.activity,
        id: uid(),
        courseId,
        createdAt: now(),
        mode: active?.mode ?? ('learn' as const),
      }
    : null;
  return {
    ...workspace,
    activities: activity ? [...workspace.activities, activity] : workspace.activities,
    selectedActivityId: activity?.id ?? workspace.selectedActivityId,
    messages: [
      ...workspace.messages,
      {
        id: uid(),
        courseId,
        role: 'assistant',
        content:
          attempt &&
          (active?.mode !== 'exam' || !!active.reviewedAt) &&
          reply.assessment.feedback &&
          reply.assessment.feedback !== reply.message
            ? `${reply.message}\n\n${reply.assessment.feedback}`
            : reply.message,
      },
    ],
    interactions: workspace.interactions.map((item) =>
      item.id === attemptId ? { ...item, verdict: grade } : item,
    ),
    memories:
      reply.memory && attempt
        ? [
            ...workspace.memories,
            {
              id: uid(),
              courseId,
              text: reply.memory,
              evidenceId: attempt.id,
              updatedAt: now(),
            },
          ]
        : workspace.memories,
  };
}
