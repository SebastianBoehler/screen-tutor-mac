// Markdown with KaTeX math ($…$, $$…$$) and ```mermaid diagrams, using the
// marked, katex and mermaid browser builds loaded by room.html. Raw HTML in the
// source is escaped, so board content can never inject markup.

declare const marked: any;
declare const katex: any;
declare const mermaid: any;

export function escapeHtml(text: string): string {
  return text.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
}

export function renderMarkdown(source: string): string {
  if (typeof marked === "undefined") return `<pre>${escapeHtml(source)}</pre>`;
  const math: string[] = [];
  const protectedSource = source.replace(/\$\$[\s\S]+?\$\$|\$[^$\n]+?\$/g, (match) => {
    math.push(match);
    return `@@MATH${math.length - 1}@@`;
  });
  const renderer = new marked.Renderer();
  renderer.html = (html: string) => escapeHtml(html);
  renderer.code = (text: string, lang?: string) =>
    lang === "mermaid" ? `<div class="mermaid">${escapeHtml(text)}</div>` : `<pre><code>${escapeHtml(text)}</code></pre>`;
  renderer.link = (href: string, _title: string, text: string) =>
    /^https?:\/\//i.test(href) ? `<a href="${escapeHtml(href)}" target="_blank" rel="noopener noreferrer">${text}</a>` : text;
  renderer.image = (_href: string, _title: string, text: string) => escapeHtml(text ?? "");
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

let mermaidReady = false;
let diagramCounter = 0;

/** Renders into `root` and turns mermaid placeholders into SVG. */
export async function renderMarkdownInto(root: HTMLElement, source: string): Promise<void> {
  root.classList.add("markdown");
  root.innerHTML = renderMarkdown(source);
  const nodes = Array.from(root.querySelectorAll<HTMLElement>(".mermaid"));
  if (!nodes.length || typeof mermaid === "undefined") return;
  if (!mermaidReady) {
    mermaid.initialize({ startOnLoad: false, theme: "neutral", securityLevel: "strict" });
    mermaidReady = true;
  }
  for (const node of nodes) {
    if (!node.isConnected) return;
    try {
      const { svg } = await mermaid.render(`board-diagram-${diagramCounter++}`, node.textContent ?? "");
      if (node.isConnected) node.innerHTML = svg;
    } catch (error) {
      console.warn("mermaid render failed", error);
    }
  }
}
