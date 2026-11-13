import { describe, expect, test } from "bun:test";
import { DeskChangeGate, FP_H, FP_W } from "../src/shared/deskGate";
import { AudioMixer, base64ToPcm, pcmToBase64 } from "../src/server/mixer";
import { parseObservation, resolveObserverModel } from "../src/server/observer";
import { FRAME_SAMPLES, isValidRoomCode, cleanName } from "../src/shared/protocol";

const blank = (value = 200) => new Uint8Array(FP_W * FP_H).fill(value);
const withInk = (rows: number) => {
  const fp = blank();
  fp.fill(20, 0, FP_W * rows);
  return fp;
};

describe("DeskChangeGate", () => {
  test("first look, then waits for a settled material change", () => {
    const gate = new DeskChangeGate();
    expect(gate.evaluate(blank(), 0, false)).toBe("first_look");
    gate.recordAnalysis(blank(), 0);
    expect(gate.evaluate(blank(), 5, false)).toBeNull();
    // Hands moving: a large change is motion, not yet settled.
    expect(gate.evaluate(withInk(10), 6, false)).toBeNull();
    // Same frame 2 s later: settled, materially different from the analyzed one.
    expect(gate.evaluate(withInk(10), 8, false)).toBe("page_changed");
  });

  test("respects the minimum interval", () => {
    const gate = new DeskChangeGate();
    gate.evaluate(blank(), 0, false);
    gate.recordAnalysis(blank(), 0);
    expect(gate.evaluate(withInk(1), 2, false)).toBeNull();
  });

  test("reports a stall once per active task", () => {
    const gate = new DeskChangeGate();
    gate.evaluate(blank(), 0, true);
    gate.recordAnalysis(blank(), 0);
    expect(gate.evaluate(blank(), 60, true)).toBeNull();
    expect(gate.evaluate(blank(), 91, true)).toBe("no_visible_progress");
    gate.recordAnalysis(blank(), 91);
    expect(gate.evaluate(blank(), 200, true)).toBeNull();
  });
});

describe("AudioMixer", () => {
  test("sums participants with clipping and ranks speakers by energy", () => {
    const mixer = new AudioMixer();
    mixer.push("a", new Int16Array(FRAME_SAMPLES).fill(20_000));
    mixer.push("b", new Int16Array(FRAME_SAMPLES).fill(20_000));
    mixer.push("c", new Int16Array(FRAME_SAMPLES).fill(1_000));
    const frame = mixer.mix();
    expect(frame[0]).toBe(32767);
    expect(mixer.takeSpeakers()).toEqual(["a", "b", "c"]);
    expect(mixer.takeSpeakers()).toEqual([]);
    expect(mixer.mix().every((s) => s === 0)).toBe(true);
  });

  test("bounds each queue so latency cannot grow", () => {
    const mixer = new AudioMixer();
    mixer.push("a", new Int16Array(FRAME_SAMPLES * 20).fill(100));
    let frames = 0;
    while (mixer.mix()[0] !== 0) frames++;
    expect(frames).toBe(8);
  });

  test("PCM round-trips through base64", () => {
    const pcm = Int16Array.from([0, 1, -1, 32767, -32768]);
    expect(Array.from(base64ToPcm(pcmToBase64(pcm)))).toEqual(Array.from(pcm));
  });
});

describe("observer", () => {
  test("parses JSON wrapped in prose and fills defaults", () => {
    const o = parseObservation('Sure: {"summary":"Factoring","issue":null} done');
    expect(o.summary).toBe("Factoring");
    expect(o.progress).toBe("unclear");
    expect(o.work_transcription).toBe("");
    expect(() => parseObservation("no json")).toThrow();
  });

  test("picks the provider from the keys and model id", () => {
    expect(resolveObserverModel({ openaiKey: "k" })).toEqual({ model: "gpt-5.4-mini", provider: "openai" });
    expect(resolveObserverModel({ openaiKey: "k", openrouterKey: "r" })?.provider).toBe("openrouter");
    expect(resolveObserverModel({ openaiKey: "k", model: "google/gemini-3.5-flash" })).toBeNull();
    expect(resolveObserverModel({})).toBeNull();
  });
});

test("room codes and names are sanitized", () => {
  expect(isValidRoomCode("abc-defg-hij")).toBe(true);
  expect(isValidRoomCode("../etc")).toBe(false);
  expect(cleanName("  <b>Anna</b>\n ")).toBe("bAnna/b");
  expect(cleanName("x".repeat(80)).length).toBe(40);
});
