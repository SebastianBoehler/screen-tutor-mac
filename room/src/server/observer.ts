// Desk observer: one raw HTTPS call per material page change to a fast vision
// model. Uses the OpenAI Responses API by default; a model id with a slash
// (e.g. google/gemini-3.5-flash-lite) goes to OpenRouter instead.

import { OBSERVER_SYSTEM, observerUserText } from "./prompts";

export type Observation = {
  desk_visible?: boolean;
  summary: string;
  work_transcription: string;
  progress: string;
  issue?: { kind?: string; location?: string; description?: string } | null;
  interjection?: { kind?: string; reason?: string; suggested_move?: string } | null;
};

export type ObserverConfig = {
  openaiKey?: string;
  openrouterKey?: string;
  model?: string;
  openaiBaseURL?: string;
};

export function resolveObserverModel(config: ObserverConfig): { model: string; provider: "openai" | "openrouter" } | null {
  const model = config.model || (config.openrouterKey ? "google/gemini-3.5-flash-lite" : "gpt-5.4-mini");
  const provider = model.includes("/") ? "openrouter" : "openai";
  if (provider === "openrouter" && !config.openrouterKey) return null;
  if (provider === "openai" && !config.openaiKey) return null;
  return { model, provider };
}

export function parseObservation(text: string): Observation {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start < 0 || end <= start) throw new Error("observer returned no JSON");
  const data = JSON.parse(text.slice(start, end + 1));
  if (!data || typeof data !== "object" || Array.isArray(data)) throw new Error("observer JSON is not an object");
  return {
    ...data,
    summary: String(data.summary ?? ""),
    work_transcription: String(data.work_transcription ?? ""),
    progress: String(data.progress ?? "unclear"),
  };
}

export async function observeDesk(
  config: ObserverConfig,
  input: { name: string; reason: string; task: string | null; previous: string | null; secondsWithoutChange: number | null; jpegBase64: string },
  signal?: AbortSignal,
): Promise<Observation> {
  const resolved = resolveObserverModel(config);
  if (!resolved) throw new Error("no observer API key");
  const text = observerUserText(input);
  const image = `data:image/jpeg;base64,${input.jpegBase64}`;

  if (resolved.provider === "openrouter") {
    const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      signal,
      headers: { Authorization: `Bearer ${config.openrouterKey}`, "Content-Type": "application/json", "X-Title": "ScreenTutor Study Room" },
      body: JSON.stringify({
        model: resolved.model,
        messages: [
          { role: "system", content: OBSERVER_SYSTEM },
          { role: "user", content: [{ type: "text", text }, { type: "image_url", image_url: { url: image } }] },
        ],
        response_format: { type: "json_object" },
        temperature: 0.2,
        max_tokens: 900,
        provider: { sort: "throughput", data_collection: "deny", zdr: true },
      }),
    });
    if (!response.ok) throw new Error(`OpenRouter ${response.status}: ${(await response.text()).slice(0, 200)}`);
    const json: any = await response.json();
    return parseObservation(json.choices?.[0]?.message?.content ?? "");
  }

  const response = await fetch(`${config.openaiBaseURL ?? "https://api.openai.com"}/v1/responses`, {
    method: "POST",
    signal,
    headers: { Authorization: `Bearer ${config.openaiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model: resolved.model,
      instructions: OBSERVER_SYSTEM,
      input: [
        {
          role: "user",
          content: [
            { type: "input_text", text },
            { type: "input_image", image_url: image, detail: "high" },
          ],
        },
      ],
      text: { format: { type: "json_object" } },
      ...(resolved.model.startsWith("gpt-5") ? { reasoning: { effort: "low" } } : {}),
      max_output_tokens: 2000,
      store: false,
    }),
  });
  if (!response.ok) throw new Error(`OpenAI ${response.status}: ${(await response.text()).slice(0, 200)}`);
  const json: any = await response.json();
  const output = (json.output ?? [])
    .flatMap((item: any) => item.content ?? [])
    .filter((part: any) => part.type === "output_text")
    .map((part: any) => part.text)
    .join("");
  return parseObservation(output);
}

export function observationNote(name: string, o: Observation | null, observedAt: number): string {
  if (!o) return `${name}: no observation yet.`;
  const age = Math.round((Date.now() - observedAt) / 1000);
  let text = `${name} (${o.progress}, ${age}s ago): ${o.summary}`;
  if (o.work_transcription) text += `\n  Written work: ${o.work_transcription}`;
  if (o.issue && typeof o.issue === "object") {
    text += `\n  Possible ${o.issue.kind} at ${o.issue.location}: ${o.issue.description}`;
  }
  return text;
}
