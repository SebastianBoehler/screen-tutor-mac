import { useRef, useState } from 'react';
import { FileText, Plus, Upload, ArrowUpRight, Pencil } from 'lucide-react';
import type { Material, Workspace } from '../domain/models';
import { now, uid } from '../domain/models';
import { importMaterial } from '../services/materials';
import { Dialog } from './Dialog';

export function Materials({
  workspace,
  update,
  onSource,
}: {
  workspace: Workspace;
  update(change: (value: Workspace) => Workspace): void;
  onSource(id: string, page: number): void;
}) {
  const file = useRef<HTMLInputElement>(null);
  const [importing, setImporting] = useState(false);
  const [error, setError] = useState('');
  const [note, setNote] = useState<Material | 'new' | null>(null);
  const courseId = workspace.selectedCourseId!;
  const materials = workspace.materials.filter((item) => item.courseId === courseId);
  return (
    <section className="page-content">
      <div className="page-heading">
        <div>
          <span className="eyebrow">Your sources</span>
          <h1>Material to think with.</h1>
          <p className="muted">Course documents and your own notes, kept distinct.</p>
        </div>
      </div>
      <div className="row wrap">
        <button className="primary" disabled={importing} onClick={() => file.current?.click()}>
          <Upload size={17} />
          {importing ? 'Reading material…' : 'Import material'}
        </button>
        <button className="secondary" onClick={() => setNote('new')}>
          <Plus size={17} />
          Lecture note
        </button>
      </div>
      <input
        ref={file}
        type="file"
        multiple
        accept=".pdf,.md,.markdown,.txt"
        className="sr-only"
        onChange={async (event) => {
          const selected = Array.from(event.target.files ?? []);
          event.target.value = '';
          if (!selected.length) return;
          setImporting(true);
          setError('');
          const hashes = new Set(materials.map((item) => item.hash));
          const errors: string[] = [];
          for (const selectedFile of selected) {
            try {
              const material = await importMaterial(selectedFile, courseId);
              if (hashes.has(material.hash))
                throw new Error('This document is already in this course.');
              hashes.add(material.hash);
              update((value) => ({ ...value, materials: [...value.materials, material] }));
            } catch (error) {
              errors.push(`${selectedFile.name}: ${(error as Error).message}`);
            }
          }
          setError(errors.join('\n'));
          setImporting(false);
        }}
      />
      {error && (
        <p role="alert" className="error-text">
          {error}
        </p>
      )}
      <div className="material-list">
        {materials.length === 0 ? (
          <div className="empty-inline">
            <FileText size={25} />
            <h2>Start with a lecture or a page of notes.</h2>
            <p>PDF, Markdown and text · up to 25 MB. Files are read on this device.</p>
          </div>
        ) : (
          materials.map((material) => (
            <div className="material-row" key={material.id}>
              <FileText size={22} />
              <div className="grow">
                <strong>{material.name}</strong>
                <p className="muted">
                  {material.kind === 'lecture-note'
                    ? 'Your lecture note · editable'
                    : `${material.pages.length} pages · course document`}
                </p>
              </div>
              {material.kind === 'lecture-note' && (
                <button
                  className="icon-button"
                  aria-label={`Edit ${material.name}`}
                  onClick={() => setNote(material)}
                >
                  <Pencil size={17} />
                </button>
              )}
              <button
                className="icon-button"
                aria-label={`Read ${material.name}`}
                onClick={() => onSource(material.id, 1)}
              >
                <ArrowUpRight size={18} />
              </button>
            </div>
          ))
        )}
      </div>
      <p className="footnote">
        Notes remain your own account of a lecture. Tutor interpretations do not replace course
        sources.
      </p>
      {note && (
        <NoteEditor
          material={note === 'new' ? undefined : note}
          onClose={() => setNote(null)}
          onSave={(name, text) => {
            const material: Material =
              note === 'new'
                ? {
                    id: uid(),
                    courseId,
                    name,
                    hash: '',
                    kind: 'lecture-note',
                    createdAt: now(),
                    pages: [{ number: 1, text }],
                  }
                : { ...note, name, pages: [{ number: 1, text }] };
            update((value) => ({
              ...value,
              materials:
                note === 'new'
                  ? [...value.materials, material]
                  : value.materials.map((item) => (item.id === material.id ? material : item)),
            }));
            setNote(null);
          }}
        />
      )}
    </section>
  );
}
function NoteEditor({
  material,
  onSave,
  onClose,
}: {
  material?: Material;
  onSave(name: string, text: string): void;
  onClose(): void;
}) {
  const [name, setName] = useState(material?.name ?? '');
  const [text, setText] = useState(material?.pages[0]?.text ?? '');
  return (
    <Dialog title={material ? 'Edit lecture note' : 'Capture a lecture note'} onClose={onClose}>
      <form
        onSubmit={(event) => {
          event.preventDefault();
          onSave(name.trim(), text.trim());
        }}
      >
        <label>
          Lecture or topic
          <input
            autoFocus
            required
            value={name}
            maxLength={120}
            onChange={(event) => setName(event.target.value)}
            placeholder="Give your note a title"
          />
        </label>
        <label>
          Your notes
          <textarea
            className="note-editor"
            required
            value={text}
            maxLength={100_000}
            onChange={(event) => setText(event.target.value)}
            rows={12}
            placeholder="Capture ideas, questions and reasoning. You can study from this note immediately."
          />
        </label>
        <div className="dialog-actions">
          <button className="primary" disabled={!name.trim() || !text.trim()}>
            Save as study material
          </button>
        </div>
      </form>
    </Dialog>
  );
}
