import { ArtifactFrame } from '../components/ArtifactFrame';
import { Plot } from '../interactive/Plot';
import type { QueueComparison } from './experiment';

export function ComparisonArtifact({
  result,
  activityId,
}: {
  result: QueueComparison;
  activityId: string;
}) {
  const [first, second] = result.runs;
  return (
    <ArtifactFrame
      title="Queue comparison"
      activityId={activityId}
      preview={
        <div className="artifact-preview investigation-preview">
          <p>Observed mean customers in system</p>
          <div className="row wrap">
            {result.runs.map((run) => (
              <p key={run.arrivalRate}>
                λ = {run.arrivalRate}: <strong>{run.observedMeanNumber.toFixed(2)}</strong>
              </p>
            ))}
          </div>
          <p className="muted">200 min each · finite observations.</p>
        </div>
      }
    >
      <Plot
        title="Cumulative mean customers in the system"
        description="Solid line: arrival rate 4 per minute. Dashed line: 4.75. Both use service rate 5 per minute and start empty."
        points={first.points}
        trail={second.points}
        xDomain={[0, 200]}
        yDomain={[
          0,
          Math.max(5, ...result.runs.flatMap((run) => run.points.map((point) => point.y))),
        ]}
        xLabel="Simulated time (min)"
        yLabel="Cumulative mean customers"
      />
      <p className="model-note">Solid: λ = 4/min · dashed: λ = 4.75/min.</p>
      <div className="investigation-table">
        <table>
          <caption>Finite observations and steady-state theory</caption>
          <thead>
            <tr>
              <th>Arrivals/min</th>
              <th>Observed mean</th>
              <th>Theory λ/(μ−λ)</th>
              <th>Events</th>
            </tr>
          </thead>
          <tbody>
            {result.runs.map((run) => (
              <tr key={run.arrivalRate}>
                <th>{run.arrivalRate}</th>
                <td>{run.observedMeanNumber.toFixed(2)}</td>
                <td>{run.theoreticalMeanNumber.toFixed(2)}</td>
                <td>{run.events}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="model-note">
        M/M/1 · service 5/min · first-come first-served · initially empty · seed 42. Each run covers
        200 minutes. One finite run does not establish a steady-state mean or its uncertainty.
      </p>
    </ArtifactFrame>
  );
}
