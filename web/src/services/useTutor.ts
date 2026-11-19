import { useEffect, useRef, useState } from 'react';
import type { Workspace } from '../domain/models';
import { uid, now } from '../domain/models';
import { studyContext } from '../domain/retrieval';
import { applyReply } from '../domain/applyReply';

export interface Connections {
  openaiKey: string;
  openrouterKey: string;
  provider: 'openai' | 'openrouter';
}
export function useTutor(
  current: React.RefObject<Workspace>,
  update: (change: (value: Workspace) => Workspace) => void,
  connections: Connections,
) {
  const [busy, setBusy] = useState(false);
  const [receiving, setReceiving] = useState(false);
  const [error, setError] = useState('');
  const [latency, setLatency] = useState<number | null>(null);
  const controller = useRef<AbortController | null>(null);
  useEffect(() => () => controller.current?.abort(), []);
  async function send(
    text: string,
    options: {
      attempt?: boolean;
      assisted?: boolean;
      image?: string;
      mode?: 'learn' | 'exam';
    } = {},
  ) {
    if (controller.current) throw new Error('Wait for the current activity, or stop it first.');
    const snapshot = current.current;
    const courseId = snapshot.selectedCourseId;
    if (!courseId) throw new Error('Choose a course first.');
    const active = snapshot.activities.find((item) => item.id === snapshot.selectedActivityId);
    const context = studyContext(
      snapshot,
      text,
      options.mode ?? (active?.reviewedAt ? 'learn' : active?.mode) ?? 'learn',
    );
    if (!context.sources.length)
      throw new Error('Add course material or a lecture note before starting your study session.');
    const attemptId = options.attempt && context.activityId ? uid() : undefined;
    const userMessage = {
      id: uid(),
      courseId,
      role: 'user' as const,
      content: text,
    };
    update((value) => ({
      ...value,
      messages: [...value.messages, userMessage],
      interactions: attemptId
        ? [
            ...value.interactions,
            {
              id: attemptId,
              courseId,
              activityId: context.activityId!,
              at: now(),
              kind: 'attempt',
              text,
              verdict: 'ungraded',
              assisted: context.assisted || !!options.assisted,
            },
          ]
        : value.interactions,
    }));
    const abort = new AbortController();
    controller.current = abort;
    setError('');
    setBusy(true);
    setReceiving(false);
    const started = performance.now();
    try {
      const messages = [
        ...snapshot.messages.filter((item) => item.courseId === courseId).slice(-10),
        userMessage,
      ].map(({ role, content }) => ({ role, content }));
      const { requestTutor } = await import('./tutor');
      const reply = await requestTutor(
        {
          provider: connections.provider,
          context,
          messages,
          image: options.image,
        },
        connections.provider === 'openai' ? connections.openaiKey : connections.openrouterKey,
        abort.signal,
        () => setReceiving(true),
      );
      if (abort.signal.aborted || current.current.selectedCourseId !== courseId)
        return 'The request was stopped.';
      update((value) => {
        const result = applyReply(value, reply, courseId, attemptId);
        if (reply.activity) result.activities[result.activities.length - 1].mode = context.mode;
        return result;
      });
      setLatency(Math.round(performance.now() - started));
      return reply.message;
    } catch (error) {
      const message = abort.signal.aborted
        ? 'Generation stopped. Your saved work is available.'
        : error instanceof Error
          ? error.message
          : 'The tutor could not respond.';
      setError(message);
      throw new Error(message);
    } finally {
      controller.current = null;
      setBusy(false);
      setReceiving(false);
    }
  }
  return {
    send,
    busy,
    receiving,
    error,
    setError,
    latency,
    stop: () => controller.current?.abort(),
  };
}
