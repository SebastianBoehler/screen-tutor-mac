import { useRef, useState } from 'react';
import { ArrowUp, Camera, Mic, MicOff, Paperclip, Square, X } from 'lucide-react';
import type { VoiceStatus } from '../services/voice';
import type { Message } from '../domain/models';

export function Composer({
  busy,
  receiving,
  status,
  latest,
  image,
  disabled,
  voiceOnly = false,
  onSend,
  onStop,
  onVoice,
  onMute,
  onDisconnect,
  onCamera,
  onFile,
  onClearImage,
  onConversation,
}: {
  busy: boolean;
  receiving: boolean;
  status: VoiceStatus;
  latest?: Message;
  image: string;
  disabled: boolean;
  voiceOnly?: boolean;
  onSend(text: string): Promise<boolean>;
  onStop(): void;
  onVoice(): void;
  onMute(): void;
  onDisconnect(): void;
  onCamera(): void;
  onFile(file: File): void;
  onClearImage(): void;
  onConversation(): void;
}) {
  const [text, setText] = useState('');
  const file = useRef<HTMLInputElement>(null);
  return (
    <div className="composer-dock">
      {latest && (
        <button className="tutor-cue" aria-label="Open tutor response" onClick={onConversation}>
          <span>{latest.content}</span>
        </button>
      )}
      {image && (
        <div className="attachment">
          <img src={image} alt="Note photo ready to share" />
          <span>Note photo · shared when you send</span>
          <button className="icon-button" onClick={onClearImage} aria-label="Remove photo">
            <X size={16} />
          </button>
        </div>
      )}
      <form
        className="composer"
        onSubmit={async (event) => {
          event.preventDefault();
          if ((!text.trim() && !image) || busy) return;
          const value =
            text.trim() ||
            'Look at this photo of my notes and help me reason through the next step.';
          if (await onSend(value))
            setText((current) => (current.trim() === text.trim() ? '' : current));
        }}
      >
        <label className="sr-only" htmlFor="tutor-message">
          Talk to your tutor
        </label>
        <textarea
          id="tutor-message"
          rows={1}
          placeholder={
            voiceOnly
              ? 'Write in the canvas, or connect the live tutor…'
              : 'Ask, think out loud, or show your notes…'
          }
          value={text}
          maxLength={6000}
          disabled={disabled || voiceOnly}
          onChange={(event) => setText(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === 'Enter' && !event.shiftKey && !event.nativeEvent.isComposing) {
              event.preventDefault();
              event.currentTarget.form?.requestSubmit();
            }
          }}
        />
        <div className="composer-controls">
          <div className="row">
            <button
              type="button"
              className="icon-button"
              aria-label="Open note camera"
              title="Show notes"
              disabled={disabled || voiceOnly || busy}
              onClick={onCamera}
            >
              <Camera size={18} />
            </button>
            <button
              type="button"
              className="icon-button"
              aria-label="Attach note photo"
              title="Attach photo"
              disabled={disabled || voiceOnly || busy}
              onClick={() => file.current?.click()}
            >
              <Paperclip size={18} />
            </button>
            <span className="composer-divider" />
            {status === 'off' ? (
              <button type="button" className="voice-button" disabled={disabled} onClick={onVoice}>
                <Mic size={16} />
                Talk to tutor
              </button>
            ) : (
              <>
                <button
                  type="button"
                  className={`voice-button connected ${status === 'muted' ? 'is-muted' : ''}`}
                  disabled={status === 'connecting'}
                  onClick={onMute}
                >
                  {status === 'muted' ? <MicOff size={16} /> : <Mic size={16} />}
                  {status === 'connecting'
                    ? 'Connecting…'
                    : status === 'speaking'
                      ? 'Tutor speaking'
                      : status === 'muted'
                        ? 'Mic muted'
                        : 'Listening'}
                </button>
                <button
                  type="button"
                  className="icon-button"
                  aria-label="Disconnect voice"
                  onClick={onDisconnect}
                >
                  <Square size={14} />
                </button>
              </>
            )}
          </div>
          {busy ? (
            <button
              type="button"
              className="send-button"
              aria-label="Stop generating"
              onClick={onStop}
            >
              <Square size={16} />
            </button>
          ) : (
            <button
              type="submit"
              className="send-button"
              aria-label="Send to tutor"
              disabled={disabled || voiceOnly || (!text.trim() && !image)}
            >
              <ArrowUp size={19} />
            </button>
          )}
        </div>
      </form>
      <input
        ref={file}
        type="file"
        accept="image/*"
        className="sr-only"
        onChange={(event) => {
          const selected = event.target.files?.[0];
          event.target.value = '';
          if (selected) onFile(selected);
        }}
      />
      <p className="composer-caption" role="status">
        {busy ? (receiving ? 'Building your activity…' : 'Preparing your activity…') : ''}
      </p>
    </div>
  );
}
