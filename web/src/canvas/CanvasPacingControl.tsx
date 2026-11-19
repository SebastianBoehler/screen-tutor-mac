import type { useCanvasPacing } from './useCanvasPacing';

export function CanvasPacingControl({
  pacing,
  preparing,
  onStop,
  voiceConnected,
}: {
  pacing: ReturnType<typeof useCanvasPacing>;
  preparing: boolean;
  onStop(): void;
  voiceConnected: boolean;
}) {
  return (
    <div className="canvas-pacing row wrap">
      <button
        className="text-button"
        aria-pressed={pacing.held}
        onClick={() => pacing.hold(!pacing.held)}
      >
        {pacing.held ? 'View held' : 'Hold view'}
      </button>
      {preparing && (
        <>
          <span className="muted" role="status">
            Preparing view…
          </span>
          <button className="text-button" onClick={onStop}>
            Stop preparing
          </button>
        </>
      )}
      {pacing.pending && (
        <button className="secondary" onClick={pacing.show}>
          Show prepared view<span className="sr-only">: {pacing.pending.title}</span>
        </button>
      )}
      {!voiceConnected && pacing.held && (
        <span className="muted">New views wait until you choose “Show prepared view”.</span>
      )}
      {pacing.pending && (
        <span className="sr-only" role="status">
          New view prepared.{' '}
          {pacing.held ? 'The current view is held.' : 'Waiting for a quiet pause.'}
        </span>
      )}
    </div>
  );
}
