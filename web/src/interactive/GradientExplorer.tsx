import { gradientStep, loss } from './mathematics';
import type { InteractiveSpec } from './schema';
import type { InteractiveState } from './state';
import { Plot } from './Plot';
import { Slider } from './Slider';

type State = Extract<InteractiveState, { kind: 'gradient-descent' }>;
export function GradientExplorer({
  spec,
  state,
  onChange,
}: {
  spec: Extract<InteractiveSpec, { kind: 'gradient-descent' }>;
  state: State;
  onChange(value: State): void;
}) {
  const bound = Math.max(
    4,
    Math.ceil(Math.abs(state.position)) + 1,
    ...state.trail.map((value) => Math.ceil(Math.abs(value)) + 1),
  );
  const canStep = state.trail.length <= 30 && Math.abs(state.position) <= 16;
  const points = Array.from({ length: 121 }, (_, i) => {
    const x = -bound + (i / 120) * bound * 2;
    return { x, y: loss(x) };
  });
  return (
    <>
      <Plot
        title="Gradient descent on quadratic loss"
        description={`x = ${state.position.toFixed(4)}, loss = ${loss(state.position).toFixed(4)}, learning rate = ${state.learningRate}.`}
        points={points}
        xDomain={[-bound, bound]}
        yDomain={[0, bound * bound]}
        xLabel="Position x"
        yLabel="L(x) = x²"
        marker={{ x: state.position, y: loss(state.position) }}
        trail={state.trail.map((x) => ({ x, y: loss(x) }))}
      />
      <div className="parameters">
        <Slider
          label="Learning rate η"
          min={0.01}
          max={1.2}
          step={0.01}
          value={state.learningRate}
          onChange={(learningRate) => onChange({ ...state, learningRate })}
        />
        <Slider
          label="Starting position"
          min={-4}
          max={4}
          step={0.1}
          value={state.trail[0]}
          onChange={(position) => onChange({ ...state, position, trail: [position] })}
        />
      </div>
      <div className="model-actions">
        <button
          className="primary"
          disabled={!canStep}
          onClick={() => {
            const position = gradientStep(state.position, state.learningRate);
            onChange({ ...state, position, trail: [...state.trail, position] });
          }}
        >
          Take one step
        </button>
        <button
          className="secondary"
          onClick={() => onChange({ ...state, position: spec.position, trail: [spec.position] })}
        >
          Reset path
        </button>
        <output>
          x = {state.position.toFixed(3)} · loss = {loss(state.position).toFixed(3)}
        </output>
      </div>
      <p className="model-note">
        {canStep
          ? 'Exact update: x ← x − η · 2x. Compare small steps with overshooting.'
          : 'Run paused at the step or display limit. Reset the path to continue.'}
      </p>
    </>
  );
}
