import type { Activity, Workspace } from './models';

type LegacyWorkspace = Omit<Workspace, 'version' | 'activities' | 'interactiveStates'> & {
  version: 1;
  activities: Omit<Activity, 'interactive'>[];
};
export function migrateWorkspace(value: Workspace | LegacyWorkspace): Workspace {
  if (value.version === 2) return value;
  return {
    ...value,
    version: 2,
    interactiveStates: {},
    activities: value.activities.map((activity) => ({ ...activity, interactive: null })),
  };
}
