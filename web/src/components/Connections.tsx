import { useState } from 'react';
import { KeyRound } from 'lucide-react';
import { Dialog } from './Dialog';
import type { Connections as ConnectionValues } from '../services/useTutor';

export function Connections({
  value,
  available,
  onSave,
  onClose,
}: {
  value: ConnectionValues;
  available: { openai: boolean; openrouter: boolean };
  onSave(value: ConnectionValues): void;
  onClose(): void;
}) {
  const [draft, setDraft] = useState(value);
  return (
    <Dialog title="Connect your tutor" onClose={onClose}>
      <p className="muted">
        Use your own API account. Your provider bills you directly. ChatGPT subscriptions do not
        cover this voice connection.
      </p>
      <form
        onSubmit={(event) => {
          event.preventDefault();
          onSave(draft);
        }}
      >
        <label>
          Text and activity provider
          <select
            value={draft.provider}
            onChange={(event) =>
              setDraft({
                ...draft,
                provider: event.target.value as ConnectionValues['provider'],
              })
            }
          >
            <option value="openai">OpenAI · GPT-5.4 mini</option>
            <option value="openrouter">OpenRouter · Gemini 3.5 Flash</option>
          </select>
        </label>
        <label>
          OpenAI API key
          <input
            type="password"
            autoComplete="off"
            spellCheck={false}
            value={draft.openaiKey}
            onChange={(event) => setDraft({ ...draft, openaiKey: event.target.value })}
            placeholder={
              available.openai ? 'Configured on this local server' : 'Required for live voice'
            }
          />
        </label>
        {draft.provider === 'openrouter' && (
          <label>
            OpenRouter API key
            <input
              type="password"
              autoComplete="off"
              spellCheck={false}
              value={draft.openrouterKey}
              onChange={(event) => setDraft({ ...draft, openrouterKey: event.target.value })}
              placeholder={
                available.openrouter ? 'Configured on this local server' : 'Your OpenRouter API key'
              }
            />
          </label>
        )}
        <p className="privacy-note">
          <KeyRound size={16} />
          Entered keys stay in this tab’s memory. Reloading clears them. They are sent only to your
          local server for provider calls.
        </p>
        <p className="muted">
          Relevant course excerpts and conversation are sent when you ask the tutor. Photos are
          shared only when you choose.
        </p>
        <div className="dialog-actions">
          <button className="primary">Use these connections</button>
        </div>
      </form>
    </Dialog>
  );
}
