export interface QueueState {
  clock: number;
  nextArrival: number;
  nextDeparture: number | null;
  customers: number[];
  arrived: number;
  completed: number;
  areaNumber: number;
  totalSystemTime: number;
  events: number;
  randomState: number;
  lastEvent: 'arrival' | 'departure' | null;
  history: { x: number; y: number }[];
}
function exponential(seed: number, rate: number) {
  const next = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
  const uniform = (next + 0.5) / 4294967296;
  return { seed: next, interval: -Math.log(uniform) / rate };
}
export function createQueue(arrivalRate: number, _serviceRate: number): QueueState {
  const first = exponential(42, arrivalRate);
  return {
    clock: 0,
    nextArrival: first.interval,
    nextDeparture: null,
    customers: [],
    arrived: 0,
    completed: 0,
    areaNumber: 0,
    totalSystemTime: 0,
    events: 0,
    randomState: first.seed,
    lastEvent: null,
    history: [{ x: 0, y: 0 }],
  };
}
/** FCFS, one server, exponential interarrivals and service, initially empty. */
export function stepQueue(state: QueueState, arrivalRate: number, serviceRate: number): QueueState {
  const arrival = state.nextDeparture === null || state.nextArrival <= state.nextDeparture;
  const clock = arrival ? state.nextArrival : state.nextDeparture!;
  const next = {
    ...state,
    customers: [...state.customers],
    clock,
    events: state.events + 1,
    areaNumber: state.areaNumber + state.customers.length * (clock - state.clock),
    lastEvent: arrival ? ('arrival' as const) : ('departure' as const),
  };
  const draw = (rate: number) => {
    const result = exponential(next.randomState, rate);
    next.randomState = result.seed;
    return result.interval;
  };
  if (arrival) {
    next.customers.push(clock);
    next.arrived++;
    next.nextArrival = clock + draw(arrivalRate);
    if (state.customers.length === 0) next.nextDeparture = clock + draw(serviceRate);
  } else {
    const entered = next.customers.shift()!;
    next.completed++;
    next.totalSystemTime += clock - entered;
    next.nextDeparture = next.customers.length ? clock + draw(serviceRate) : null;
  }
  next.history = [...state.history, { x: clock, y: next.customers.length }].slice(-160);
  return next;
}
export function queueSummary(state: QueueState, arrivalRate: number, serviceRate: number) {
  const stable = arrivalRate < serviceRate;
  return {
    time: state.clock,
    events: state.events,
    inSystem: state.customers.length,
    waiting: Math.max(0, state.customers.length - 1),
    completed: state.completed,
    observedMeanNumber: state.clock > 0 ? state.areaNumber / state.clock : null,
    observedMeanTime: state.completed > 0 ? state.totalSystemTime / state.completed : null,
    load: arrivalRate / serviceRate,
    theoreticalMeanNumber: stable ? arrivalRate / (serviceRate - arrivalRate) : null,
    theoreticalMeanTime: stable ? 1 / (serviceRate - arrivalRate) : null,
  };
}
