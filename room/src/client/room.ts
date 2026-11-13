// Study room client: camera + mic, direct video to the other learners, mic audio
// to the room server for the tutor, and the shared board.

import { MicCapture, TutorPlayer } from "./audio";
import { DeskWatcher } from "./desk";
import { fakeMediaStream } from "./fakeMedia";
import { escapeHtml, renderMarkdownInto } from "./markdown";
import { Mesh } from "./mesh";
import type { Caption, ClientMessage, RoomState, ServerMessage } from "../shared/protocol";

const NAME_KEY = "study-room-name";
const $ = <T extends HTMLElement = HTMLElement>(id: string) => document.getElementById(id) as T;

const code = decodeURIComponent(location.pathname.split("/").pop() ?? "");
let localStream = new MediaStream();
let ws: WebSocket | null = null;
let mesh: Mesh | null = null;
let selfId = "";
let state: RoomState | null = null;
let boardVersion = -1;
let leaving = false;
const remoteStreams = new Map<string, MediaStream>();
const captions: Caption[] = [];
let captionTimer: ReturnType<typeof setTimeout> | null = null;

const player = new TutorPlayer();
const mic = new MicCapture((frame) => {
  if (ws?.readyState === WebSocket.OPEN) ws.send(frame);
});
const localVideo = document.createElement("video");
localVideo.autoplay = localVideo.muted = localVideo.playsInline = true;
const desk = new DeskWatcher(
  localVideo,
  () => !!state?.tasks.some((t) => t.status === "active" && (t.assignee === selfId || t.assignee === "everyone")),
  (reason, jpeg, secondsWithoutChange) => send({ type: "desk_frame", reason, jpeg, secondsWithoutChange }),
);

function send(message: ClientMessage): void {
  if (ws?.readyState === WebSocket.OPEN) ws.send(JSON.stringify(message));
}

// MARK: media

const videoTrack = () => localStream.getVideoTracks()[0] ?? null;
const audioTrack = () => localStream.getAudioTracks()[0] ?? null;

async function openMedia(deviceId?: string): Promise<void> {
  const video: MediaTrackConstraints = { width: { ideal: 1920 }, height: { ideal: 1080 }, ...(deviceId ? { deviceId: { exact: deviceId } } : {}) };
  const audio: MediaTrackConstraints = { echoCancellation: true, noiseSuppression: true, autoGainControl: true };
  if (new URLSearchParams(location.search).has("fake")) {
    localStream = fakeMediaStream($<HTMLInputElement>("prejoin-name").value || "Learner");
    ($("preview") as HTMLVideoElement).srcObject = localStream;
    localVideo.srcObject = localStream;
    for (const id of ["prejoin-camera", "camera"]) $(id).hidden = true;
    return;
  }
  try {
    localStream = await navigator.mediaDevices.getUserMedia({ audio, video });
  } catch (error) {
    console.warn("camera unavailable, trying microphone only", error);
    localStream = await navigator.mediaDevices.getUserMedia({ audio });
    $("prejoin-status").textContent = "No camera available; joining with microphone only.";
  }
  ($("preview") as HTMLVideoElement).srcObject = localStream;
  localVideo.srcObject = localStream;
  await fillCameras();
}

async function fillCameras(): Promise<void> {
  const devices = (await navigator.mediaDevices.enumerateDevices()).filter((d) => d.kind === "videoinput");
  const current = videoTrack()?.getSettings().deviceId;
  for (const select of [$<HTMLSelectElement>("prejoin-camera"), $<HTMLSelectElement>("camera")]) {
    select.innerHTML = devices
      .map((d, i) => `<option value="${escapeHtml(d.deviceId)}">${escapeHtml(d.label || `Camera ${i + 1}`)}</option>`)
      .join("");
    if (current) select.value = current;
    select.hidden = devices.length === 0;
  }
}

async function switchCamera(deviceId: string): Promise<void> {
  const fresh = await navigator.mediaDevices.getUserMedia({ video: { deviceId: { exact: deviceId }, width: { ideal: 1920 }, height: { ideal: 1080 } } });
  const next = fresh.getVideoTracks()[0];
  const old = videoTrack();
  if (old) {
    localStream.removeTrack(old);
    old.stop();
  }
  localStream.addTrack(next);
  localVideo.srcObject = ($("preview") as HTMLVideoElement).srcObject = new MediaStream(localStream.getTracks());
  mesh?.setLocalTracks(localStream.getTracks());
  updateDeskWatching(true);
  for (const select of [$<HTMLSelectElement>("prejoin-camera"), $<HTMLSelectElement>("camera")]) select.value = deviceId;
}

function updateDeskWatching(restart = false): void {
  const on = $<HTMLInputElement>("desk").checked && !!videoTrack()?.enabled;
  if (restart) desk.stop();
  if (on) desk.start();
  else if (desk.running || restart) {
    desk.stop();
    send({ type: "desk_off" });
  }
}

// MARK: connection

