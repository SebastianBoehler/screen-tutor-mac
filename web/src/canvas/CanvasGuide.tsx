import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { MousePointer2, X } from 'lucide-react';
import { registerCanvasGuide, type CanvasChange, type GuidanceCommand } from './guidance';

type Cue = {
  command: Exclude<GuidanceCommand, { action: 'clear' }>;
  change?: CanvasChange;
  target: Element;
  sequence: number;
};
const selectors: Record<string, string> = {
  artifact: '.interactive-artifact',
  plot: '.teaching-plot',
  parameters: '.parameters',
  result:
    '.model-result, .model-comparison, .generated-answer, .investigation-preview, .investigation-table',
  question: '.prediction, .investigation-question',
  diagram: '.mechanism',
};
export function CanvasGuide({
  activityId,
  active,
  voiceConnected,
}: {
  activityId: string;
  active: boolean;
  voiceConnected: boolean;
}) {
  const anchor = useRef<HTMLDivElement>(null);
  const [host, setHost] = useState<HTMLElement | null>(null);
  useEffect(() => setHost(anchor.current?.parentElement ?? null), []);
  const latest = useRef({ active });
  latest.current = { active };
  const sequence = useRef(0);
  const [cue, setCue] = useState<Cue | null>(null);
  const [bounds, setBounds] = useState({ left: 0, top: 0, width: 0, height: 0 });
  useEffect(() => {
    if (!active) {
      sequence.current++;
      setCue(null);
    }
  }, [active]);
  useEffect(
    () =>
      registerCanvasGuide(activityId, async (command, change) => {
        if (!latest.current.active) throw new Error('The selected canvas changed. Inspect again.');
        const token = ++sequence.current;
        if (command.action === 'clear') {
          setCue(null);
          return JSON.stringify({ cleared: true });
        }
        const host = anchor.current?.parentElement;
        if (!host) throw new Error('The canvas is unavailable.');
        if (command.target !== 'question' && command.target !== 'diagram')
          window.dispatchEvent(
            new CustomEvent('screentutor:open-artifact', { detail: activityId }),
          );
        const selector = command.target.startsWith('parameter:')
          ? `[data-canvas-parameter="${command.target.slice(10)}"]`
          : selectors[command.target];
        const deadline = performance.now() + 1500;
        let target: Element | null = null;
        while (
          performance.now() < deadline &&
          token === sequence.current &&
          latest.current.active
        ) {
          target = host.querySelector(selector);
          if (target && target.getBoundingClientRect().height > 0) break;
          await new Promise((resolve) => setTimeout(resolve, 30));
        }
        if (token !== sequence.current || !latest.current.active)
          throw new Error('The canvas cue was superseded.');
        if (!target || !target.getBoundingClientRect().height)
          throw new Error('That visual target is unavailable on this artifact.');
        setCue({ command, change, target, sequence: token });
        const rect = target.getBoundingClientRect();
        const viewport = host.closest('.main-content')?.getBoundingClientRect();
        return JSON.stringify({
          activityId,
          target: command.target,
          cue: command.action,
          visible:
            rect.bottom > (viewport?.top ?? 0) && rect.top < (viewport?.bottom ?? innerHeight),
          changed: change ?? null,
        });
      }),
    [activityId],
  );
  useLayoutEffect(() => {
    if (!cue) return;
    const host = anchor.current?.parentElement;
    if (!host) return;
    const position = () => {
      const parent = host.getBoundingClientRect(),
        target = cue.target.getBoundingClientRect();
      setBounds({
        left: target.left - parent.left,
        top: target.top - parent.top,
        width: target.width,
        height: target.height,
      });
    };
    const observer = new ResizeObserver(position);
    observer.observe(host);
    observer.observe(cue.target);
    position();
    window.addEventListener('resize', position);
    const changed = cue.change
      ? [cue.target, ...host.querySelectorAll('.teaching-plot, .model-result, .model-comparison')]
      : [];
    changed.forEach((element) => {
      element.classList.remove('canvas-change');
      void element.getBoundingClientRect();
      element.classList.add('canvas-change');
    });
    const timer = setTimeout(
      () => changed.forEach((element) => element.classList.remove('canvas-change')),
      900,
    );
    return () => {
      observer.disconnect();
      window.removeEventListener('resize', position);
      clearTimeout(timer);
      changed.forEach((element) => element.classList.remove('canvas-change'));
    };
  }, [cue]);
  return (
    <>
      <div
        ref={anchor}
        className={`canvas-guide${active && (voiceConnected || cue) ? ' is-ready' : ''}`}
        data-canvas-guidance={cue?.command.target}
      >
        {cue && (
          <div className="canvas-cue-label" role="status">
            <span>
              Tutor · {cue.command.label}
              {cue.change?.restarted ? ' · run restarted' : ''}
            </span>
            <button
              aria-label="Clear tutor cue"
              onClick={() => {
                sequence.current++;
                setCue(null);
              }}
            >
              <X size={16} />
            </button>
          </div>
        )}
      </div>
      {cue &&
        host &&
        createPortal(
          <div className="canvas-cue" style={bounds} key={cue.sequence} aria-hidden="true">
            {cue.command.action === 'point' && (
              <MousePointer2 className="canvas-tutor-pointer" size={24} fill="currentColor" />
            )}
          </div>,
          host,
        )}
    </>
  );
}
