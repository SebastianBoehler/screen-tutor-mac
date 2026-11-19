import { useId } from 'react';

export interface Point {
  x: number;
  y: number;
}
export function Plot({
  title,
  description,
  points,
  xDomain,
  yDomain,
  xLabel,
  yLabel,
  marker,
  trail,
  step = false,
}: {
  title: string;
  description: string;
  points: Point[];
  xDomain: [number, number];
  yDomain: [number, number];
  xLabel: string;
  yLabel: string;
  marker?: Point;
  trail?: Point[];
  step?: boolean;
}) {
  const id = useId().replace(/:/g, '');
  const x = (value: number) => 52 + ((value - xDomain[0]) / (xDomain[1] - xDomain[0])) * 524;
  const y = (value: number) => 212 - ((value - yDomain[0]) / (yDomain[1] - yDomain[0])) * 190;
  const path = (values: Point[], stepped = false) =>
    values
      .map((point, i) =>
        i === 0
          ? `M${x(point.x)},${y(point.y)}`
          : stepped
            ? `H${x(point.x)}V${y(point.y)}`
            : `L${x(point.x)},${y(point.y)}`,
      )
      .join(' ');
  const number = (value: number) => Number(value.toPrecision(3)).toString();
  return (
    <svg
      className="teaching-plot"
      viewBox="0 0 600 260"
      role="img"
      aria-labelledby={`${id}-title ${id}-desc`}
    >
      <title id={`${id}-title`}>{title}</title>
      <desc id={`${id}-desc`}>{description}</desc>
      <defs>
        <clipPath id={`${id}-clip`}>
          <rect x="52" y="18" width="524" height="194" />
        </clipPath>
      </defs>
      {[0, 0.5, 1].map((part) => {
        const value = yDomain[0] + part * (yDomain[1] - yDomain[0]);
        return (
          <g key={part}>
            <line className="plot-grid" x1="52" x2="576" y1={y(value)} y2={y(value)} />
            <text x="42" y={y(value) + 4} textAnchor="end">
              {number(value)}
            </text>
          </g>
        );
      })}
      <line className="plot-axis" x1="52" x2="52" y1="18" y2="212" />
      <line className="plot-axis" x1="52" x2="576" y1="212" y2="212" />
      {[0, 0.5, 1].map((part) => {
        const value = xDomain[0] + part * (xDomain[1] - xDomain[0]);
        return (
          <text key={part} x={x(value)} y="231" textAnchor="middle">
            {number(value)}
          </text>
        );
      })}
      <text x="314" y="253" textAnchor="middle">
        {xLabel}
      </text>
      <text x="55" y="12">
        {yLabel}
      </text>
      <g clipPath={`url(#${id}-clip)`}>
        <path className="plot-line" d={path(points, step)} />
        {trail && <path className="plot-trail" d={path(trail)} />}
        {marker && (
          <>
            <line
              className="plot-guide"
              x1={x(marker.x)}
              x2={x(marker.x)}
              y1="212"
              y2={y(marker.y)}
            />
            <circle className="plot-point" cx={x(marker.x)} cy={y(marker.y)} r="5" />
          </>
        )}
      </g>
    </svg>
  );
}
