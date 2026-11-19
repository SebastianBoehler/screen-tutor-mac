import { runQueueComparison } from './experiment';

self.onmessage = () => {
  try {
    self.postMessage({ result: runQueueComparison() });
  } catch (error) {
    self.postMessage({ error: error instanceof Error ? error.message : 'The experiment failed.' });
  }
};
