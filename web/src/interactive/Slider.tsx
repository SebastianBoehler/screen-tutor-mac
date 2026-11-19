import { useId } from 'react';

export function Slider({
  label,
  value,
  min,
  max,
  step,
  onChange,
  disabled = false,
}: {
  label: string;
  value: number;
  min: number;
  max: number;
  step: number;
  onChange(value: number): void;
  disabled?: boolean;
}) {
  const id = useId();
  return (
    <div className="parameter">
      <div className="parameter-label">
        <label htmlFor={id}>{label}</label>
        <output htmlFor={id}>{Number(value.toFixed(3))}</output>
      </div>
      <input
        id={id}
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        disabled={disabled}
        onChange={(event) => onChange(Number(event.target.value))}
      />
    </div>
  );
}
