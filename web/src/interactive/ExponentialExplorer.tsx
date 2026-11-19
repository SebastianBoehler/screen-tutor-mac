import { survivalProbability } from './mathematics';
import type { InteractiveSpec } from './schema';
import type { InteractiveState } from './state';
import { Plot } from './Plot';
import { Slider } from './Slider';

type State = Extract<InteractiveState, { kind: 'exponential' }>;
export function ExponentialExplorer({
  spec,
  state,
  onChange,
}: {
  spec: Extract<InteractiveSpec, { kind: 'exponential' }>;
  state: State;
  onChange(value: State): void;
}) {
  const probability = survivalProbability(state.rate, state.time);
  const unit = spec.unit === 'seconds' ? 's' : 'min';
  const points = Array.from({ length: 161 }, (_, i) => ({
    x: i / 16,
    y: survivalProbability(state.rate, i / 16),
  }));
  return (
    <>
      <Plot
        title="Exponential survival probability"
        description={`At rate ${state.rate} per ${unit}, P(T > ${state.time}) = ${probability.toFixed(4)}.`}
        points={points}
        xDomain={[0, 10]}
        yDomain={[0, 1]}
        xLabel={`Time (${unit})`}
        yLabel="P(T > t)"
        marker={{ x: state.time, y: probability }}
      />
      <div className="parameters">
        <Slider
          parameter="rate"
          label={`Arrival rate λ (per ${unit})`}
          min={0.1}
          max={8}
          step={0.1}
          value={state.rate}
          onChange={(rate) => onChange({ ...state, rate })}
        />
        <Slider
          parameter="time"
          label={`Time t (${unit})`}
          min={0}
          max={10}
          step={0.1}
          value={state.time}
          onChange={(time) => onChange({ ...state, time })}
        />
      </div>
      <p className="model-result" role="status">
        P(T &gt; {state.time}) = <strong>{probability.toFixed(4)}</strong>
      </p>
      <p className="model-note">
        Poisson arrivals at a constant rate. The curve shows exact probabilities, not sampled
        estimates.
      </p>
    </>
  );
}
