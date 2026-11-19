import { ArrowRight, BookOpen, FolderPlus, NotebookPen } from 'lucide-react';
import type { Course } from '../domain/models';

export function EmptyCanvas({
  course,
  hasMaterial,
  busy,
  onNew,
  onMaterials,
  onStart,
  onGoal,
}: {
  course?: Course;
  hasMaterial: boolean;
  busy: boolean;
  onNew(): void;
  onMaterials(): void;
  onStart(): void;
  onGoal(goal: string): void;
}) {
  return (
    <section className="empty-canvas">
      <div className="empty-mark">
        <BookOpen size={31} strokeWidth={1.3} />
      </div>
      <span className="eyebrow">Your learning canvas</span>
      <h1>
        {!course
          ? 'Make room for\na clearer understanding.'
          : 'One idea.\nA little more understanding.'}
      </h1>
      <p className="empty-description">
        {!course
          ? 'Your material, a voice tutor, and space to work things out. Built around what you can do on your own.'
          : 'Start from your course material. Think it through with your tutor, then try the next step yourself.'}
      </p>
      {!course ? (
        <button className="primary" onClick={onNew}>
          Add your first course
          <ArrowRight size={17} />
        </button>
      ) : !hasMaterial ? (
        <button className="primary" onClick={onMaterials}>
          <FolderPlus size={17} />
          Bring your course material
          <ArrowRight size={17} />
        </button>
      ) : (
        <div className="session-start">
          <label htmlFor="learning-goal">What would you like to understand?</label>
          <textarea
            id="learning-goal"
            rows={2}
            value={course.goal}
            maxLength={1000}
            onChange={(event) => onGoal(event.target.value)}
            placeholder="A concept, a question, or something you got stuck on"
          />
          <button className="primary" disabled={busy} onClick={onStart}>
            {busy ? 'Preparing your activity…' : 'Start with a question'}
            <ArrowRight size={17} />
          </button>
        </div>
      )}
      <div className="empty-principles">
        <span>
          <NotebookPen size={16} />
          Your thinking comes first
        </span>
        <span>One concept at a time</span>
        <span>Practice, then revisit</span>
      </div>
    </section>
  );
}
