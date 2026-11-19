import { useId, useState, type ReactNode } from 'react';
import { Maximize2, Minimize2 } from 'lucide-react';

export function ArtifactFrame({
  title,
  preview,
  children,
  onCollapse,
}: {
  title: string;
  preview: ReactNode;
  children: ReactNode;
  onCollapse?(): void;
}) {
  const [expanded, setExpanded] = useState(false);
  const id = useId();
  return (
    <section className="interactive-artifact" aria-label={title}>
      <div className="artifact-heading">
        <strong>{title}</strong>
        <button
          className="secondary"
          aria-expanded={expanded}
          aria-controls={id}
          onClick={() => {
            if (expanded) onCollapse?.();
            setExpanded(!expanded);
          }}
        >
          {expanded ? (
            <Minimize2 size={16} aria-hidden="true" />
          ) : (
            <Maximize2 size={16} aria-hidden="true" />
          )}
          {expanded ? 'Collapse' : 'Expand'}
        </button>
      </div>
      {!expanded && preview}
      <div id={id} className="artifact-content" hidden={!expanded}>
        {expanded && children}
      </div>
    </section>
  );
}
