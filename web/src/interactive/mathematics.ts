export const survivalProbability = (rate: number, time: number) => Math.exp(-rate * time);
export const gradientStep = (position: number, rate: number) => position - rate * 2 * position;
export const loss = (position: number) => position * position;
