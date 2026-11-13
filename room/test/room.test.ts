// End-to-end room flow against a fake OpenAI Realtime server: join, greeting,
// tutor audio relay, speaker attribution, look_at_desk, the board, signaling.

import { afterAll, beforeAll, expect, test } from "bun:test";
import { startServer } from "../src/server/app";
import { FRAME_SAMPLES } from "../src/shared/protocol";

type Fake = { events: any[]; socket: any; send(event: object): void };
const fake: Fake = { events: [], socket: null, send: (e) => fake.socket?.send(JSON.stringify(e)) };

const fakeServer = Bun.serve({
  port: 0,
  fetch(req, server) {
    expect(req.headers.get("authorization")).toBe("Bearer sk-test");
    return server.upgrade(req) ? undefined : new Response("no", { status: 400 });
  },
  websocket: {
    open(ws) {
      fake.socket = ws;
    },
    message(_ws, message) {
      const event = JSON.parse(String(message));
      fake.events.push(event);
      if (event.type === "session.update") fake.send({ type: "session.updated", session: event.session });
    },
  },
});

let app: ReturnType<typeof startServer>;

beforeAll(() => {
  app = startServer({
    port: 0,
    openaiKey: "sk-test",
    tutorModel: "gpt-realtime-2.1",
    realtimeURL: `ws://localhost:${fakeServer.port}`,
    observer: {},
    iceServers: [],
    interjectionCooldownMs: 0,
    idleCloseMs: 200,
  });
});

afterAll(() => {
  app.stop();
  fakeServer.stop(true);
});

async function until<T>(check: () => T | undefined | null | false, label: string, ms = 3000): Promise<T> {
  const deadline = Date.now() + ms;
  while (Date.now() < deadline) {
    const value = check();
    if (value) return value;
    await Bun.sleep(10);
  }
  throw new Error(`timed out waiting for ${label}`);
}

function client(name: string) {
  const ws = new WebSocket(`ws://localhost:${app.server.port}/ws/test-room`);
  ws.binaryType = "arraybuffer";
  const messages: any[] = [];
  const audio: ArrayBuffer[] = [];
  ws.onmessage = (e) => (typeof e.data === "string" ? messages.push(JSON.parse(e.data)) : audio.push(e.data));
  ws.onopen = () => ws.send(JSON.stringify({ type: "join", name }));
  return { ws, messages, audio, latest: (type: string) => [...messages].reverse().find((m) => m.type === type) };
}

const fakeEvent = (predicate: (e: any) => boolean) => fake.events.find(predicate);

