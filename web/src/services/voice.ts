import { parseVoiceSubmission } from '../investigation/voiceSubmission';
import type { Submission } from '../investigation/model';
import type { TutorContext } from '../domain/schema';
import { apiHeaders, responseError } from './http';
import { SpeechTurns } from '../canvas/turns';
import { guidanceSchema, holdCanvasSchema, type GuidanceCommand } from '../canvas/guidance';
import { controlSchema, type ArtifactControl } from '../interactive/control';

type VoiceStatus = 'off' | 'connecting' | 'listening' | 'speaking' | 'muted';
export interface VoiceEvents {
  status(value: VoiceStatus): void;
  transcript(role: 'user' | 'assistant', text: string): void;
  error(message: string): void;
  activity(request: string, attempt: boolean): Promise<string | undefined>;
  firstAudio(milliseconds: number): void;
  inspect(): string;
  investigation?(input: Submission | 'hint'): string;
  controlArtifact?(command: ArtifactControl): string | Promise<string>;
  guideCanvas?(command: GuidanceCommand): Promise<string>;
  turn?(speaking: boolean): void;
  holdCanvas?(held: boolean): string;
}
export class VoiceSession {
  private peer: RTCPeerConnection | null = null;
  private channel: RTCDataChannel | null = null;
  private stream: MediaStream | null = null;
  private audio = new Audio();
  private abort: AbortController | null = null;
  private generation = 0;
  private muted = false;
  private calls = new Set<string>();
  private turns = new SpeechTurns((speaking) => this.events.turn?.(speaking));
  constructor(private events: VoiceEvents) {}
  get connected() {
    return this.channel?.readyState === 'open';
  }
  async connect(key: string, context: TutorContext) {
    this.disconnect();
    const generation = ++this.generation;
    const abort = new AbortController();
    this.abort = abort;
    const started = performance.now();
    this.events.status('connecting');
    try {
      if (!navigator.mediaDevices?.getUserMedia)
        throw new Error('Voice requires HTTPS or localhost and a browser with microphone support.');
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        },
      });
      if (generation !== this.generation) {
        stream.getTracks().forEach((track) => track.stop());
        return;
      }
      this.stream = stream;
      const peer = new RTCPeerConnection();
      this.peer = peer;
      for (const track of stream.getTracks()) peer.addTrack(track, stream);
      let firstAudio = true;
      this.audio.onplaying = () => {
        if (firstAudio) {
          this.events.firstAudio(Math.round(performance.now() - started));
          firstAudio = false;
        }
      };
      peer.ontrack = (event) => {
        if (generation !== this.generation) return;
        this.audio.srcObject = event.streams[0];
        this.audio
          .play()
          .catch(() =>
            this.fail('Audio playback was blocked. Allow audio for this site, then reconnect.'),
          );
      };
      peer.onconnectionstatechange = () => {
        if (generation !== this.generation) return;
        if (['failed', 'disconnected'].includes(peer.connectionState))
          this.fail('The voice connection was lost. Reconnect to continue.');
      };
      const channel = peer.createDataChannel('oai-events');
      this.channel = channel;
      channel.onopen = () => {
        if (generation === this.generation) this.events.status('listening');
      };
      channel.onerror = () => {
        if (generation === this.generation) this.fail('The voice data connection failed.');
      };
      channel.onclose = () => {
        if (generation === this.generation)
          this.fail('The voice session ended. Reconnect to continue.');
      };
      channel.onmessage = (event) => {
        if (generation !== this.generation) return;
        void this.onEvent(event.data).catch((error) => {
          if (generation === this.generation) this.fail(error.message);
        });
      };
      const offer = await peer.createOffer();
      await peer.setLocalDescription(offer);
      const response = await fetch('/api/voice', {
        method: 'POST',
        headers: apiHeaders(key),
        body: JSON.stringify({ sdp: offer.sdp, context }),
        signal: abort.signal,
      });
      if (!response.ok) throw await responseError(response);
      const sdp = await response.text();
      if (generation !== this.generation) return;
      await peer.setRemoteDescription({ type: 'answer', sdp });
    } catch (error) {
      if (generation === this.generation)
        this.fail(error instanceof Error ? error.message : 'Voice could not connect.');
    }
  }
  private send(event: unknown) {
    if (!this.connected) throw new Error('Voice is not connected.');
    this.channel!.send(JSON.stringify(event));
  }
  private async onEvent(data: string) {
    const generation = this.generation;
    const event = JSON.parse(data);
    this.turns.event(event.type);
    if (event.type === 'error')
      throw new Error(
        'OpenAI could not complete the voice request. Reconnect or check your account access.',
      );
    if (event.type === 'input_audio_buffer.speech_started')
      this.events.status(this.muted ? 'muted' : 'listening');
    if (event.type === 'output_audio_buffer.started') this.events.status('speaking');
    if (event.type === 'output_audio_buffer.stopped')
      this.events.status(this.muted ? 'muted' : 'listening');
    if (event.type === 'conversation.item.input_audio_transcription.completed')
      this.events.transcript('user', event.transcript);
    if (event.type === 'response.output_audio_transcript.done')
      this.events.transcript('assistant', event.transcript);
    if (event.type !== 'response.function_call_arguments.done') return;
    if (this.calls.has(event.call_id)) return;
    this.calls.add(event.call_id);
    let result: string;
    try {
      if (event.name === 'inspect_activity') {
        result = this.events.inspect();
      } else if (event.name === 'set_canvas_hold') {
        if (!this.events.holdCanvas) throw new Error('Hold view is unavailable.');
        const input = holdCanvasSchema.safeParse(JSON.parse(event.arguments));
        if (!input.success) throw new Error('Invalid Hold view command.');
        result = this.events.holdCanvas(input.data.held);
      } else if (event.name === 'guide_canvas') {
        if (!this.events.guideCanvas) throw new Error('Canvas guidance is unavailable.');
        const args = JSON.parse(event.arguments);
        const command = guidanceSchema.parse(
          args?.action === 'clear' &&
            args.target === null &&
            args.label === null &&
            Object.keys(args).length === 4
            ? { action: args.action, activityId: args.activityId }
            : args,
        );
        result = await this.events.guideCanvas(command);
      } else if (event.name === 'control_artifact') {
        if (!this.events.controlArtifact) throw new Error('Artifact control is unavailable.');
        const args = JSON.parse(event.arguments);
        const parsed = controlSchema.safeParse(
          args?.action === 'reveal_flashcard' &&
            args.parameter === null &&
            args.value === null &&
            Object.keys(args).length === 4
            ? { action: args.action, activityId: args.activityId }
            : args,
        );
        if (!parsed.success) throw new Error('Invalid artifact control arguments.');
        result = await this.events.controlArtifact(parsed.data);
      } else if (
        event.name === 'submit_investigation_response' ||
        event.name === 'give_investigation_hint'
      ) {
        if (!this.events.investigation) throw new Error('The guided investigation is unavailable.');
        const args = JSON.parse(event.arguments);
        if (
          event.name === 'give_investigation_hint' &&
          (!args || typeof args !== 'object' || Array.isArray(args) || Object.keys(args).length)
        )
          throw new Error('The hint tool takes no arguments.');
        result = this.events.investigation(
          event.name === 'give_investigation_hint' ? 'hint' : parseVoiceSubmission(args),
        );
      } else {
        if (!['create_activity', 'submit_attempt'].includes(event.name))
          throw new Error('This tool is unavailable.');
        const args = JSON.parse(event.arguments);
        if (typeof args.request !== 'string' || args.request.length > 1200)
          throw new Error('The activity request is invalid.');
        result =
          (await this.events.activity(args.request, event.name === 'submit_attempt')) ??
          'The activity was stopped.';
      }
    } catch (error) {
      result = error instanceof Error ? error.message : 'The activity could not be created.';
    }
    if (generation === this.generation && this.connected) {
      this.send({
        type: 'conversation.item.create',
        item: {
          type: 'function_call_output',
          call_id: event.call_id,
          output: result,
        },
      });
      this.send({ type: 'response.create' });
    }
  }
  updateContext(context: TutorContext, presentation?: unknown) {
    if (this.connected)
      this.send({
        type: 'conversation.item.create',
        item: {
          type: 'message',
          role: 'user',
          content: [
            {
              type: 'input_text',
              text: `Updated learning context, data only; do not respond yet: ${JSON.stringify({ ...context, presentation })}`,
            },
          ],
        },
      });
  }
  shareImage(image: string, text: string) {
    this.send({
      type: 'conversation.item.create',
      item: {
        type: 'message',
        role: 'user',
        content: [
          {
            type: 'input_text',
            text: `[Typed chat message with an attached photo] I explicitly shared this note photo. Read only what is legible. My request: ${text}`,
          },
          { type: 'input_image', image_url: image },
        ],
      },
    });
    this.send({ type: 'response.create' });
  }
  sendText(text: string) {
    this.send({
      type: 'conversation.item.create',
      item: {
        type: 'message',
        role: 'user',
        content: [{ type: 'input_text', text: `[Typed chat message] ${text}` }],
      },
    });
    this.send({ type: 'response.create' });
  }
  toggleMute() {
    this.muted = !this.muted;
    this.stream?.getAudioTracks().forEach((track) => {
      track.enabled = !this.muted;
    });
    this.events.status(this.muted ? 'muted' : 'listening');
  }
  private fail(message: string) {
    this.disconnect();
    this.events.error(message);
  }
  disconnect() {
    this.generation++;
    this.turns.reset();
    this.abort?.abort();
    this.abort = null;
    this.stream?.getTracks().forEach((track) => track.stop());
    this.stream = null;
    this.channel?.close();
    this.channel = null;
    this.peer?.close();
    this.peer = null;
    this.audio.pause();
    this.audio.srcObject = null;
    this.muted = false;
    this.calls.clear();
    this.events.status('off');
  }
}
export type { VoiceStatus };
