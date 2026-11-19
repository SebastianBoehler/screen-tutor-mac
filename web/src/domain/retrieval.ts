import type { Material, Workspace } from './models';
import type { TutorContext } from './schema';
import { presentedInvestigation, investigationContext, prompts } from '../investigation/model';
import { getLiveInteractive, summarizeInteractive } from '../interactive/state';

const terms = (text: string) => [
  ...new Set(text.toLocaleLowerCase().match(/[\p{L}\p{N}]{3,}/gu) ?? []),
];
export function retrieve(materials: Material[], query: string): TutorContext['sources'] {
  const words = terms(query);
  const chunks = materials.flatMap((material) =>
    material.pages.flatMap((page) => {
      const result = [];
      for (let start = 0; start < page.text.length; start += 1800) {
        const text = page.text.slice(start, start + 2200);
        const lower = text.toLocaleLowerCase();
        result.push({
          id: `${material.id}:${page.number}:${start}`,
          label: `${material.name} · p. ${page.number}${material.kind === 'lecture-note' ? ' · learner-authored lecture note' : ' · imported document'}`,
          text,
          score: words.reduce((sum, word) => sum + (lower.includes(word) ? 1 : 0), 0),
        });
      }
      return result;
    }),
  );
  return chunks
    .sort((a, b) => b.score - a.score)
    .slice(0, 6)
    .map(({ score: _, ...source }) => source);
}

export function studyContext(
  workspace: Workspace,
  query: string,
  mode: 'learn' | 'exam',
): TutorContext {
  const course = workspace.courses.find((item) => item.id === workspace.selectedCourseId);
  if (!course) throw new Error('Choose a course before starting a lesson.');
  const activity = workspace.activities.find(
    (item) => item.id === workspace.selectedActivityId && item.courseId === course.id,
  );
  const events = workspace.interactions.filter((item) => item.activityId === activity?.id);
  const exploration = activity
    ? (getLiveInteractive(activity.id) ?? workspace.interactiveStates[activity.id])
    : undefined;
  const investigation = investigationContext(workspace);
  const guided = investigation ? presentedInvestigation(workspace) : undefined;
  return {
    course: course.name,
    goal: course.goal,
    mode,
    sources: retrieve(
      workspace.materials.filter((item) => item.courseId === course.id),
      `${query} ${course.goal} ${activity?.concept ?? ''}`,
    ),
    memories: workspace.memories
      .filter((item) => item.courseId === course.id)
      .slice(-8)
      .map((item) => item.text),
    evidence: workspace.interactions
      .filter((item) => item.courseId === course.id)
      .slice(-12)
      .map(
        (item) =>
          `${item.kind}: ${item.verdict}; assisted=${item.assisted}; ${item.text.slice(0, 160)}`,
      )
      .join('\n'),
    activity:
      activity && guided ? { ...activity, question: prompts[guided.stage] } : (activity ?? null),
    activityId: activity?.id ?? null,
    assisted: events.some((item) => item.assisted || item.kind !== 'attempt'),
    revealed: events.some((item) => item.kind === 'reveal'),
    exploration: investigation ?? (exploration ? summarizeInteractive(exploration) : null),
  };
}
