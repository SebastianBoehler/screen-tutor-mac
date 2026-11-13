// HTTP + WebSocket server for the study room. Bun serves the pages (bundling the
// client TypeScript), relays WebRTC signaling between browsers, and hosts each
// room's tutor. No framework, no media server.

import lobbyPage from "../../public/index.html";
import roomPage from "../../public/room.html";
import { Room, type RoomConfig, type SocketData } from "./room";
import { isValidRoomCode, type ClientMessage } from "../shared/protocol";

export type AppOptions = { port: number; hostname?: string; development?: boolean } & RoomConfig;

export function configFromEnv(env: Record<string, string | undefined> = process.env): RoomConfig {
  let iceServers: RTCIceServer[] = [{ urls: "stun:stun.l.google.com:19302" }];
  if (env.ICE_SERVERS) {
    try {
      iceServers = JSON.parse(env.ICE_SERVERS);
    } catch {
      console.warn("ICE_SERVERS is not valid JSON; using the default STUN server.");
    }
  }
  return {
    openaiKey: env.OPENAI_API_KEY || undefined,
    tutorModel: env.STUDY_TUTOR_MODEL || "gpt-realtime-2.1",
    realtimeURL: env.OPENAI_REALTIME_URL || undefined,
    observer: {
      openaiKey: env.OPENAI_API_KEY || undefined,
      openrouterKey: env.OPENROUTER_API_KEY || undefined,
      model: env.DESK_OBSERVER_MODEL || undefined,
      openaiBaseURL: env.OPENAI_BASE_URL || undefined,
    },
    iceServers,
    interjectionCooldownMs: Number(env.INTERJECTION_COOLDOWN_SECONDS ?? 45) * 1000,
    idleCloseMs: 60_000,
  };
}

export function startServer(options: AppOptions) {
  const rooms = new Map<string, Room>();
  const roomFor = (code: string) => {
    let room = rooms.get(code);
    if (!room) rooms.set(code, (room = new Room(code, options)));
    return room;
  };

  // Forget rooms that stayed empty for 30 minutes.
  const sweep = setInterval(() => {
    for (const [code, room] of rooms) {
      if (room.size === 0 && Date.now() - room.emptySince > 30 * 60_000) {
        room.dispose();
        rooms.delete(code);
      }
    }
  }, 60_000);

  const server = Bun.serve<SocketData>({
    port: options.port,
    hostname: options.hostname,
    development: options.development,
    routes: {
      "/": lobbyPage,
      "/r/:code": roomPage,
      "/healthz": () => Response.json({ ok: true, rooms: rooms.size, tutor: !!options.openaiKey }),
    },
    fetch(req, server) {
      const url = new URL(req.url);
      const match = url.pathname.match(/^\/ws\/([^/]+)$/);
      if (match) {
        const code = decodeURIComponent(match[1]);
        if (!isValidRoomCode(code)) return new Response("bad room code", { status: 400 });
        if (server.upgrade(req, { data: { room: code, id: crypto.randomUUID().slice(0, 8) } })) return;
        return new Response("upgrade failed", { status: 400 });
      }
      return new Response("Not found", { status: 404 });
    },
    websocket: {
      maxPayloadLength: 4 * 1024 * 1024,
      idleTimeout: 120,
      message(ws, message) {
        const room = rooms.get(ws.data.room);
        if (typeof message !== "string") {
          // Microphone audio: 24 kHz mono PCM16.
          if (!room) return;
          const bytes = message as Uint8Array;
          const copy = new Int16Array(bytes.byteLength >> 1);
          new Uint8Array(copy.buffer).set(bytes.subarray(0, copy.byteLength));
          room.audio(ws.data.id, copy);
          return;
        }
        let parsed: ClientMessage;
        try {
          parsed = JSON.parse(message);
        } catch {
          return;
        }
        if (parsed.type === "join") roomFor(ws.data.room).join(ws, parsed.name);
        else room?.message(ws.data.id, parsed);
      },
      close(ws) {
        rooms.get(ws.data.room)?.leave(ws.data.id);
      },
    },
  });

  return {
    server,
    rooms,
    stop() {
      clearInterval(sweep);
      for (const room of rooms.values()) room.dispose();
      server.stop(true);
    },
  };
}
