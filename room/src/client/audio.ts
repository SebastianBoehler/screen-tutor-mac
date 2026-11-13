// Microphone capture to 24 kHz PCM16 frames and tutor voice playback, with
// nothing but Web Audio and one AudioWorklet.

import { FRAME_SAMPLES, SAMPLE_RATE } from "../shared/protocol";

// Runs on the audio thread: linear resampling from the context rate to 24 kHz,
// emitted as 40 ms Int16 frames.
const CAPTURE_WORKLET = `
class PcmCapture extends AudioWorkletProcessor {
  constructor() {
    super();
    this.ratio = sampleRate / ${SAMPLE_RATE};
    this.position = 0;
    this.last = 0;
    this.frame = new Int16Array(${FRAME_SAMPLES});
    this.filled = 0;
  }
  process(inputs) {
    const input = inputs[0] && inputs[0][0];
    if (!input) return true;
    while (this.position < input.length) {
      const i = Math.floor(this.position);
      const t = this.position - i;
      const a = i === 0 ? this.last : input[i - 1];
      const b = input[i];
      const s = Math.max(-1, Math.min(1, a + (b - a) * t));
      this.frame[this.filled++] = s < 0 ? s * 32768 : s * 32767;
      if (this.filled === ${FRAME_SAMPLES}) {
        this.port.postMessage(this.frame.buffer, [this.frame.buffer]);
        this.frame = new Int16Array(${FRAME_SAMPLES});
        this.filled = 0;
      }
      this.position += this.ratio;
    }
    this.position -= input.length;
    this.last = input[input.length - 1];
    return true;
  }
}
registerProcessor("pcm-capture", PcmCapture);
`;

export class MicCapture {
  private context: AudioContext | null = null;
  private source: MediaStreamAudioSourceNode | null = null;
  private node: AudioWorkletNode | null = null;
  muted = false;

  constructor(private onFrame: (frame: ArrayBuffer) => void) {}

  async start(track: MediaStreamTrack): Promise<void> {
    if (!this.context) {
      this.context = new AudioContext();
      const url = URL.createObjectURL(new Blob([CAPTURE_WORKLET], { type: "text/javascript" }));
      await this.context.audioWorklet.addModule(url);
      URL.revokeObjectURL(url);
    }
    await this.context.resume();
    this.source?.disconnect();
    this.node?.disconnect();
    this.source = this.context.createMediaStreamSource(new MediaStream([track]));
    this.node = new AudioWorkletNode(this.context, "pcm-capture");
    this.node.port.onmessage = (event) => {
      if (!this.muted) this.onFrame(event.data);
    };
    this.source.connect(this.node);
  }

  stop(): void {
    this.source?.disconnect();
    this.node?.disconnect();
    void this.context?.close();
    this.context = null;
  }
}

/**
 * Plays the tutor's PCM. Output is routed through a local RTCPeerConnection pair
 * so the browser's echo canceller treats it like call audio and the tutor does
 * not hear itself through the speakers.
 */
export class TutorPlayer {
  private context = new AudioContext();
  private output = this.context.createGain();
  private analyser = this.context.createAnalyser();
  private playhead = 0;
  private sources = new Set<AudioBufferSourceNode>();
  private element = new Audio();
  private loopback: RTCPeerConnection[] = [];

  constructor() {
    this.analyser.fftSize = 512;
    this.output.connect(this.analyser);
    this.element.autoplay = true;
  }

  async start(): Promise<void> {
    await this.context.resume();
    try {
      await this.routeThroughLoopback();
    } catch (error) {
      console.warn("echo-cancelled playback unavailable, playing directly", error);
      this.output.connect(this.context.destination);
    }
  }

  private async routeThroughLoopback(): Promise<void> {
    const destination = this.context.createMediaStreamDestination();
    this.output.connect(destination);
    const sender = new RTCPeerConnection();
    const receiver = new RTCPeerConnection();
    this.loopback = [sender, receiver];
    sender.onicecandidate = (e) => e.candidate && receiver.addIceCandidate(e.candidate);
    receiver.onicecandidate = (e) => e.candidate && sender.addIceCandidate(e.candidate);
    const received = new Promise<MediaStream>((resolve) => {
      receiver.ontrack = (e) => resolve(e.streams[0] ?? new MediaStream([e.track]));
    });
    for (const track of destination.stream.getAudioTracks()) sender.addTrack(track, destination.stream);
    await sender.setLocalDescription(await sender.createOffer());
    await receiver.setRemoteDescription(sender.localDescription!);
    await receiver.setLocalDescription(await receiver.createAnswer());
    await sender.setRemoteDescription(receiver.localDescription!);
    const stream = await Promise.race([
      received,
      new Promise<never>((_, reject) => setTimeout(() => reject(new Error("loopback timeout")), 3000)),
    ]);
    this.element.srcObject = stream;
    await this.element.play();
  }

  play(bytes: ArrayBuffer): void {
    const pcm = new Int16Array(bytes);
    if (!pcm.length) return;
    const buffer = this.context.createBuffer(1, pcm.length, SAMPLE_RATE);
    const channel = buffer.getChannelData(0);
    for (let i = 0; i < pcm.length; i++) channel[i] = pcm[i] / 32768;
    const source = this.context.createBufferSource();
    source.buffer = buffer;
    source.connect(this.output);
    const now = this.context.currentTime;
    if (this.playhead < now + 0.03) this.playhead = now + 0.06;
    source.start(this.playhead);
    this.playhead += buffer.duration;
    this.sources.add(source);
    source.onended = () => this.sources.delete(source);
  }

  clear(): void {
    for (const source of this.sources) {
      try {
        source.stop();
      } catch {}
    }
    this.sources.clear();
    this.playhead = 0;
  }

  /** 0…1 loudness of what is playing right now. */
  level(): number {
    const data = new Uint8Array(this.analyser.fftSize);
    this.analyser.getByteTimeDomainData(data);
    let sum = 0;
    for (const v of data) sum += ((v - 128) / 128) ** 2;
    return Math.min(1, Math.sqrt(sum / data.length) * 4);
  }

  close(): void {
    this.clear();
    for (const pc of this.loopback) pc.close();
    void this.context.close();
  }
}
