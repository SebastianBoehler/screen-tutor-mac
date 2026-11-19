import { useState } from 'react';
import { exampleContent } from '../domain/exampleContent';
import { Dialog } from './Dialog';

export function ExamplePicker({
  disabled,
  onOpen,
}: {
  disabled: boolean;
  onOpen(id: string): void;
}) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button className="text-button" disabled={disabled} onClick={() => setOpen(true)}>
        Examples
      </button>
      {open && (
        <Dialog title="Canvas examples" onClose={() => setOpen(false)}>
          <p className="muted">Illustrative and ungraded. Each example saves your work locally.</p>
          <div className="example-options">
            {exampleContent.map((example) => (
              <button
                className="secondary"
                key={example.id}
                onClick={() => {
                  onOpen(example.id);
                  setOpen(false);
                }}
              >
                <strong>{example.label}</strong>
                <span>{example.description}</span>
              </button>
            ))}
          </div>
        </Dialog>
      )}
    </>
  );
}
