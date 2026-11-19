import { useState } from 'react';
import { Pencil, Trash2 } from 'lucide-react';
import { now, type Workspace } from '../domain/models';

export function Memory({
  workspace,
  update,
}: {
  workspace: Workspace;
  update(change: (value: Workspace) => Workspace): void;
}) {
  const [editing, setEditing] = useState<string | null>(null);
  const [draft, setDraft] = useState('');
  const memories = workspace.memories.filter(
    (item) => item.courseId === workspace.selectedCourseId,
  );
  return (
    <section className="page-content">
      <span className="eyebrow">Learner memory</span>
      <h1>A tutor that learns with you.</h1>
      <p className="page-intro">
        Revisable observations about your reasoning, drawn from your attempts. You can correct or
        remove any of them.
      </p>
      {memories.length === 0 && (
        <div className="empty-inline">
          <h2>No assumptions yet.</h2>
          <p>Your tutor will build context from your actual work.</p>
        </div>
      )}
      <div className="memory-list">
        {memories.map((memory) => (
          <article className="memory-row" key={memory.id}>
            <span className="eyebrow">Teaching hypothesis · editable</span>
            {editing === memory.id ? (
              <form
                onSubmit={(event) => {
                  event.preventDefault();
                  update((value) => ({
                    ...value,
                    memories: value.memories.map((item) =>
                      item.id === memory.id
                        ? { ...item, text: draft.trim(), updatedAt: now() }
                        : item,
                    ),
                  }));
                  setEditing(null);
                }}
              >
                <textarea
                  autoFocus
                  maxLength={700}
                  value={draft}
                  onChange={(event) => setDraft(event.target.value)}
                />
                <button className="secondary" disabled={!draft.trim()}>
                  Save correction
                </button>
              </form>
            ) : (
              <p>{memory.text}</p>
            )}
            <details>
              <summary>Reasoning behind this observation</summary>
              <blockquote>
                {workspace.interactions.find((item) => item.id === memory.evidenceId)?.text ??
                  'Original evidence is unavailable.'}
              </blockquote>
            </details>
            <div className="row">
              <button
                className="text-button"
                onClick={() => {
                  setDraft(memory.text);
                  setEditing(memory.id);
                }}
              >
                <Pencil size={15} />
                Correct
              </button>
              <button
                className="text-button"
                onClick={() =>
                  update((value) => ({
                    ...value,
                    memories: value.memories.filter((item) => item.id !== memory.id),
                  }))
                }
              >
                <Trash2 size={15} />
                Remove
              </button>
            </div>
          </article>
        ))}
      </div>
    </section>
  );
}
