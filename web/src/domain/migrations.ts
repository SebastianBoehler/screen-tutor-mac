import type { Activity, Workspace } from './models';

type VersionTwo = Omit<Workspace, 'version' | 'investigations'> & { version: 2 };
type LegacyWorkspace = Omit<VersionTwo, 'version' | 'activities' | 'interactiveStates'> & {
  version: 1;
  activities: Omit<Activity, 'interactive'>[];
};
export function migrateWorkspace(value: Workspace | VersionTwo | LegacyWorkspace): Workspace {
  if (value.version === 3) return value;
  if (value.version === 2) return { ...value, version: 3, investigations: {} };
  return {
    ...value,
    version: 3,
    investigations: {},
    interactiveStates: {},
    activities: value.activities.map((activity) => ({ ...activity, interactive: null })),
  };
}
