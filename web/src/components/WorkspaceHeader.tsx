import { Download, Menu, Settings2, X } from 'lucide-react';
import type { Page } from '../services/useLearning';

export function WorkspaceHeader({
  courseName,
  page,
  saving,
  storageError,
  onNavigation,
  onExport,
  onConnections,
}: {
  courseName?: string;
  page: Page;
  saving: boolean;
  storageError: string;
  onNavigation(): void;
  onExport(): void;
  onConnections(): void;
}) {
  return (
    <header className="topbar">
      <div className="row topbar-context">
        <button
          className="icon-button mobile-only"
          aria-label="Open navigation"
          onClick={onNavigation}
        >
          <Menu size={20} />
        </button>
        <span className="course-context">{courseName ?? 'Your workspace'}</span>
        <span className="breadcrumb-slash">/</span>
        <span className="muted">
          {page === 'study' ? 'Canvas' : page[0].toUpperCase() + page.slice(1)}
        </span>
      </div>
      <div className="row topbar-actions">
        <span className="save-status">
          {saving ? 'Saving…' : storageError ? 'Not saved' : 'Saved locally'}
        </span>
        <button
          className="icon-button"
          aria-label="Export learning workspace"
          title="Export workspace"
          onClick={onExport}
        >
          <Download size={17} />
        </button>
        <button className="icon-button" aria-label="Open connections" onClick={onConnections}>
          <Settings2 size={17} />
        </button>
      </div>
    </header>
  );
}

export function ErrorBanner({ error, onDismiss }: { error: string; onDismiss?: () => void }) {
  if (!error) return null;
  return (
    <div className="error-banner" role="alert">
      <span>{error}</span>
      {onDismiss && (
        <button className="icon-button" aria-label="Dismiss error" onClick={onDismiss}>
          <X size={16} />
        </button>
      )}
    </div>
  );
}
