import { createQueue, stepQueue } from '../interactive/queueEngine';
import type { Point } from '../interactive/Plot';

export interface ComparisonRun {
  arrivalRate: number;
  serviceRate: number;
  time: number;
  events: number;
  completed: number;
  observedMeanNumber: number;
  theoreticalMeanNumber: number;
  points: Point[];
}
export interface QueueComparison {
  runs: ComparisonRun[];
}

/** Equal time horizons, including the area after the last event before each checkpoint. */
export function runQueueComparison(): QueueComparison {
  const serviceRate = 5;
  return {
    runs: [4, 4.75].map((arrivalRate) => {
      let state = createQueue(arrivalRate, serviceRate);
      const points: Point[] = [{ x: 0, y: 0 }];
      for (let time = 5; time <= 200; time += 5) {
        while (Math.min(state.nextArrival, state.nextDeparture ?? Infinity) <= time) {
          if (state.events >= 100_000) throw new Error('The experiment exceeded its event limit.');
          state = stepQueue(state, arrivalRate, serviceRate);
        }
        const area = state.areaNumber + state.customers.length * (time - state.clock);
        points.push({ x: time, y: area / time });
      }
      return {
        arrivalRate,
        serviceRate,
        time: 200,
        events: state.events,
        completed: state.completed,
        observedMeanNumber: points.at(-1)!.y,
        theoreticalMeanNumber: arrivalRate / (serviceRate - arrivalRate),
        points,
      };
    }),
  };
}
