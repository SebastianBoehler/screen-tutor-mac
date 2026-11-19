import { useEffect, useRef, useState } from 'react';
import { useInvestigation } from '../investigation/useInvestigation';
import { isInvestigation } from '../investigation/model';
import type { InteractiveState } from '../interactive/state';
import { now, uid, type Course } from '../domain/models';
import { studyContext } from '../domain/retrieval';
import {
  openCanvasExample,
  prefillEmptyCanvas,
  saveExampleReasoning,
} from '../domain/canvasExamples';
import { isCanvasExample } from '../domain/exampleContent';
import { useWorkspace } from './useWorkspace';
import { useTutor, type Connections } from './useTutor';
import { VoiceSession, type VoiceStatus } from './voice';
import { canvasPresentation, canvasVoiceEvents } from '../canvas/voiceEvents';
import { useCanvasPacing } from '../canvas/useCanvasPacing';

export type Page = 'study' | 'materials' | 'plan' | 'memory';
export function useLearning() {
  const store = useWorkspace();
  const { workspace, current, update } = store;
  useEffect(() => {
    if (!store.ready) return;
    const value = prefillEmptyCanvas(current.current);
    if (value !== current.current) update(() => value);
  }, [store.ready, current, update]);
  const [page, setPage] = useState<Page>('study');
  const [voiceStatus, setVoiceStatus] = useState<VoiceStatus>('off');
  const liveVoice = !['off', 'connecting'].includes(voiceStatus);
  const investigation = useInvestigation(workspace, current, update, store.ready, liveVoice);
  const canvasPacing = useCanvasPacing(
    workspace,
    current,
    update,
    store.ready && page === 'study' && liveVoice,
  );
  const [connections, setConnections] = useState<Connections>({
    provider: 'openrouter',
    openaiKey: '',
    openrouterKey: '',
  });
  const [available, setAvailable] = useState({
    openai: false,
    openrouter: false,
  });
  const [error, setError] = useState('');
  const [firstAudio, setFirstAudio] = useState<number | null>(null);
  const tutor = useTutor(current, update, connections);
  const sendRef = useRef(tutor.send);
  sendRef.current = tutor.send;
  const [voice] = useState(
    () =>
      new VoiceSession({
        status: setVoiceStatus,
        error: setError,
        firstAudio: setFirstAudio,
        transcript: (role, content) => {
          if (!content?.trim()) return;
          const courseId = current.current.selectedCourseId;
          if (courseId)
            update((value) => ({
              ...value,
              messages: [
                ...value.messages,
                { id: uid(), courseId, role, content: content.slice(0, 8000) },
              ],
            }));
        },
        ...canvasVoiceEvents({
          current,
          hold: canvasPacing.hold,
          send: sendRef,
          investigation: investigation.voice,
          turn: canvasPacing.turn,
          error: setError,
        }),
      }),
  );
  useEffect(() => {
    const controller = new AbortController();
    fetch('/api/status', { signal: controller.signal })
      .then((response) => {
        if (!response.ok) throw new Error('The local tutor server is unavailable.');
        return response.json();
      })
      .then(setAvailable)
      .catch((error) => {
        if (!controller.signal.aborted) setError(error.message);
      });
    return () => controller.abort();
  }, []);
  useEffect(() => () => voice.disconnect(), [voice]);
  const course = workspace.courses.find((item) => item.id === workspace.selectedCourseId);
  const activity = workspace.activities.find(
    (item) => item.id === workspace.selectedActivityId && item.courseId === course?.id,
  );
  useEffect(() => {
    if (voice.connected && current.current.selectedCourseId) {
      voice.updateContext(
        studyContext(current.current, activity?.concept ?? '', activity?.mode ?? 'learn'),
        canvasPresentation(workspace),
      );
    }
  }, [
    voice,
    current,
    activity?.id,
    workspace.interactions.length,
    workspace.investigations,
    workspace.canvas,
    workspace.activities.length,
  ]);
  const run = (text: string, options?: Parameters<typeof tutor.send>[1]) => {
    setError('');
    return tutor.send(text, options).catch((error) => {
      setError(error.message);
    });
  };
  async function sendMessage(text: string, image?: string): Promise<boolean> {
    setError('');
    try {
      if (voice.connected) {
        if (image) voice.shareImage(image, text);
        else voice.sendText(text);
        const courseId = current.current.selectedCourseId!;
        update((value) => ({
          ...value,
          messages: [...value.messages, { id: uid(), courseId, role: 'user', content: text }],
        }));
        return true;
      }
      return !!(await run(text, { image }));
    } catch (error) {
      setError((error as Error).message);
      return false;
    }
  }
  function saveExploration(id: string, state: InteractiveState) {
    update((value) => ({
      ...value,
      interactiveStates: { ...value.interactiveStates, [id]: state },
    }));
  }
  function openExample(id?: string) {
    voice.disconnect();
    update((value) => openCanvasExample(value, id));
    setPage('study');
    setError('');
    tutor.setError('');
  }
  function checkReasoning(id = activity?.id) {
    if (!id) return;
    if (current.current.selectedActivityId !== id)
      update((value) => ({ ...value, selectedActivityId: id }));
    if (isCanvasExample(id)) update(saveExampleReasoning);
    else
      void run(`My attempt: ${current.current.drafts[id] ?? ''}`, {
        attempt: true,
        assisted: voice.connected,
      });
  }
  function selectCourse(id: string) {
    voice.disconnect();
    update((value) => ({
      ...value,
      selectedCourseId: id,
      selectedActivityId:
        value.activities.filter((item) => item.courseId === id).at(-1)?.id ?? null,
    }));
    setPage('study');
    setError('');
    tutor.setError('');
  }
  function addCourse(item: Course) {
    voice.disconnect();
    update((value) => ({
      ...value,
      courses: [...value.courses, item],
      selectedCourseId: item.id,
      selectedActivityId: null,
    }));
    setPage('materials');
  }
  function event(kind: 'hint' | 'reveal' | 'explore', id = activity?.id) {
    const target = current.current.activities.find((item) => item.id === id);
    if (!target) return;
    if (
      current.current.interactions.some(
        (item) => item.activityId === target.id && item.kind === kind,
      )
    )
      return;
    update((value) => ({
      ...value,
      interactions: [
        ...value.interactions,
        {
          id: uid(),
          courseId: target.courseId,
          activityId: target.id,
          at: now(),
          kind,
          text:
            kind === 'hint'
              ? 'Requested a cue.'
              : kind === 'explore'
                ? 'Opened or manipulated an interactive model.'
                : 'Revealed the answer.',
          verdict: 'ungraded',
          assisted: true,
        },
      ],
    }));
  }
  function finishExam() {
    if (!activity) return;
    voice.disconnect();
    event('hint');
    update((value) => ({
      ...value,
      activities: value.activities.map((item) =>
        item.id === activity.id ? { ...item, reviewedAt: now() } : item,
      ),
    }));
    void run(
      'The practice exam is finished. Review my recorded answers with source-grounded feedback, then identify one useful next practice target.',
      { mode: 'learn' },
    );
  }
  async function startVoice() {
    setError('');
    try {
      const context = studyContext(current.current, course?.goal ?? '', activity?.mode ?? 'learn');
      if (!context.sources.length && !isInvestigation(current.current.selectedActivityId))
        throw new Error('Add course material or a lecture note before connecting the tutor.');
      await voice.connect(connections.openaiKey, context);
    } catch (error) {
      setError((error as Error).message);
    }
  }
  return {
    ...store,
    canvasPacing,
    page,
    setPage,
    course,
    activity,
    connections,
    setConnections,
    available,
    error: error || tutor.error,
    clearError: () => {
      setError('');
      tutor.setError('');
    },
    setError,
    voice,
    voiceStatus,
    firstAudio,
    tutor,
    run,
    selectCourse,
    selectActivity: (id: string) => {
      if (isInvestigation(id)) investigation.open();
      else
        update((value) => ({
          ...value,
          selectedActivityId: id,
          ...(value.canvas
            ? {
                canvas: {
                  ...value.canvas,
                  pendingActivityIds: value.canvas.pendingActivityIds.filter(
                    (pending) => pending !== id,
                  ),
                },
              }
            : {}),
        }));
      setPage('study');
    },
    openExample,
    investigation,
    openInvestigation: () => {
      voice.disconnect();
      investigation.open();
      setPage('study');
      setError('');
      tutor.setError('');
    },
    checkReasoning,
    saveExploration,
    sendMessage,
    addCourse,
    event,
    startVoice,
    finishExam,
  };
}
