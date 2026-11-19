import type { InteractiveSpec } from './schema';
import type { InteractiveState } from './state';
import { Plot } from './Plot';
import { Slider } from './Slider';

export function GeneratedExercise({
  spec,
  state,
  onChange,
}: {
  spec: Extract<InteractiveSpec, { kind: 'flashcard' | 'fill-blank' | 'linear' }>;
  state: InteractiveState;
  onChange(value: InteractiveState): void;
}) {
  if (spec.kind === 'flashcard' && state.kind === 'flashcard')
    return (
      <div className="generated-exercise">
        <p>{spec.front}</p>
        {state.revealed && <p className="generated-answer">{spec.back}</p>}
        <button
          className="secondary"
          onClick={() => onChange({ ...state, revealed: !state.revealed })}
        >
          {state.revealed ? 'Hide answer' : 'Show answer'}
        </button>
      </div>
    );
  if (spec.kind === 'fill-blank' && state.kind === 'fill-blank') {
    const matches =
      state.response.trim().toLocaleLowerCase() === spec.answer.trim().toLocaleLowerCase();
    return (
      <div className="generated-exercise">
        <label>
          {spec.before}{' '}
          <input
            aria-label="Missing term"
            value={state.response}
            maxLength={120}
            onChange={(event) =>
              onChange({ ...state, response: event.target.value, checked: false })
            }
          />{' '}
          {spec.after}
        </label>
        <button
          className="secondary"
          disabled={!state.response.trim()}
          onClick={() => onChange({ ...state, checked: true })}
        >
          Check term
        </button>
        {state.checked && (
          <p role="status">
            {matches
              ? 'Matches the expected term.'
              : 'Does not match the expected term. Try again.'}
          </p>
        )}
      </div>
    );
  }
  if (spec.kind === 'linear' && state.kind === 'linear') {
    const points = Array.from({ length: 41 }, (_, i) => {
      const x = i / 4 - 5;
      return { x, y: state.slope * x + state.intercept };
    });
    return (
      <>
        <p className="model-result">
          y = {state.slope} × x {state.intercept < 0 ? '−' : '+'} {Math.abs(state.intercept)}
        </p>
        <Plot
          title="Linear function"
          description={`Slope ${state.slope}, intercept ${state.intercept}.`}
          points={points}
          xDomain={[-5, 5]}
          yDomain={[-30, 30]}
          xLabel="x"
          yLabel="y"
        />
        <div className="parameters">
          <Slider
            parameter="slope"
            label="Slope"
            min={-5}
            max={5}
            step={0.1}
            value={state.slope}
            onChange={(slope) => onChange({ ...state, slope })}
          />
          <Slider
            parameter="intercept"
            label="Intercept"
            min={-5}
            max={5}
            step={0.1}
            value={state.intercept}
            onChange={(intercept) => onChange({ ...state, intercept })}
          />
        </div>
      </>
    );
  }
  return null;
}
