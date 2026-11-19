import type { InteractiveState } from './state';
import { loss, survivalProbability } from './mathematics';
import { queueSummary } from './queueEngine';

export const artifactTitles = {
  queue: 'Queue simulation',
  exponential: 'Probability curve',
  'gradient-descent': 'Gradient descent',
  flashcard: 'Flashcard',
  'fill-blank': 'Fill in the blank',
  linear: 'Linear function',
};

export function ArtifactPreview({ state }: { state: InteractiveState }) {
  if (state.kind === 'flashcard' || state.kind === 'fill-blank' || state.kind === 'linear') {
    return (
      <div className="artifact-preview">
        <p className="muted">
          {state.kind === 'flashcard'
            ? 'Recall the answer before turning the card.'
            : state.kind === 'fill-blank'
              ? 'Complete the missing term, then check it.'
              : 'Change the slope and intercept to see how the line moves.'}
        </p>
      </div>
    );
  }
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
            {state.arrivalRate >= state.serviceRate
              ? 'Arrivals match or exceed service capacity; the queue can keep growing.'
              : 'Service is faster than arrivals on average; a queue can still form.'}
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
            ? 'The curve shows the chance of waiting longer than a given time.'
            : 'Each step follows the slope toward lower loss; large steps can overshoot.'}
        </p>
      </div>
    </div>
  );
}
