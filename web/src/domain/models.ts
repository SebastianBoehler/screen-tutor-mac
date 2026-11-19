import type { ActivityContent, Verdict } from './schema';
import type { Investigation } from '../investigation/model';
import type { CanvasPacing } from '../canvas/pacing';
import type { InteractiveState } from '../interactive/state';

export interface Course {
  id: string;
  name: string;
  goal: string;
  examDate: string;
}
export interface Material {
  id: string;
  courseId: string;
  name: string;
  hash: string;
  kind: 'document' | 'lecture-note';
  createdAt: string;
  pages: { number: number; text: string }[];
}
export interface Activity extends ActivityContent {
  id: string;
  courseId: string;
  createdAt: string;
  mode: 'learn' | 'exam';
  reviewedAt?: string;
}
export interface Interaction {
  id: string;
  courseId: string;
  activityId: string;
  at: string;
  kind: 'attempt' | 'hint' | 'reveal' | 'explore';
  text: string;
  verdict: Verdict;
  assisted: boolean;
}
export interface Message {
  id: string;
  courseId: string;
  role: 'user' | 'assistant';
  content: string;
}
export interface Memory {
  id: string;
  courseId: string;
  text: string;
  evidenceId: string;
  updatedAt: string;
}
export interface Settings {
  dailyMinutes: number;
  restStart: string;
  restEnd: string;
}
export interface Workspace {
  version: 3;
  courses: Course[];
  materials: Material[];
  activities: Activity[];
  interactions: Interaction[];
  messages: Message[];
  memories: Memory[];
  selectedCourseId: string | null;
  selectedActivityId: string | null;
  drafts: Record<string, string>;
  interactiveStates: Record<string, InteractiveState>;
  investigations: Record<string, Investigation>;
  canvas?: CanvasPacing;
  settings: Settings;
}
export const emptyWorkspace = (): Workspace => ({
  version: 3,
  courses: [],
  materials: [],
  activities: [],
  interactions: [],
  messages: [],
  memories: [],
  selectedCourseId: null,
  selectedActivityId: null,
  drafts: {},
  interactiveStates: {},
  investigations: {},
  settings: { dailyMinutes: 30, restStart: '22:00', restEnd: '08:00' },
});
export const uid = () => crypto.randomUUID();
export const now = () => new Date().toISOString();
