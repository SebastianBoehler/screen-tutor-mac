// Change detection for a desk camera. Same decisions as ScreenTutor's Swift
// DeskChangeGate: look once at the start, again when the page changed materially
// and the hands have settled, and once when an active task shows no progress.

import type { DeskReason } from "./protocol";

export const FP_W = 64;
export const FP_H = 48;

/** 64×48 grayscale fingerprint from RGBA pixels already scaled to FP_W×FP_H. */
export function fingerprintFromRGBA(rgba: Uint8ClampedArray | Uint8Array): Uint8Array {
  const out = new Uint8Array(FP_W * FP_H);
  for (let i = 0; i < out.length; i++) {
    const p = i * 4;
    out[i] = (rgba[p] * 299 + rgba[p + 1] * 587 + rgba[p + 2] * 114) / 1000;
  }
  return out;
}

export function changedFraction(a: Uint8Array, b: Uint8Array, threshold = 14): number {
  let changed = 0;
  for (let i = 0; i < a.length; i++) if (Math.abs(a[i] - b[i]) > threshold) changed++;
  return changed / a.length;
}

export class DeskChangeGate {
  motionThreshold = 0.02;
  materialThreshold = 0.006;
  settleSeconds = 1.5;
  minimumInterval = 4;
  stallSeconds = 90;

  private previous: Uint8Array | null = null;
  private analyzed: Uint8Array | null = null;
  private lastMotion: number | null = null;
  lastMaterialChange: number | null = null;
  private lastAnalysis: number | null = null;
  private stallReported = false;

  /** `now` in seconds. Returns a reason to analyze, or null to wait. */
  evaluate(fp: Uint8Array, now: number, hasTask: boolean): DeskReason | null {
    try {
      if (this.previous && changedFraction(fp, this.previous) > this.motionThreshold) this.lastMotion = now;
      if (this.lastMaterialChange === null) this.lastMaterialChange = now;
      if (!this.analyzed) return "first_look";
      if (this.lastAnalysis !== null && now - this.lastAnalysis < this.minimumInterval) return null;
      const settled = this.lastMotion === null || now - this.lastMotion >= this.settleSeconds;
      if (changedFraction(fp, this.analyzed) > this.materialThreshold) {
        this.lastMaterialChange = now;
        this.stallReported = false;
        return settled ? "page_changed" : null;
      }
      if (hasTask && !this.stallReported && now - this.lastMaterialChange >= this.stallSeconds) {
        this.stallReported = true;
        return "no_visible_progress";
      }
      return null;
    } finally {
      this.previous = fp;
    }
  }

  recordAnalysis(fp: Uint8Array, now: number): void {
    this.analyzed = fp;
    this.lastAnalysis = now;
  }

  reset(): void {
    this.previous = this.analyzed = null;
    this.lastMotion = this.lastMaterialChange = this.lastAnalysis = null;
    this.stallReported = false;
  }
}