test("a learner joins and the tutor greets, speaks, hears, looks and writes", async () => {
  const anna = client("Anna");
  const welcome = await until(() => anna.latest("welcome"), "welcome");
  expect(welcome.state.peers).toEqual([{ id: welcome.id, name: "Anna" }]);

  // The server opens the Realtime session with tools and server-side VAD that never auto-responds.
  const update = await until(() => fakeEvent((e) => e.type === "session.update"), "session.update");
  expect(update.session.tools.map((t: any) => t.name)).toEqual(["show_on_board", "assign_task", "finish_task", "look_at_desk", "desk_notes"]);
  expect(update.session.audio.input.turn_detection.create_response).toBe(false);

  // Greeting once ready.
  await until(() => fakeEvent((e) => e.type === "response.create"), "greeting response");
  expect(JSON.stringify(fakeEvent((e) => e.type === "conversation.item.create"))).toContain("Present now: Anna");
  await until(() => anna.latest("state")?.state.tutor.state === "listening", "tutor listening");

  // Tutor voice is relayed to the browser as raw PCM.
  const voice = Buffer.from(new Int16Array(FRAME_SAMPLES).fill(1234).buffer).toString("base64");
  fake.send({ type: "response.created", response: { id: "r1" } });
  fake.send({ type: "response.output_audio.delta", item_id: "a1", delta: voice });
  fake.send({ type: "response.done", response: { id: "r1", status: "completed", output: [] } });
  const played = await until(() => anna.audio[0], "tutor audio");
  expect(new Int16Array(played)[0]).toBe(1234);

  // Microphone audio is mixed into input_audio_buffer.append.
  for (let i = 0; i < 5; i++) anna.ws.send(new Int16Array(FRAME_SAMPLES).fill(8000).buffer);
  const append = await until(
    () => fake.events.find((e) => e.type === "input_audio_buffer.append" && Buffer.from(e.audio, "base64").readInt16LE(0) === 8000),
    "mixed audio",
  );
  expect(append).toBeTruthy();

  // A committed turn gets a speaker note right after it, then a response (only one learner here).
  fake.events.length = 0;
  fake.send({ type: "input_audio_buffer.speech_started" });
  fake.send({ type: "input_audio_buffer.speech_stopped" });
  fake.send({ type: "input_audio_buffer.committed", item_id: "u1" });
  const heard = await until(() => fakeEvent((e) => e.type === "conversation.item.create" && e.previous_item_id === "u1"), "speaker note");
  expect(heard.item.content[0].text).toBe("[room] Heard: Anna.");
  await until(() => fakeEvent((e) => e.type === "response.create"), "turn response");

  // look_at_desk asks Anna's browser for a fresh photo and hands it to the model.
  fake.events.length = 0;
  fake.send({
    type: "response.done",
    response: { status: "completed", output: [{ type: "function_call", name: "look_at_desk", call_id: "c1", arguments: '{"name":"anna"}' }] },
  });
  const request = await until(() => anna.latest("desk_snapshot_request"), "snapshot request");
  anna.ws.send(JSON.stringify({ type: "desk_snapshot", requestId: request.requestId, jpeg: "SU1BR0U=" }));
  const output = await until(() => fakeEvent((e) => e.item?.type === "function_call_output"), "tool output");
  expect(JSON.parse(output.item.output)).toMatchObject({ ok: true, name: "Anna" });
  const image = await until(() => fakeEvent((e) => e.item?.content?.[1]?.type === "input_image"), "desk image");
  expect(image.item.content[1].image_url).toBe("data:image/jpeg;base64,SU1BR0U=");
  await until(() => fakeEvent((e) => e.type === "response.create"), "continue after tool");

  // show_on_board and assign_task update everyone's state.
  fake.send({
    type: "response.done",
    response: {
      status: "completed",
      output: [
        { type: "function_call", name: "show_on_board", call_id: "c2", arguments: '{"title":"Chain rule","markdown":"$f(g(x))$"}' },
        { type: "function_call", name: "assign_task", call_id: "c3", arguments: '{"assignee":"Anna","title":"Derive","task":"Differentiate $\\\\sin(x^2)$"}' },
      ],
    },
  });
  const state = await until(() => {
    const s = anna.latest("state")?.state;
    return s?.board?.title === "Chain rule" && s.tasks.length === 1 && s;
  }, "board and task");
  expect(state.tasks[0]).toMatchObject({ assigneeName: "Anna", status: "active", title: "Derive" });

  // A second learner: peers learn about each other and signaling is relayed.
  const ben = client("Ben");
  const benWelcome = await until(() => ben.latest("welcome"), "ben welcome");
  expect(benWelcome.state.board.title).toBe("Chain rule");
  const joined = await until(() => anna.latest("peer_joined"), "peer joined");
  anna.ws.send(JSON.stringify({ type: "signal", to: joined.peer.id, data: { candidate: null } }));
  const signal = await until(() => ben.latest("signal"), "relayed signal");
  expect(signal.from).toBe(welcome.id);

  // With two learners, a turn that does not address the tutor gets no response.
  fake.send({ type: "response.done", response: { status: "completed", output: [] } });
  await Bun.sleep(50);
  fake.events.length = 0;
  (app.rooms.get("test-room") as any).lastTutorSpokeAt = 0;
  fake.send({ type: "input_audio_buffer.committed", item_id: "u2" });
  fake.send({ type: "conversation.item.input_audio_transcription.completed", item_id: "u2", transcript: "Ben, what did you get?" });
  await until(() => ben.latest("caption")?.caption.text === "Ben, what did you get?", "caption");
  await Bun.sleep(100);
  expect(fakeEvent((e) => e.type === "response.create")).toBeUndefined();

  // ...but one that addresses the tutor does.
  fake.send({ type: "input_audio_buffer.committed", item_id: "u3" });
  fake.send({ type: "conversation.item.input_audio_transcription.completed", item_id: "u3", transcript: "Tutor, can you check this?" });
  await until(() => fakeEvent((e) => e.type === "response.create"), "addressed response");

  // Leaving updates the room.
  ben.ws.close();
  await until(() => anna.latest("peer_left"), "peer left");
  anna.ws.close();
});
