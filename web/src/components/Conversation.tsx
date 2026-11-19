import { lazy, Suspense } from 'react';
import type { Message } from '../domain/models';
import { Dialog } from './Dialog';

const RichText = lazy(() => import('./RichText'));
export function Conversation({ messages, onClose }: { messages: Message[]; onClose(): void }) {
  return (
    <Dialog title="Your conversation" onClose={onClose}>
      <div className="conversation-log">
        {messages.length === 0 ? (
          <p className="muted">
            Think out loud or ask your tutor a question. Your activities stay on the canvas.
          </p>
        ) : (
          messages.map((message) => (
            <article key={message.id} className={`conversation-turn ${message.role}`}>
              <span className="eyebrow">{message.role === 'user' ? 'You' : 'Tutor'}</span>
              <Suspense fallback={<p>{message.content}</p>}>
                <RichText text={message.content} />
              </Suspense>
            </article>
          ))
        )}
      </div>
    </Dialog>
  );
}
