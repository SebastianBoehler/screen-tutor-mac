// The room's voice tutor: one raw WebSocket to the OpenAI Realtime API.
// The room server streams the mixed microphone audio in, relays the tutor's
// voice out, and runs every tool call itself; there is no SDK in between.

import { pcmToBase64, base64ToPcm } from "./mixer";
import type { TutorState } from "../shared/protocol";

export type ToolDefinition = {
  type: "function";
  name: string;
  description: string;
  parameters: { type: "object"; properties: Record<string, unknown>; required?: string[]; additionalProperties?: boolean };
};

export type ToolResult = { output: Record<string, unknown>; followUp?: { text: string; jpegBase64?: string } };

export type TutorHandlers = {
  onAudio(pcm: Int16Array): void;
  onAudioClear(): void;
  onState(state: TutorState, detail: string): void;
  onTutorTranscript(text: string, final: boolean): void;
  onLearnerTranscript(itemId: string, text: string): void;
  onSpeechStarted(): void;
  onCommitted(itemId: string): void;
  runTool(name: string, args: Record<string, unknown>): Promise<ToolResult>;
};

export type TutorConfig = {
  apiKey: string;
  model: string;
  url?: string;
  instructions: string;
  tools: ToolDefinition[];
  voice?: string;
};

let counter = 0;
export function itemId(prefix: string): string {
  return `${prefix}_${Date.now().toString(36)}${(counter++).toString(36)}`.slice(0, 32);
}

export class RealtimeTutor {
  private ws: WebSocket | null = null;
  private ready = false;
  private responseActive = false;
  private responseQueued = false;
  private userSpeaking = false;
  private lastSpeechStoppedAt = 0;
  private playback: { itemId: string; startedAt: number; audioMs: number } | null = null;
  private speakingTimer: ReturnType<typeof setTimeout> | null = null;
  private transcript = "";
  private closedByUs = false;
  /** Set for errors a reconnect cannot fix. */
  fatal: string | null = null;
  state: TutorState = "offline";

  constructor(private config: TutorConfig, private handlers: TutorHandlers) {}

  get isOpen(): boolean {
    return this.ready;
  }

  connect(): void {
    this.closedByUs = false;
    this.setState("connecting", "Connecting the tutor voice…");
    const url = this.config.url ?? `wss://api.openai.com/v1/realtime?model=${encodeURIComponent(this.config.model)}`;
    // Bun's WebSocket accepts request headers, so the API key never reaches a browser.
    const ws = new WebSocket(url, { headers: { Authorization: `Bearer ${this.config.apiKey}` } } as any);
    this.ws = ws;
    ws.onopen = () => this.send(this.sessionUpdate());
    ws.onmessage = (message) => {
      try {
        this.handle(JSON.parse(String(message.data)));
      } catch (error) {
        console.warn("[tutor] bad event", error);
      }
    };
    ws.onclose = (event) => {
      const wasReady = this.ready;
      this.ready = false;
      this.responseActive = false;
      this.ws = null;
      if (this.closedByUs) return;
      if (this.fatal) this.setState("offline", this.fatal);
      else if (!wasReady) this.setState("offline", `Could not start the tutor voice (${event.code}). Check OPENAI_API_KEY and the model name.`);
      else this.setState("offline", `Tutor voice disconnected (${event.code}${event.reason ? `: ${event.reason}` : ""}).`);
    };
    ws.onerror = () => console.warn("[tutor] websocket error");
  }

  close(): void {
    this.closedByUs = true;
    this.ws?.close();
    this.ws = null;
    this.ready = false;
    this.setState("offline", "Tutor is resting until someone joins.");
  }

  appendAudio(pcm: Int16Array): void {
    if (this.ready) this.send({ type: "input_audio_buffer.append", audio: pcmToBase64(pcm) });
  }

  /** Adds a user-role context item (text, optionally with a desk photo). */
  addContext(text: string, opts: { previousItemId?: string; jpegBase64?: string } = {}): void {
    const content: unknown[] = [{ type: "input_text", text }];
    if (opts.jpegBase64) content.push({ type: "input_image", image_url: `data:image/jpeg;base64,${opts.jpegBase64}`, detail: "high" });
    this.send({
      type: "conversation.item.create",
      ...(opts.previousItemId ? { previous_item_id: opts.previousItemId } : {}),
      item: { id: itemId("ctx"), type: "message", role: "user", content },
    });
  }

  requestResponse(): void {
    if (!this.ready) return;
    if (this.responseActive) {
      this.responseQueued = true;
      return;
    }
    this.responseActive = true;
    this.send({ type: "response.create" });
  }

  /** True when an automated note can be spoken without talking over anyone. */
  get isIdle(): boolean {
    return (
      this.ready &&
      !this.responseActive &&
      !this.userSpeaking &&
      !this.isPlaying &&
      Date.now() - this.lastSpeechStoppedAt > 1500
    );
  }

  private get isPlaying(): boolean {
    return !!this.playback && Date.now() < this.playback.startedAt + this.playback.audioMs;
  }

