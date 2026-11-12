// Messages on the "study" data topic between the tutor agent and room clients.
// Keep in sync with room/agent/protocol.py.

export const STUDY_TOPIC = "study";
export const AGENT_NAME = "study-tutor";

export type Board = { title: string; markdown: string; updatedAt: number };

export type StudyTask = {
  id: string;
  assignee: string; // participant identity, or "everyone"
  assigneeName: string;
  title: string;
  task: string;
  status: "active" | "independent" | "assisted" | "abandoned";
};

export type DeskStatus = {
  identity: string;
  name: string;
  progress: string;
  summary: string;
  issue?: string | null;
  updatedAt: number;
};

export type AgentMessage =
  | { type: "board"; board: Board | null }
  | { type: "tasks"; tasks: StudyTask[] }
  | { type: "desks"; desks: DeskStatus[] }
  | { type: "status"; text: string };

export type ClientMessage = { type: "sync_request" };

export function isValidRoomCode(code: string): boolean {
  return /^[a-z0-9][a-z0-9-]{2,39}$/.test(code);
}