function connect(name: string): void {
  const protocol = location.protocol === "https:" ? "wss" : "ws";
  ws = new WebSocket(`${protocol}://${location.host}/ws/${encodeURIComponent(code)}`);
  ws.binaryType = "arraybuffer";
  ws.onopen = () => send({ type: "join", name });
  ws.onmessage = (event) => {
    if (typeof event.data !== "string") {
      player.play(event.data as ArrayBuffer);
      return;
    }
    void handle(JSON.parse(event.data) as ServerMessage);
  };
  ws.onclose = () => {
    if (leaving) return;
    $("tutor-detail").textContent = "Disconnected from the room server.";
    $("tutor-pill").textContent = "Disconnected";
    $("tutor-pill").className = "tutor-pill";
    $("leave").textContent = "Rejoin";
    $("leave").onclick = () => location.reload();
  };
}

async function handle(message: ServerMessage): Promise<void> {
  switch (message.type) {
    case "welcome":
      selfId = message.id;
      mesh = new Mesh(
        selfId,
        message.iceServers,
        (to, data) => send({ type: "signal", to, data }),
        (peerId, stream) => {
          remoteStreams.set(peerId, stream);
          renderTiles();
        },
      );
      mesh.setLocalTracks(localStream.getTracks());
      for (const peer of message.state.peers) if (peer.id !== selfId) mesh.connect(peer.id);
      render(message.state);
      updateDeskWatching();
      break;
    case "state":
      render(message.state);
      break;
    case "peer_joined":
      mesh?.connect(message.peer.id);
      break;
    case "peer_left":
      mesh?.disconnect(message.id);
      remoteStreams.delete(message.id);
      renderTiles();
      break;
    case "signal":
      await mesh?.handleSignal(message.from, message.data);
      break;
    case "caption":
      showCaption(message.caption);
      break;
    case "tutor_audio_clear":
      player.clear();
      break;
    case "desk_snapshot_request": {
      const allowed = $<HTMLInputElement>("desk").checked && !!videoTrack()?.enabled;
      send({ type: "desk_snapshot", requestId: message.requestId, jpeg: allowed ? desk.snapshot() : null });
      break;
    }
    case "error":
      $("tutor-detail").textContent = message.message;
      break;
  }
}

// MARK: rendering

function render(next: RoomState): void {
  state = next;
  const pill = $("tutor-pill");
  const labels = { offline: "Tutor offline", connecting: "Tutor joining…", listening: "Tutor listening", thinking: "Tutor thinking", speaking: "Tutor speaking" };
  pill.textContent = labels[next.tutor.state];
  pill.className = `tutor-pill ${next.tutor.state}`;
  $("tutor-detail").textContent = next.tutor.detail;
  renderTiles();
  renderTasks();
  if ((next.board?.updatedAt ?? 0) !== boardVersion) {
    boardVersion = next.board?.updatedAt ?? 0;
    const board = $("board");
    if (next.board) {
      board.innerHTML = `<h2>${escapeHtml(next.board.title)}</h2><div></div>`;
      void renderMarkdownInto(board.lastElementChild as HTMLElement, next.board.markdown);
    } else {
      board.innerHTML = `<p class="muted">The tutor's board appears here.</p>`;
    }
  }
  renderDesks();
}

function tile(id: string): HTMLElement {
  let el = document.getElementById(`tile-${id}`);
  if (!el) {
    el = document.createElement("div");
    el.id = `tile-${id}`;
    el.className = "tile";
    $("grid").append(el);
  }
  return el;
}

function renderTiles(): void {
  if (!state) return;
  const tutor = tile("tutor");
  tutor.className = `tile tutor ${state.tutor.state}`;
  if (!tutor.firstChild) tutor.innerHTML = `<div class="tutor-orb"></div><span class="label">Tutor</span>`;

  const self = tile(selfId);
  if (!self.contains(localVideo)) {
    self.prepend(localVideo);
    self.insertAdjacentHTML("beforeend", `<span class="label"></span>`);
  }
  self.querySelector(".label")!.textContent = `${state.peers.find((p) => p.id === selfId)?.name ?? "You"} (you)`;

  const keep = new Set(["tile-tutor", `tile-${selfId}`]);
  for (const peer of state.peers) {
    if (peer.id === selfId) continue;
    keep.add(`tile-${peer.id}`);
    const el = tile(peer.id);
    let video = el.querySelector("video");
    if (!video) {
      video = document.createElement("video");
      video.autoplay = video.playsInline = true;
      el.append(video);
      el.insertAdjacentHTML("beforeend", `<span class="label"></span>`);
    }
    const stream = remoteStreams.get(peer.id);
    if (stream && video.srcObject !== stream) video.srcObject = stream;
    el.querySelector(".label")!.textContent = peer.name;
  }
  for (const el of Array.from($("grid").children)) if (!keep.has(el.id)) el.remove();
}

