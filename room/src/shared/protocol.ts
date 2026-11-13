// Wire protocol between room clients and the room server (one WebSocket per participant).
// JSON text frames carry everything below; binary frames carry audio:
//   client -> server: microphone, 24 kHz mono PCM16 little-endian
//   server -> client: tutor voice, same format

export const SAMPLE_RATE = 24_000;
/** 40 ms of audio per binary frame. */
export const FRAME_SAMPLES = 960;
export const MAX_PARTICIPANTS = 6;

export type Board = { title: string; markdown: string; updatedAt: number };

export type TaskOutcome = "active" | "independent" | "assisted" | "abandoned";

export type StudyTask = {
  id: string;
  assignee: string; // participant id, or "everyone"
  assigneeName: string;
  title: string;
  task: string;
  status: TaskOutcome;
};

export type DeskStatus = {
  id: string;
  name: string;
  progress: string;
  summary: string;
  issue: string | null;
  updatedAt: number;
};

export type Peer = { id: string; name: string };

export type TutorState = "offline" | "connecting" | "listening" | "thinking" | "speaking";

export type RoomState = {
  peers: Peer[];
  board: Board | null;
  tasks: StudyTask[];
  desks: DeskStatus[];
  tutor: { state: TutorState; detail: string };
};

export type Caption = { speaker: string; text: string; final: boolean; role: "learner" | "tutor" };

export type SignalData =
  | { description: RTCSessionDescriptionInit }
  | { candidate: RTCIceCandidateInit | null };

export type ServerMessage =
  | { type: "welcome"; id: string; iceServers: RTCIceServer[]; state: RoomState }
  | { type: "state"; state: RoomState }
  | { type: "peer_joined"; peer: Peer }
  | { type: "peer_left"; id: string }
  | { type: "signal"; from: string; data: SignalData }
  | { type: "caption"; caption: Caption }
  | { type: "tutor_audio_clear" }
  | { type: "desk_snapshot_request"; requestId: string }
  | { type: "error"; message: string };

export type DeskReason = "first_look" | "page_changed" | "no_visible_progress";

export type ClientMessage =
  | { type: "join"; name: string }
  | { type: "signal"; to: string; data: SignalData }
  | { type: "desk_frame"; reason: DeskReason; jpeg: string; secondsWithoutChange: number | null }
  | { type: "desk_snapshot"; requestId: string; jpeg: string | null }
  | { type: "desk_off" }
  | { type: "ask_tutor" };

export function isValidRoomCode(code: string): boolean {
  return /^[a-z0-9][a-z0-9-]{2,39}$/.test(code);
}

export function cleanName(name: unknown): string {
  return String(name ?? "")
    .replace(/[\u0000-\u001f<>]/g, "")
    .trim()
    .slice(0, 40);
}