  private sessionUpdate() {
    return {
      type: "session.update",
      session: {
        type: "realtime",
        model: this.config.model,
        instructions: this.config.instructions,
        output_modalities: ["audio"],
        tools: this.config.tools,
        tool_choice: "auto",
        parallel_tool_calls: false,
        reasoning: { effort: "low" },
        audio: {
          input: {
            format: { type: "audio/pcm", rate: 24000 },
            noise_reduction: { type: "far_field" },
            transcription: { model: "gpt-4o-mini-transcribe" },
            turn_detection: { type: "semantic_vad", eagerness: "auto", create_response: false, interrupt_response: true },
          },
          output: { format: { type: "audio/pcm", rate: 24000 }, voice: this.config.voice ?? "marin" },
        },
      },
    };
  }

  private send(event: Record<string, unknown>): void {
    if (this.ws?.readyState === WebSocket.OPEN) this.ws.send(JSON.stringify(event));
  }

  private setState(state: TutorState, detail = ""): void {
    this.state = state;
    this.handlers.onState(state, detail);
  }

  private settleState(): void {
    if (!this.ready) return;
    if (this.isPlaying) {
      if (this.state !== "speaking") this.setState("speaking");
      if (this.speakingTimer) clearTimeout(this.speakingTimer);
      const remaining = this.playback!.startedAt + this.playback!.audioMs - Date.now();
      this.speakingTimer = setTimeout(() => this.settleState(), remaining + 50);
    } else if (this.responseActive) {
      if (this.state !== "thinking") this.setState("thinking");
    } else if (this.state !== "listening") {
      this.setState("listening");
    }
  }

  private async handle(event: any): Promise<void> {
    switch (event.type) {
      case "session.updated":
        if (!this.ready) {
          this.ready = true;
          this.setState("listening");
        }
        break;
      case "input_audio_buffer.speech_started":
        this.userSpeaking = true;
        this.handlers.onSpeechStarted();
        this.interruptPlayback();
        break;
      case "input_audio_buffer.speech_stopped":
        this.userSpeaking = false;
        this.lastSpeechStoppedAt = Date.now();
        break;
      case "input_audio_buffer.committed":
        this.handlers.onCommitted(event.item_id);
        break;
      case "conversation.item.input_audio_transcription.completed":
        this.handlers.onLearnerTranscript(event.item_id, String(event.transcript ?? "").trim());
        break;
      case "response.created":
        this.responseActive = true;
        this.transcript = "";
        this.settleState();
        break;
      case "response.output_audio.delta": {
        const pcm = base64ToPcm(event.delta);
        const ms = (pcm.length / 24000) * 1000;
        if (!this.playback || this.playback.itemId !== event.item_id || !this.isPlaying) {
          // Small lead so clients have buffered audio before the clock starts.
          this.playback = { itemId: event.item_id, startedAt: Date.now() + 80, audioMs: 0 };
        }
        this.playback.audioMs += ms;
        this.handlers.onAudio(pcm);
        this.settleState();
        break;
      }
      case "response.output_audio_transcript.delta":
        this.transcript += event.delta ?? "";
        this.handlers.onTutorTranscript(this.transcript, false);
        break;
      case "response.output_audio_transcript.done":
        this.handlers.onTutorTranscript(String(event.transcript ?? this.transcript), true);
        break;
      case "response.done":
        await this.finishResponse(event.response);
        break;
      case "error": {
        const error = event.error ?? {};
        console.warn("[tutor] error", error.code, error.message);
        if (error.code === "invalid_api_key") {
          this.fatal = "Tutor voice unavailable: the OpenAI API key was rejected.";
          this.setState("offline", this.fatal);
        }
        if (error.code === "conversation_already_has_active_response") this.responseQueued = true;
        break;
      }
    }
  }

  private interruptPlayback(): void {
    if (!this.isPlaying || !this.playback) return;
    const played = Math.max(0, Math.min(this.playback.audioMs, Date.now() - this.playback.startedAt));
    this.send({ type: "conversation.item.truncate", item_id: this.playback.itemId, content_index: 0, audio_end_ms: Math.round(played) });
    this.playback = null;
    this.handlers.onAudioClear();
    this.settleState();
  }

  private async finishResponse(response: any): Promise<void> {
    const calls = (response?.output ?? []).filter((item: any) => item.type === "function_call");
    this.responseActive = false;
    if (response?.status === "failed") {
      const detail = response.status_details?.error?.message ?? "response failed";
      console.warn("[tutor] response failed:", detail);
    }
    if (calls.length) {
      for (const call of calls) {
        let args: Record<string, unknown> = {};
        try {
          args = JSON.parse(call.arguments || "{}");
        } catch {}
        let result: ToolResult;
        try {
          result = await this.handlers.runTool(call.name, args);
        } catch (error) {
          result = { output: { ok: false, error: String((error as Error)?.message ?? error) } };
        }
        this.send({
          type: "conversation.item.create",
          item: { type: "function_call_output", call_id: call.call_id, output: JSON.stringify(result.output) },
        });
        if (result.followUp) this.addContext(result.followUp.text, { jpegBase64: result.followUp.jpegBase64 });
      }
      this.responseQueued = false;
      this.requestResponse();
    } else if (this.responseQueued) {
      this.responseQueued = false;
      this.requestResponse();
    }
    this.settleState();
  }
}
