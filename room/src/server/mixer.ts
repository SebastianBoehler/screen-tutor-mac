// Mixes every participant's microphone into the single audio stream the tutor
// hears, and keeps per-speaker energy so each turn can be attributed by name.

import { FRAME_SAMPLES } from "../shared/protocol";

const MAX_QUEUED_FRAMES = 8; // 320 ms; older audio is dropped to bound latency
const SPEAKING_RMS = 0.015;

export class AudioMixer {
  private queues = new Map<string, Int16Array[]>();
  private energy = new Map<string, number>();

  push(id: string, pcm: Int16Array): void {
    let queue = this.queues.get(id);
    if (!queue) this.queues.set(id, (queue = []));
    for (let offset = 0; offset < pcm.length; offset += FRAME_SAMPLES) {
      const frame = new Int16Array(FRAME_SAMPLES);
      frame.set(pcm.subarray(offset, offset + FRAME_SAMPLES));
      queue.push(frame);
    }
    while (queue.length > MAX_QUEUED_FRAMES) queue.shift();
  }

  remove(id: string): void {
    this.queues.delete(id);
    this.energy.delete(id);
  }

  /** One 40 ms frame: the clipped sum of each participant's next frame. */
  mix(): Int16Array {
    const sum = new Int32Array(FRAME_SAMPLES);
    for (const [id, queue] of this.queues) {
      const frame = queue.shift();
      if (!frame) continue;
      let squares = 0;
      for (let i = 0; i < FRAME_SAMPLES; i++) {
        sum[i] += frame[i];
        squares += frame[i] * frame[i];
      }
      const rms = Math.sqrt(squares / FRAME_SAMPLES) / 32768;
      if (rms > SPEAKING_RMS) this.energy.set(id, (this.energy.get(id) ?? 0) + rms);
    }
    const out = new Int16Array(FRAME_SAMPLES);
    for (let i = 0; i < FRAME_SAMPLES; i++) out[i] = Math.max(-32768, Math.min(32767, sum[i]));
    return out;
  }

  /** Participants who spoke since the last call, loudest first; resets the tally. */
  takeSpeakers(): string[] {
    const ranked = [...this.energy.entries()].sort((a, b) => b[1] - a[1]).map(([id]) => id);
    this.energy.clear();
    return ranked;
  }

  resetSpeakers(): void {
    this.energy.clear();
  }
}

export function pcmToBase64(pcm: Int16Array): string {
  return Buffer.from(pcm.buffer, pcm.byteOffset, pcm.byteLength).toString("base64");
}

export function base64ToPcm(base64: string): Int16Array {
  const bytes = Buffer.from(base64, "base64");
  return new Int16Array(bytes.buffer, bytes.byteOffset, Math.floor(bytes.byteLength / 2));
}
