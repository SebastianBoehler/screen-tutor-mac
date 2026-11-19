import { emptyWorkspace, type Workspace } from '../domain/models';
import { migrateWorkspace } from '../domain/migrations';

const databaseName = 'screentutor-learning';
let database: Promise<IDBDatabase> | undefined;
function open() {
  database ??= new Promise((resolve, reject) => {
    const request = indexedDB.open(databaseName, 1);
    request.onupgradeneeded = () => request.result.createObjectStore('workspace');
    request.onsuccess = () => resolve(request.result);
    request.onerror = () =>
      reject(new Error('Local storage could not be opened. Check browser storage permissions.'));
    request.onblocked = () =>
      reject(new Error('Close other ScreenTutor tabs to upgrade local storage.'));
  });
  return database;
}
export async function loadWorkspace(): Promise<Workspace> {
  const db = await open();
  return new Promise((resolve, reject) => {
    const tx = db.transaction('workspace', 'readonly');
    const request = tx.objectStore('workspace').get('current');
    request.onsuccess = () => {
      const value = request.result;
      if (value && value.version !== 1 && value.version !== 2 && value.version !== 3)
        reject(new Error('This workspace version is unsupported. Your data was not modified.'));
      else resolve(value ? migrateWorkspace(value) : emptyWorkspace());
    };
    request.onerror = () => reject(new Error('Your learning workspace could not be read.'));
  });
}
export async function saveWorkspace(workspace: Workspace): Promise<void> {
  const db = await open();
  return new Promise((resolve, reject) => {
    const tx = db.transaction('workspace', 'readwrite');
    tx.objectStore('workspace').put(workspace, 'current');
    tx.oncomplete = () => resolve();
    tx.onerror = () =>
      reject(
        new Error(
          'Changes could not be saved. Browser storage may be full. Export your workspace before closing.',
        ),
      );
    tx.onabort = () =>
      reject(new Error('Saving was interrupted. Export your workspace before closing.'));
  });
}
export function exportWorkspace(workspace: Workspace) {
  const url = URL.createObjectURL(
    new Blob([JSON.stringify(workspace, null, 2)], {
      type: 'application/json',
    }),
  );
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = `screentutor-${new Date().toISOString().slice(0, 10)}.json`;
  anchor.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
