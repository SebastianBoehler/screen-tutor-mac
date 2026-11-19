import type { InteractiveState } from './state';
import { loss, survivalProbability } from './mathematics';
import { queueSummary } from './queueEngine';

export const artifactTitles = {
  queue: 'Queue simulation',
  exponential: 'Probability curve',
  'gradient-descent': 'Gradient descent',
};

export function ArtifactPreview({ state }: { state: InteractiveState }) {
  if (state.kind === 'queue') {
    const summary = queueSummary(state.simulation, state.arrivalRate, state.serviceRate);
    return (
      <div className="artifact-preview">
        <div className="preview-queue" aria-hidden="true">
          <span>{summary.waiting} waiting</span>
          <span>→</span>
          <span className="preview-server">{summary.inSystem ? 'Busy' : 'Idle'}</span>
        </div>
        <div>
          <p>
            λ {state.arrivalRate} / min · μ {state.serviceRate} / min
          </p>
          <p className="muted">
            Event {summary.events} · {summary.inSystem} in system
          </p>
        </div>
      </div>
    );
  }
  const exponential = state.kind === 'exponential';
  const points = Array.from({ length: 61 }, (_, i) => {
    const x = i / 60;
    const y = exponential ? survivalProbability(state.rate, x * 3) : loss(x * 2 - 1);
    return `${8 + x * 164},${78 - y * 64}`;
  }).join(' ');
  return (
    <div className="artifact-preview">
      <svg
        viewBox="0 0 180 90"
        role="img"
        aria-label={
          exponential ? 'Exponential survival curve preview' : 'Quadratic loss curve preview'
        }
      >
        <path className="plot-axis" d="M8 8V78H172" fill="none" />
        <polyline className="plot-line" points={points} />
      </svg>
      <div>
        <p>
          {exponential
            ? `P(T > ${state.time}) = ${survivalProbability(state.rate, state.time).toFixed(4)}`
            : `x = ${state.position.toFixed(3)} · loss = ${loss(state.position).toFixed(3)}`}
        </p>
        <p className="muted">
          {exponential
            ? `Arrival rate λ = ${state.rate}`
            : `Learning rate η = ${state.learningRate} · ${state.trail.length - 1} steps`}
        </p>
      </div>
    </div>
  );
}
