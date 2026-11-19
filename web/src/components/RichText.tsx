import { useEffect, useState } from 'react';

export default function RichText({ text }: { text: string }) {
  const [html, setHtml] = useState('');
  const [error, setError] = useState('');
  useEffect(() => {
    let active = true;
    Promise.all([
      import('marked'),
      import('dompurify'),
      import('katex'),
      import('katex/dist/katex.min.css'),
    ])
      .then(([{ marked }, { default: purify }, katex]) => {
        const math: string[] = [];
        const source = text.replace(/\$\$[\s\S]+?\$\$|\$[^$\n]+?\$/g, (value) => {
          math.push(value);
          return `SCREENTUTORMATH${math.length - 1}TOKEN`;
        });
        const clean = purify.sanitize(marked.parse(source, { async: false }), {
          USE_PROFILES: { html: true },
          FORBID_TAGS: ['img', 'iframe', 'style', 'form', 'input', 'button'],
          FORBID_ATTR: ['style', 'id'],
          ALLOW_DATA_ATTR: false,
        });
        const result = clean.replace(/SCREENTUTORMATH(\d+)TOKEN/g, (_, index) => {
          const raw = math[Number(index)];
          const display = raw.startsWith('$$');
          return katex.renderToString(display ? raw.slice(2, -2) : raw.slice(1, -1), {
            displayMode: display,
            throwOnError: false,
            trust: false,
            maxExpand: 1000,
          });
        });
        if (active) {
          setHtml(result);
          setError('');
        }
      })
      .catch(() => {
        if (active) setError('The rich content renderer could not load. Reload the page to retry.');
      });
    return () => {
      active = false;
    };
  }, [text]);
  if (error) return <p role="alert">{error}</p>;
  if (!html) return <div className="prose">{text}</div>;
  return (
    <div
      className="prose"
      dangerouslySetInnerHTML={{ __html: html }}
      onClick={(event) => {
        const anchor = (event.target as HTMLElement).closest('a');
        if (anchor) {
          event.preventDefault();
          if (/^https?:\/\//i.test(anchor.href))
            window.open(anchor.href, '_blank', 'noopener,noreferrer');
        }
      }}
    />
  );
}
