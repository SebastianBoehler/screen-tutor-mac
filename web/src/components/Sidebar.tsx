import {
  BookOpen,
  CalendarDays,
  FolderOpen,
  GraduationCap,
  Plus,
  Settings2,
  Sprout,
  X,
} from 'lucide-react';
import type { Workspace } from '../domain/models';
import type { Page } from '../services/useLearning';

const destinations = [
  { id: 'study', title: 'Study', Icon: BookOpen },
  { id: 'materials', title: 'Materials', Icon: FolderOpen },
  { id: 'plan', title: 'Plan', Icon: CalendarDays },
  { id: 'memory', title: 'Memory', Icon: Sprout },
] as const;
export function Sidebar({
  workspace,
  page,
  open,
  busy,
  onClose,
  onPage,
  onCourse,
  onActivity,
  onNew,
  onSettings,
}: {
  workspace: Workspace;
  page: Page;
  open: boolean;
  busy: boolean;
  onClose(): void;
  onPage(page: Page): void;
  onCourse(id: string): void;
  onActivity(id: string): void;
  onNew(): void;
  onSettings(): void;
}) {
  return (
    <>
      {open && <button className="sidebar-scrim" aria-label="Close navigation" onClick={onClose} />}
      <aside className={`sidebar ${open ? 'is-open' : ''}`} aria-label="Learning navigation">
        <div className="brand">
          <GraduationCap size={23} strokeWidth={1.6} />
          <strong>ScreenTutor</strong>
          <button
            className="icon-button mobile-only"
            aria-label="Close navigation"
            onClick={onClose}
          >
            <X size={18} />
          </button>
        </div>
        <nav className="destinations" aria-label="Workspace">
          {destinations.map(({ id, title, Icon }) => (
            <button
              key={id}
              className={page === id ? 'active' : ''}
              aria-current={page === id ? 'page' : undefined}
              onClick={() => {
                onPage(id);
                onClose();
              }}
            >
              <Icon size={18} strokeWidth={1.6} />
              {title}
            </button>
          ))}
        </nav>
        <div className="sidebar-label row between">
          <span>Your courses</span>
          <button className="icon-button" aria-label="Add course" onClick={onNew}>
            <Plus size={16} />
          </button>
        </div>
        <nav aria-label="Courses" className="course-nav">
          {workspace.courses.map((course) => (
            <button
              className={course.id === workspace.selectedCourseId ? 'active' : ''}
              key={course.id}
              disabled={busy}
              onClick={() => {
                onCourse(course.id);
                onClose();
              }}
            >
              <span className="course-dot" />
              <span>{course.name}</span>
            </button>
          ))}
        </nav>
        {workspace.courses.length === 0 && (
          <p className="sidebar-empty">A separate space for every course.</p>
        )}
        {workspace.activities.some((item) => item.courseId === workspace.selectedCourseId) && (
          <>
            <div className="sidebar-label">Your canvas</div>
            <nav className="activity-nav" aria-label="Saved activities">
              {workspace.activities
                .filter((item) => item.courseId === workspace.selectedCourseId)
                .reverse()
                .map((item) => (
                  <button
                    key={item.id}
                    className={item.id === workspace.selectedActivityId ? 'active' : ''}
                    disabled={busy}
                    onClick={() => {
                      onActivity(item.id);
                      onClose();
                    }}
                  >
                    {item.title}
                    {workspace.canvas?.pendingActivityIds.includes(item.id) && ' · Prepared'}
                  </button>
                ))}
            </nav>
          </>
        )}
        <div className="sidebar-bottom">
          <span className="local-label">
            <span className="status-dot" />
            Stored on this device
          </span>
          <button className="settings-link" onClick={onSettings}>
            <Settings2 size={17} />
            Connections
          </button>
        </div>
      </aside>
    </>
  );
}
