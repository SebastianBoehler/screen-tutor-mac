"use client";

import katex from "katex";
import { marked } from "marked";
import { useEffect, useMemo, useRef } from "react";

function escapeHtml(text: string) {
  return text.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]!);
}

/** Markdown with KaTeX math ($…$, $$…$$) and ```mermaid diagrams. Raw HTML is escaped. */
export function renderMarkdown(source: string): string {
  const math: string[] = [];
  const protectedSource = source.replace(/\$\$[\s\S]+?\$\$|\$[^$\n]+?\$/g, (match) => {
    math.push(match);
    return `@@MATH${math.length - 1}@@`;
  });
  const renderer = new marked.Renderer();
  renderer.html = (html: string) => escapeHtml(html);
  renderer.code = (text: string, lang?: string) =>
    lang === "mermaid"
      ? `<div class="mermaid">${escapeHtml(text)}</div>`
      : `<pre><code>${escapeHtml(text)}</code></pre>`;
  const html = marked.parse(protectedSource, { renderer, async: false }) as string;
  return html.replace(/@@MATH(\d+)@@/g, (_, index) => {
    const raw = math[Number(index)];
    const display = raw.startsWith("$$");
    const body = display ? raw.slice(2, -2) : raw.slice(1, -1);
    try {
      return katex.renderToString(body, { displayMode: display, throwOnError: false });
    } catch {
      return escapeHtml(raw);
    }
  });
}

export function Markdown({ source }: { source: string }) {
  const ref = useRef<HTMLDivElement>(null);
  const html = useMemo(() => renderMarkdown(source), [source]);

  // The HTML is applied here rather than through dangerouslySetInnerHTML so React never
  // swaps these nodes while Mermaid turns diagram placeholders into SVG.
  useEffect(() => {
    const root = ref.current;
    if (!root) return;
    root.innerHTML = html;
    if (!root.querySelector(".mermaid")) return;
    let cancelled = false;
    import("mermaid")
      .then(async ({ default: mermaid }) => {
        mermaid.initialize({ startOnLoad: false, theme: "neutral", securityLevel: "strict" });
        const nodes = Array.from(root.querySelectorAll<HTMLElement>(".mermaid:not([data-rendered])"));
        for (const [index, node] of nodes.entries()) {
          if (cancelled || !node.isConnected) return;
          try {
            const { svg } = await mermaid.render(`board-diagram-${Date.now()}-${index}`, node.textContent ?? "");
            if (cancelled || !node.isConnected) return;
            node.innerHTML = svg;
            node.setAttribute("data-rendered", "true");
          } catch (error) {
            console.warn("mermaid render failed", error);
          }
        }
      })
      .catch((error: unknown) => console.warn("mermaid failed to load", error));
    return () => {
      cancelled = true;
    };
  }, [html]);

  return <div ref={ref} className="markdown" />;
}
