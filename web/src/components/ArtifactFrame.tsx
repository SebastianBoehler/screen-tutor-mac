import { useEffect, useId, useRef, useState, type ReactNode } from 'react';
import { Maximize2, Minimize2, PanelTop } from 'lucide-react';

export function ArtifactFrame({
  title,
  preview,
  children,
  onCollapse,
  active = true,
  activityId,
  showInVoice = false,
}: {
  title: string;
  preview: ReactNode;
  children: ReactNode;
  onCollapse?(): void;
  active?: boolean;
  activityId?: string;
  showInVoice?: boolean;
}) {
  const [expanded, setExpanded] = useState(false);
  const [canvasView, setCanvasView] = useState(false);
  const frameRef = useRef<HTMLElement>(null);
  const id = useId();
  useEffect(() => {
    if (!active) setCanvasView(false);
  }, [active]);
  useEffect(() => {
    if (active && showInVoice) setExpanded(true);
  }, [active, showInVoice]);
  useEffect(() => {
    const open = (event: Event) => {
      if ((event as CustomEvent).detail === activityId) setExpanded(true);
    };
    window.addEventListener('screentutor:open-artifact', open);
    return () => window.removeEventListener('screentutor:open-artifact', open);
  }, [activityId]);
  useEffect(() => {
    if (!canvasView) return;
    const column = frameRef.current?.closest<HTMLElement>('.main-column');
    const composer = column?.querySelector<HTMLElement>('.composer-dock');
    if (!column || !composer) return;
    const update = () =>
      column.style.setProperty('--canvas-composer-height', `${composer.offsetHeight}px`);
    const observer = new ResizeObserver(update);
    observer.observe(composer);
    update();
    return () => {
      observer.disconnect();
      column.style.removeProperty('--canvas-composer-height');
    };
  }, [canvasView]);
  return (
    <section
      ref={frameRef}
      className={`interactive-artifact${expanded ? ' is-expanded' : ''}${canvasView ? ' is-canvas-view' : ''}`}
      aria-label={title}
    >
      <div className="artifact-heading">
        <strong>{title}</strong>
        <div className="artifact-heading-actions">
          {expanded && (
            <button className="secondary" onClick={() => setCanvasView(!canvasView)}>
              <PanelTop size={16} aria-hidden="true" />
              {canvasView ? 'Exit canvas view' : 'Canvas view'}
            </button>
          )}
          <button
            className="secondary"
            aria-expanded={expanded}
            aria-controls={id}
            onClick={() => {
              if (expanded) onCollapse?.();
              setCanvasView(false);
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
      </div>
      {!expanded && preview}
      <div id={id} className="artifact-content" hidden={!expanded}>
        {expanded && children}
      </div>
    </section>
  );
}
