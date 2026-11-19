import { useState } from 'react';
import { Dialog } from './Dialog';
import type { Course } from '../domain/models';
import { uid } from '../domain/models';

export function CourseForm({ onSave, onClose }: { onSave(course: Course): void; onClose(): void }) {
  const [name, setName] = useState('');
  const [goal, setGoal] = useState('');
  const [examDate, setExamDate] = useState('');
  return (
    <Dialog title="A space for your course" onClose={onClose}>
      <p className="muted">Bring your material. We’ll build from what you understand.</p>
      <form
        onSubmit={(event) => {
          event.preventDefault();
          onSave({ id: uid(), name: name.trim(), goal: goal.trim(), examDate });
        }}
      >
        <label>
          Course name
          <input
            autoFocus
            required
            maxLength={120}
            value={name}
            onChange={(event) => setName(event.target.value)}
            placeholder="Your course name"
          />
        </label>
        <label>
          What do you want to be able to do?
          <textarea
            maxLength={1000}
            rows={3}
            value={goal}
            onChange={(event) => setGoal(event.target.value)}
            placeholder="A concrete goal, in your own words"
          />
        </label>
        <label>
          Exam date <span className="muted">optional</span>
          <input
            type="date"
            value={examDate}
            onChange={(event) => setExamDate(event.target.value)}
          />
        </label>
        <div className="dialog-actions">
          <button type="button" className="secondary" onClick={onClose}>
            Cancel
          </button>
          <button className="primary" disabled={!name.trim()}>
            Create course
          </button>
        </div>
      </form>
    </Dialog>
  );
}
