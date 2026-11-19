import { lazy, Suspense } from 'react';
import { ArtifactFrame } from '../components/ArtifactFrame';
import type { InteractiveSpec } from './schema';
import type { InteractiveState } from './state';
import { ArtifactPreview, artifactTitles } from './ArtifactPreview';
import { GeneratedExercise } from './GeneratedExercise';

const ExponentialExplorer = lazy(() =>
  import('./ExponentialExplorer').then((module) => ({ default: module.ExponentialExplorer })),
);
const GradientExplorer = lazy(() =>
  import('./GradientExplorer').then((module) => ({ default: module.GradientExplorer })),
);
const QueueExplorer = lazy(() =>
  import('./QueueExplorer').then((module) => ({ default: module.QueueExplorer })),
);
export function InteractiveArtifact({
  spec,
  state,
  onChange,
  onCheckpoint,
  active,
  activityId,
  voiceConnected,
}: {
  spec: InteractiveSpec;
  state: InteractiveState;
  onChange(value: InteractiveState): void;
  onCheckpoint(): void;
  active: boolean;
  activityId: string;
  voiceConnected: boolean;
}) {
  return (
    <ArtifactFrame
      title={artifactTitles[spec.kind]}
      preview={<ArtifactPreview state={state} />}
      onCollapse={onCheckpoint}
      active={active}
      activityId={activityId}
      showInVoice={voiceConnected && spec.kind === 'flashcard'}
      collapseOnLeave={voiceConnected}
    >
      <Suspense fallback={<p role="status">Loading exploration…</p>}>
        {(spec.kind === 'flashcard' || spec.kind === 'fill-blank' || spec.kind === 'linear') && (
          <GeneratedExercise spec={spec} state={state} onChange={onChange} />
        )}
        {spec.kind === 'exponential' && state.kind === 'exponential' && (
          <ExponentialExplorer spec={spec} state={state} onChange={onChange} />
        )}
        {spec.kind === 'gradient-descent' && state.kind === 'gradient-descent' && (
          <GradientExplorer spec={spec} state={state} onChange={onChange} />
        )}
        {spec.kind === 'queue' && state.kind === 'queue' && (
          <QueueExplorer state={state} onChange={onChange} onCheckpoint={onCheckpoint} />
        )}
      </Suspense>
    </ArtifactFrame>
  );
}
