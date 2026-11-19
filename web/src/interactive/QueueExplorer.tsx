import { useEffect, useRef, useState } from 'react';
import type { InteractiveState } from './state';
import { createQueue, queueSummary, stepQueue } from './queueEngine';
import { Plot } from './Plot';
import { Slider } from './Slider';

type State = Extract<InteractiveState, { kind: 'queue' }>;
const eventLimit = 2000;
export function QueueExplorer({
  state,
  onChange,
  onCheckpoint,
}: {
  state: State;
  onChange(value: State): void;
  onCheckpoint(): void;
}) {
  const [playing, setPlaying] = useState(false);
  const live = useRef({ state, onChange, onCheckpoint });
  live.current = { state, onChange, onCheckpoint };
  const step = () => {
    const current = live.current;
    if (current.state.simulation.events >= eventLimit) {
      setPlaying(false);
      current.onCheckpoint();
      return;
    }
    current.onChange({
      ...current.state,
      simulation: stepQueue(
        current.state.simulation,
        current.state.arrivalRate,
        current.state.serviceRate,
      ),
    });
  };
  useEffect(() => {
    if (!playing) return;
    const timer = setInterval(step, 200);
    const hide = () => {
      if (document.hidden) {
        setPlaying(false);
        live.current.onCheckpoint();
      }
    };
    document.addEventListener('visibilitychange', hide);
    return () => {
      clearInterval(timer);
      document.removeEventListener('visibilitychange', hide);
    };
  }, [playing]);
  const changeRates = (arrivalRate: number, serviceRate: number) => {
    setPlaying(false);
    onChange({
      ...state,
      arrivalRate,
      serviceRate,
      simulation: createQueue(arrivalRate, serviceRate),
    });
  };
  const summary = queueSummary(state.simulation, state.arrivalRate, state.serviceRate);
  const history = state.simulation.history;
  const maxTime = Math.max(history[0].x + 1, state.simulation.clock);
  const maxCount = Math.max(4, ...history.map((point) => point.y));
  return (
    <>
      <div
        className="queue-lane"
        aria-label={`${summary.waiting} waiting, server ${summary.inSystem ? 'busy' : 'idle'}`}
      >
        <div className="queue-waiting">
          <span>Waiting · {summary.waiting}</span>
          <div className="queue-people" aria-hidden="true">
            {Array.from({ length: Math.min(summary.waiting, 12) }, (_, i) => (
              <span key={i} />
            ))}
            {summary.waiting > 12 && <b>+{summary.waiting - 12}</b>}
          </div>
        </div>
        <span aria-hidden="true">→</span>
        <div className={`queue-server ${summary.inSystem ? 'busy' : ''}`}>
          Server
          <br />
          <strong>{summary.inSystem ? 'Busy' : 'Idle'}</strong>
        </div>
      </div>
      <Plot
        title="Customers in the system over simulated time"
        description={`After ${summary.events} events at time ${summary.time.toFixed(2)} minutes, ${summary.inSystem} customers are in the system.`}
        points={history}
        xDomain={[history[0].x, maxTime]}
        yDomain={[0, maxCount]}
        xLabel="Simulated time (min)"
        yLabel="Customers N(t)"
        step
      />
      <div className="parameters">
        <Slider
          parameter="arrivalRate"
          label="Arrival rate λ (per min)"
          min={0.25}
          max={20}
          step={0.25}
          value={state.arrivalRate}
          onChange={(rate) => changeRates(rate, state.serviceRate)}
        />
        <Slider
          parameter="serviceRate"
          label="Service rate μ (per min)"
          min={0.25}
          max={20}
          step={0.25}
          value={state.serviceRate}
          onChange={(rate) => changeRates(state.arrivalRate, rate)}
        />
      </div>
      <div className="model-actions">
        <button
          className="primary"
          disabled={summary.events >= eventLimit}
          onClick={() => {
            if (playing) {
              setPlaying(false);
              onCheckpoint();
            } else setPlaying(true);
          }}
        >
          {playing ? 'Pause simulation' : 'Play simulation'}
        </button>
        <button
          className="secondary"
          disabled={playing || summary.events >= eventLimit}
          onClick={() => {
            step();
            onCheckpoint();
          }}
        >
          Step event
        </button>
        <button
          className="text-button"
          onClick={() => {
            setPlaying(false);
            onChange({ ...state, simulation: createQueue(state.arrivalRate, state.serviceRate) });
            onCheckpoint();
          }}
        >
          Reset run
        </button>
      </div>
      <p className="model-result" role="status">
        Event <strong>{summary.events}</strong> · time{' '}
        <strong>{summary.time.toFixed(2)} min</strong> · in system{' '}
        <strong>{summary.inSystem}</strong>
      </p>
      <p className="model-comparison">
        Mean number in system: this run{' '}
        <strong>
          {summary.observedMeanNumber === null
            ? 'not sampled yet'
            : summary.observedMeanNumber.toFixed(2)}
        </strong>{' '}
        · steady-state theory{' '}
        <strong>
          {summary.theoreticalMeanNumber === null
            ? 'no finite mean'
            : summary.theoreticalMeanNumber.toFixed(2)}
        </strong>
      </p>
      {summary.theoreticalMeanNumber === null && (
        <p className="model-note" role="status">
          λ ≥ μ: no stationary distribution.
        </p>
      )}
      <p className="model-note">
        M/M/1 · one server, first-come first-served. Runs start empty; short-run averages can differ
        from theory. Rate changes restart the run. Last 160 events shown · 2,000 events per run.
      </p>
    </>
  );
}
