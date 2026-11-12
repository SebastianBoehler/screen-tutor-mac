"use client";

import {
  ControlBar,
  GridLayout,
  LiveKitRoom,
  ParticipantTile,
  RoomAudioRenderer,
  useDataChannel,
  useLocalParticipant,
  useTracks,
  useTranscriptions,
  useParticipants,
} from "@livekit/components-react";
import { Track, VideoPresets } from "livekit-client";
import { useParams, useSearchParams } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";
import { StudyBoard } from "@/components/StudyBoard";
import { STUDY_TOPIC, type AgentMessage, type Board, type DeskStatus, type StudyTask } from "@/lib/protocol";

type Connection = { token: string; url: string; identity: string };

export default function RoomPage() {
  const { code } = useParams<{ code: string }>();
  const search = useSearchParams();
  const [name, setName] = useState(search.get("name") ?? "");
  const [connection, setConnection] = useState<Connection | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function connect(event?: React.FormEvent) {
    event?.preventDefault();
    setError(null);
    const response = await fetch("/api/token", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ room: code, name }),
    });
    const data = await response.json();
    if (!response.ok) {
      setError(data.error ?? "Could not join the room.");
      return;
    }
    setConnection(data);
  }

  useEffect(() => {
    if (search.get("name")) void connect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (!connection) {
    return (
      <main className="lobby">
        <form className="lobby-card" onSubmit={connect}>
          <h1>Join {code}</h1>
          <label>
            Your name
            <input value={name} onChange={(e) => setName(e.target.value)} autoFocus />
          </label>
          {error && <p className="error">{error}</p>}
          <button type="submit" disabled={!name.trim()}>
            Join room
          </button>
        </form>
      </main>
    );
  }

  return (
    <LiveKitRoom
      serverUrl={connection.url}
      token={connection.token}
      connect
      audio
      video
      options={{
        adaptiveStream: false,
        videoCaptureDefaults: { resolution: VideoPresets.h1080.resolution },
        publishDefaults: { videoSimulcastLayers: [VideoPresets.h360, VideoPresets.h720] },
      }}
      onDisconnected={() => setConnection(null)}
      className="room"
    >
      <RoomView code={code} identity={connection.identity} />
      <RoomAudioRenderer />
    </LiveKitRoom>
  );
}

function RoomView({ code, identity }: { code: string; identity: string }) {
  const [board, setBoard] = useState<Board | null>(null);
  const [tasks, setTasks] = useState<StudyTask[]>([]);
  const [desks, setDesks] = useState<DeskStatus[]>([]);
  const [status, setStatus] = useState<string | null>(null);
  const participants = useParticipants();
  const tutor = participants.find((p) => p.isAgent);
  const tutorIdentity = tutor?.identity;
  const tutorPresent = Boolean(tutor);
  const syncedWith = useRef<string | null>(null);
  const tracks = useTracks(
    [
      { source: Track.Source.Camera, withPlaceholder: true },
      { source: Track.Source.ScreenShare, withPlaceholder: false },
    ],
    { onlySubscribed: false },
  ).filter((ref) => !ref.participant.isAgent);

  const { send } = useDataChannel(STUDY_TOPIC, (message) => {
    try {
      const data = JSON.parse(new TextDecoder().decode(message.payload)) as AgentMessage;
      if (data.type === "board") setBoard(data.board);
      if (data.type === "tasks") setTasks(data.tasks);
      if (data.type === "desks") setDesks(data.desks);
      if (data.type === "status") setStatus(data.text);
    } catch {}
  });

  // Ask the tutor once for the current board, tasks and desks whenever a (new) tutor joins.
  useEffect(() => {
    if (!tutorIdentity || syncedWith.current === tutorIdentity) return;
    syncedWith.current = tutorIdentity;
    const payload = new TextEncoder().encode(JSON.stringify({ type: "sync_request" }));
    void send(payload, { reliable: true, destinationIdentities: [tutorIdentity] });
  }, [tutorIdentity, send]);

  return (
    <div className="room-layout">
      <header className="room-header">
        <strong>Study Room</strong>
        <span className="muted">{code}</span>
        <span className={`pill ${tutorPresent ? "working" : "unclear"}`}>
          {tutorPresent ? "Tutor in the room" : "Waiting for the tutor…"}
        </span>
        {status && <span className="muted small">{status}</span>}
        <button
          className="link"
          onClick={() => navigator.clipboard?.writeText(`${location.origin}/room/${code}`)}
        >
          Copy invite link
        </button>
      </header>
      <section className="stage">
        <GridLayout tracks={tracks} className="grid">
          <ParticipantTile />
        </GridLayout>
        <Captions />
        <ControlBar variation="minimal" controls={{ chat: false, settings: false }} />
      </section>
      <StudyBoard board={board} tasks={tasks} desks={desks} myIdentity={identity} />
    </div>
  );
}

function Captions() {
  const transcriptions = useTranscriptions();
  const participants = useParticipants();
  const local = useLocalParticipant();
  const names = useMemo(() => {
    const map = new Map<string, string>();
    participants.forEach((p) => map.set(p.identity, p.isAgent ? "Tutor" : p.name || p.identity));
    map.set(local.localParticipant.identity, "You");
    return map;
  }, [participants, local.localParticipant.identity]);
  const recent = transcriptions.slice(-4);
  if (recent.length === 0) return null;
  return (
    <div className="captions">
      {recent.map((t) => (
        <p key={t.streamInfo.id}>
          <strong>{names.get(t.participantInfo.identity) ?? t.participantInfo.identity}:</strong> {t.text}
        </p>
      ))}
    </div>
  );
}
