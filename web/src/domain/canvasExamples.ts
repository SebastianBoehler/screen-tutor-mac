import { now, uid, type Workspace } from './models';
import { exampleContent, isCanvasExample, queueExampleId } from './exampleContent';

const courseName = 'Modellierung und Simulation';

export function openCanvasExample(workspace: Workspace, id = queueExampleId): Workspace {
  const example = exampleContent.find((item) => item.id === id);
  if (!example) throw new Error('This canvas example is not available.');
  const existing = workspace.activities.find((item) => item.id === id);
  if (existing)
    return { ...workspace, selectedCourseId: existing.courseId, selectedActivityId: existing.id };
  const course = workspace.courses.find((item) => item.name.trim() === courseName) ?? {
    id: uid(),
    name: courseName,
    goal: 'Understand models and simulation through interactive exploration.',
    examDate: '',
  };
  return {
    ...workspace,
    courses: workspace.courses.some((item) => item.id === course.id)
      ? workspace.courses
      : [...workspace.courses, course],
    activities: [
      ...workspace.activities,
      {
        ...example.content,
        id,
        courseId: course.id,
        createdAt: now(),
        mode: 'learn',
      },
    ],
    interactions: [
      ...workspace.interactions,
      {
        id: uid(),
        courseId: course.id,
        activityId: id,
        at: now(),
        kind: 'explore',
        text: `Opened illustrative example: ${example.label}.`,
        verdict: 'ungraded',
        assisted: true,
      },
    ],
    selectedCourseId: course.id,
    selectedActivityId: id,
  };
}

export function prefillEmptyCanvas(workspace: Workspace): Workspace {
  const active = workspace.activities.some(
    (item) =>
      item.id === workspace.selectedActivityId &&
      item.courseId === workspace.selectedCourseId &&
      workspace.courses.some((course) => course.id === item.courseId),
  );
  return active ? workspace : openCanvasExample(workspace);
}

export function saveExampleReasoning(workspace: Workspace): Workspace {
  const activity = workspace.activities.find((item) => item.id === workspace.selectedActivityId);
  const text = activity && workspace.drafts[activity.id]?.trim();
  if (!activity || !isCanvasExample(activity.id) || !text) return workspace;
  return {
    ...workspace,
    interactions: [
      ...workspace.interactions,
      {
        id: uid(),
        courseId: activity.courseId,
        activityId: activity.id,
        at: now(),
        kind: 'attempt',
        text,
        verdict: 'ungraded',
        assisted: true,
      },
    ],
  };
}
