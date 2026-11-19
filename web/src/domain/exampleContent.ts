import type { ActivityContent } from './schema';

export const queueExampleId = 'illustrative-mm1-queue';
const base: ActivityContent = {
  title: '',
  concept: '',
  body: '',
  question: '',
  choices: [],
  answer: '',
  hint: '',
  explanation: '',
  diagram: null,
  interactive: null,
  sourceIds: [],
};
export const exampleContent = [
  {
    id: queueExampleId,
    label: 'Queue simulation',
    description: 'Run a single-server queue and change arrival or service rates.',
    content: {
      ...base,
      title: 'Why do queues grow near capacity?',
      concept: 'M/M/1 queue: arrival rate near service capacity',
      body: 'Keep service at **μ = 5 per minute**. Move arrivals from **λ = 4** toward **5**, and compare the run with the steady-state mean.',
      question:
        'With μ = 5, why does raising λ from 4 to 4.75 increase the mean number in the system so sharply? Why can a short run differ from theory?',
      answer:
        'For λ < μ, $L = \\lambda / (\\mu - \\lambda)$. With μ = 5, L rises from 4 at λ = 4 to 19 at λ = 4.75. Random bursts leave less spare capacity to clear the queue as λ approaches μ.',
      hint: 'Compare the spare capacity μ − λ before and after the change.',
      explanation:
        'A finite run starts empty and contains random variation. Its mean need not match steady-state theory. At λ ≥ μ there is no stationary distribution.',
      interactive: { kind: 'queue', arrivalRate: 4, serviceRate: 5 },
    },
  },
  {
    id: 'illustrative-exponential',
    label: 'Probability curve',
    description: 'Change a rate and see the probability of waiting longer.',
    content: {
      ...base,
      title: 'How long until the next arrival?',
      concept: 'Exponential waiting time',
      body: 'For Poisson arrivals, $P(T > t) = e^{-\\lambda t}$. Increase the arrival rate and watch the survival curve fall faster.',
      question:
        'If the arrival rate doubles, what happens to the chance of waiting longer than one minute? Explain using the curve.',
      answer:
        'At a fixed positive t, doubling λ squares the survival probability: $e^{-2\\lambda t} = (e^{-\\lambda t})^2$. The probability becomes smaller.',
      hint: 'Compare the curve at the same time before and after doubling the rate.',
      interactive: { kind: 'exponential', rate: 2, time: 0.5, unit: 'minutes' },
    },
  },
  {
    id: 'illustrative-gradient',
    label: 'Gradient descent',
    description: 'Step along a loss curve and explore overshooting.',
    content: {
      ...base,
      title: 'When does a step overshoot?',
      concept: 'Gradient descent step size on a quadratic',
      body: 'Minimize $L(x) = x^2$ using $x_{k+1} = x_k - 2\\eta x_k$. Change the learning rate and take one step at a time.',
      question: 'Try η = 0.1, 0.75 and 1.1. Which steps cross zero, and which make the loss grow?',
      answer:
        'The update multiplies x by $1 - 2\\eta$. For η = 0.1 it shrinks without crossing zero. At 0.75 it crosses zero and shrinks. At 1.1 it crosses zero and grows in magnitude.',
      hint: 'Look at the sign and magnitude of 1 − 2η.',
      interactive: { kind: 'gradient-descent', position: 2, learningRate: 0.1 },
    },
  },
  {
    id: 'illustrative-process',
    label: 'Process diagram',
    description: 'Follow a model from assumptions to a real-world check.',
    content: {
      ...base,
      title: 'Verification and validation answer different questions',
      concept: 'Verification versus validation',
      body: 'A simulation can follow its equations correctly and still represent the real system poorly.',
      question:
        'A queue simulator passes its equation checks but predicts shorter waits than a real service desk. Which check should you investigate next, and why?',
      answer:
        'Investigate validation: compare the model assumptions and predictions with the real service desk. Passing implementation checks supports verification, not fitness for the intended real-world use.',
      hint: 'Separate “did we implement the model correctly?” from “does the model serve its purpose?”',
      diagram: {
        nodes: [
          {
            label: 'Model assumptions',
            detail: 'State the arrivals, service process and intended use.',
          },
          { label: 'Verification', detail: 'Check that the implementation follows the model.' },
          {
            label: 'Validation',
            detail: 'Compare predictions with observations for the intended use.',
          },
        ],
        links: [
          { from: 0, to: 1, label: 'Implement and check' },
          { from: 1, to: 2, label: 'Compare with the system' },
        ],
      },
    },
  },
  {
    id: 'illustrative-math-table',
    label: 'Math & table',
    description: 'Read a rendered equation beside an exact comparison table.',
    content: {
      ...base,
      title: 'A little more demand, a much longer queue',
      concept: 'Nonlinear growth of the M/M/1 steady-state mean',
      body: 'For a stable M/M/1 queue, the mean number **in the system** includes the customer being served.\n\n$$L = \\frac{\\rho}{1 - \\rho}, \\qquad \\rho = \\frac{\\lambda}{\\mu} < 1$$\n\nWith service fixed at **μ = 5 per minute**:\n\n| Arrival rate λ / min | Utilization ρ | Mean in system L |\n| --- | --- | --- |\n| 2.5 | 0.50 | 1 |\n| 4 | 0.80 | 4 |\n| 4.75 | 0.95 | 19 |',
      question:
        'Why does moving from 80% to 95% utilization add so many more customers to the mean?',
      answer:
        'The denominator 1 − ρ shrinks from 0.20 to 0.05. The system has much less spare capacity to clear random bursts, so the mean grows nonlinearly.',
      hint: 'Compare the denominators in the equation, not just the arrival rates.',
    },
  },
] satisfies { id: string; label: string; description: string; content: ActivityContent }[];

export const isCanvasExample = (id: string) => exampleContent.some((item) => item.id === id);