function renderTasks(): void {
  const container = $("tasks");
  const active = state?.tasks.filter((t) => t.status === "active") ?? [];
  const signature = JSON.stringify(active);
  if (container.dataset.signature === signature) return;
  container.dataset.signature = signature;
  container.innerHTML = "";
  for (const task of active) {
    const mine = task.assignee === selfId || task.assignee === "everyone";
    const card = document.createElement("div");
    card.className = `task${mine ? " mine" : ""}`;
    card.innerHTML = `<div class="task-label">${mine ? "Your task" : `Task for ${escapeHtml(task.assigneeName)}`}</div><h3>${escapeHtml(task.title)}</h3><div></div>`;
    container.append(card);
    void renderMarkdownInto(card.lastElementChild as HTMLElement, task.task);
  }
}

function renderDesks(): void {
  const container = $("desks");
  const desks = state?.desks ?? [];
  const signature = JSON.stringify(desks);
  if (container.dataset.signature === signature) return;
  container.dataset.signature = signature;
  container.innerHTML = desks.length ? `<h4>Desks</h4>` : "";
  for (const d of desks) {
    const row = document.createElement("div");
    row.className = "desk";
    row.innerHTML = `<span class="pill ${escapeHtml(d.progress)}">${escapeHtml(d.progress.replace("_", " "))}</span><strong>${escapeHtml(d.name)}</strong><div></div>${d.issue ? `<div class="issue">${escapeHtml(d.issue)}</div>` : ""}`;
    container.append(row);
    void renderMarkdownInto(row.children[2] as HTMLElement, d.summary);
  }
}

function showCaption(caption: Caption): void {
  const last = captions[captions.length - 1];
  if (last && last.role === "tutor" && caption.role === "tutor" && !last.final) captions[captions.length - 1] = caption;
  else captions.push(caption);
  while (captions.length > 3) captions.shift();
  const box = $("captions");
  box.hidden = false;
  box.innerHTML = captions.map((c) => `<p><strong>${escapeHtml(c.speaker)}:</strong> ${escapeHtml(c.text)}</p>`).join("");
  if (captionTimer) clearTimeout(captionTimer);
  captionTimer = setTimeout(() => {
    box.hidden = true;
    captions.length = 0;
  }, 8000);
}

function animateTutor(): void {
  const orb = document.querySelector<HTMLElement>("#tile-tutor .tutor-orb");
  if (orb && state?.tutor.state === "speaking") orb.style.transform = `scale(${1 + player.level() * 0.6})`;
  else if (orb) orb.style.transform = "";
  requestAnimationFrame(animateTutor);
}

// MARK: controls

function wireControls(): void {
  $("room-code").textContent = code;
  $("copy-link").onclick = async () => {
    await navigator.clipboard.writeText(location.href);
    $("copy-link").textContent = "Link copied";
    setTimeout(() => ($("copy-link").textContent = "Copy invite link"), 2000);
  };
  $("mic").onclick = () => {
    const track = audioTrack();
    if (!track) return;
    track.enabled = !track.enabled;
    mic.muted = !track.enabled;
    $("mic").textContent = track.enabled ? "Mute" : "Unmute";
    $("mic").classList.toggle("off", !track.enabled);
  };
  $("cam").onclick = () => {
    const track = videoTrack();
    if (!track) return;
    track.enabled = !track.enabled;
    $("cam").textContent = track.enabled ? "Camera off" : "Camera on";
    $("cam").classList.toggle("off", !track.enabled);
    updateDeskWatching();
  };
  $<HTMLSelectElement>("camera").onchange = (e) => void switchCamera((e.target as HTMLSelectElement).value);
  $<HTMLInputElement>("desk").onchange = () => updateDeskWatching();
  $("ask").onclick = () => {
    send({ type: "ask_tutor" });
    $("ask").classList.add("on");
    setTimeout(() => $("ask").classList.remove("on"), 15_000);
  };
  $("leave").onclick = () => {
    leaving = true;
    ws?.close();
    mesh?.close();
    desk.stop();
    mic.stop();
    player.close();
    for (const track of localStream.getTracks()) track.stop();
    location.href = "/";
  };
}

async function main(): Promise<void> {
  $("prejoin-code").textContent = code;
  try {
    $<HTMLInputElement>("prejoin-name").value = localStorage.getItem(NAME_KEY) ?? "";
  } catch {}
  try {
    await openMedia();
  } catch (error) {
    $("prejoin-status").textContent = `Microphone or camera blocked: ${(error as Error).message}`;
  }
  $<HTMLSelectElement>("prejoin-camera").onchange = (e) => void switchCamera((e.target as HTMLSelectElement).value);

  $("prejoin-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const name = $<HTMLInputElement>("prejoin-name").value.trim();
    if (!name) return;
    try {
      localStorage.setItem(NAME_KEY, name);
    } catch {}
    // Started inside the click so browsers allow audio.
    await player.start();
    const track = audioTrack();
    if (track) await mic.start(track);
    $("prejoin").hidden = true;
    $("room").hidden = false;
    wireControls();
    connect(name);
    animateTutor();
  });
}

void main();
