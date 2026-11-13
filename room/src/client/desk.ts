// Watches this learner's camera like ScreenTutor's Mac desk observer: a 64×48
// fingerprint once a second, and a full photo to the room server only when the
// page changed materially (or an active task shows no progress).

import { DeskChangeGate, fingerprintFromRGBA, FP_H, FP_W } from "../shared/deskGate";
import type { DeskReason } from "../shared/protocol";

export class DeskWatcher {
  private gate = new DeskChangeGate();
  private timer: ReturnType<typeof setInterval> | null = null;
  private small = document.createElement("canvas");
  private full = document.createElement("canvas");

  constructor(
    private video: HTMLVideoElement,
    private hasTask: () => boolean,
    private onFrame: (reason: DeskReason, jpeg: string, secondsWithoutChange: number | null) => void,
  ) {
    this.small.width = FP_W;
    this.small.height = FP_H;
  }

  start(): void {
    if (this.timer) return;
    this.gate.reset();
    this.timer = setInterval(() => this.tick(), 1000);
  }

  stop(): void {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  get running(): boolean {
    return this.timer !== null;
  }

  /** Current camera frame as base64 JPEG (longest side ≤ 1600 px), or null. */
  snapshot(): string | null {
    const { videoWidth: w, videoHeight: h } = this.video;
    if (!w || !h) return null;
    const scale = Math.min(1, 1600 / Math.max(w, h));
    this.full.width = Math.round(w * scale);
    this.full.height = Math.round(h * scale);
    this.full.getContext("2d")!.drawImage(this.video, 0, 0, this.full.width, this.full.height);
    return this.full.toDataURL("image/jpeg", 0.8).split(",")[1] ?? null;
  }

  private tick(): void {
    if (!this.video.videoWidth || this.video.readyState < 2) return;
    const ctx = this.small.getContext("2d", { willReadFrequently: true })!;
    ctx.drawImage(this.video, 0, 0, FP_W, FP_H);
    const fp = fingerprintFromRGBA(ctx.getImageData(0, 0, FP_W, FP_H).data);
    const now = performance.now() / 1000;
    const reason = this.gate.evaluate(fp, now, this.hasTask());
    if (!reason) return;
    const jpeg = this.snapshot();
    if (!jpeg) return;
    this.gate.recordAnalysis(fp, now);
    const since = this.gate.lastMaterialChange;
    this.onFrame(reason, jpeg, since === null ? null : Math.round(now - since));
  }
}
