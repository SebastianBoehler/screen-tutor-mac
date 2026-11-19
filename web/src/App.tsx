import { lazy, Suspense, useState } from 'react';
import { useLearning } from './services/useLearning';
import { photoData } from './services/photo';
import { exportWorkspace } from './services/storage';
import { WorkspaceHeader, ErrorBanner } from './components/WorkspaceHeader';
import { Sidebar } from './components/Sidebar';
import { EmptyCanvas } from './components/EmptyCanvas';
import { ActivityCanvas } from './components/ActivityCanvas';
import { ExamplePicker } from './components/ExamplePicker';
import { Composer } from './components/Composer';
import { CourseForm } from './components/CourseForm';
import { Connections } from './components/Connections';

const Materials = lazy(() =>
  import('./components/Materials').then((module) => ({
    default: module.Materials,
  })),
);
const Plan = lazy(() => import('./components/Plan').then((module) => ({ default: module.Plan })));
const Memory = lazy(() =>
  import('./components/Memory').then((module) => ({ default: module.Memory })),
);
const Source = lazy(() =>
  import('./components/Source').then((module) => ({ default: module.Source })),
);
const Camera = lazy(() =>
  import('./components/Camera').then((module) => ({ default: module.Camera })),
);
const Conversation = lazy(() =>
  import('./components/Conversation').then((module) => ({
    default: module.Conversation,
  })),
);

export default function App() {
  const app = useLearning();
  const { workspace, update, course, activity } = app;
  const [sidebar, setSidebar] = useState(false);
  const [newCourse, setNewCourse] = useState(false);
  const [settings, setSettings] = useState(false);
  const [conversation, setConversation] = useState(false);
  const [camera, setCamera] = useState(false);
  const [image, setImage] = useState('');
  const [source, setSource] = useState<{ id: string; page: number } | null>(null);
  const materials = workspace.materials.filter((item) => item.courseId === course?.id);
  const messages = workspace.messages.filter((item) => item.courseId === course?.id);
  const draft = activity ? (workspace.drafts[activity.id] ?? '') : '';
  const showSource = (id: string, page: number) => setSource({ id, page });
  const selectedSource = workspace.materials.find((item) => item.id === source?.id);
  const start = (exam = false) => {
    if (!(
      app.connections[app.connections.provider === 'openai' ? 'openaiKey' : 'openrouterKey'] ||
      app.available[app.connections.provider]
    )) {
      setSettings(true);
      return;
    }
    void app.run(
      exam
        ? 'Start a course-grounded practice exam. One question at a time, no hints or answers. This is generated practice, not an official exam.'
        : `Start a study session about: ${course?.goal || 'a foundational concept in my material'}. Begin with one diagnostic prediction.`,
      { mode: exam ? 'exam' : 'learn' },
    );
  };
  const next = () => {
    void app.run(
      'Give me a new transfer question on this concept, with changed details and no answer in the visible activity.',
    );
  };
  if (!app.ready)
    return (
      <main className="loading-screen">
        <h1>ScreenTutor</h1>
        <p role="status">{app.storageError || 'Opening your learning space…'}</p>
      </main>
    );
  return (
    <div className="app-shell">
      <Sidebar
        workspace={workspace}
        page={app.page}
        open={sidebar}
        busy={app.tutor.busy}
        onClose={() => setSidebar(false)}
        onPage={app.setPage}
        onCourse={(id) => {
          setImage('');
          setCamera(false);
          app.selectCourse(id);
        }}
        onActivity={(id) => {
          update((value) => ({ ...value, selectedActivityId: id }));
          app.setPage('study');
        }}
        onNew={() => {
          if (!app.tutor.busy) {
            setSidebar(false);
            setNewCourse(true);
          }
        }}
        onSettings={() => setSettings(true)}
      />
      <div className="main-column">
        <WorkspaceHeader
          courseName={course?.name}
          page={app.page}
          saving={app.saving}
          storageError={app.storageError}
          onNavigation={() => setSidebar(true)}
          onExport={() => exportWorkspace(workspace)}
          onConnections={() => setSettings(true)}
        />
        <ErrorBanner
          error={app.storageError || app.error}
          onDismiss={app.storageError ? undefined : app.clearError}
        />
        <main id="learning-content" className="main-content">
          <Suspense
            fallback={
              <p className="page-loading" role="status">
                Opening your workspace…
              </p>
            }
          >
            {app.page === 'plan' ? (
              <Plan
                workspace={workspace}
                update={update}
                onReview={(id) => {
                  const item = workspace.activities.find((item) => item.id === id)!;
                  app.selectCourse(item.courseId);
                  update((value) => ({ ...value, selectedActivityId: id }));
                  if (
                    workspace.interactions.some(
                      (event) => event.activityId === id && event.kind === 'reveal',
                    )
                  )
                    void app.run(
                      'Review this concept with a new recall question. Use different details and hide the answer.',
                    );
                }}
              />
            ) : app.page === 'memory' && course ? (
              <Memory workspace={workspace} update={update} />
            ) : app.page === 'materials' && course ? (
              <Materials workspace={workspace} update={update} onSource={showSource} />
            ) : (
              <>
                <div className="canvas-toolbar">
                  <div className="row wrap">
                    <button
                      className="text-button"
                      disabled={app.tutor.busy}
                      onClick={() => app.openExample()}
                    >
                      Queue example
                    </button>
                    <ExamplePicker disabled={app.tutor.busy} onOpen={app.openExample} />
                    {course && materials.length > 0 && (
                      <button
                        className="text-button"
                        disabled={app.tutor.busy}
                        onClick={() =>
                          activity?.mode === 'exam' && !activity.reviewedAt
                            ? app.finishExam()
                            : start(true)
                        }
                      >
                        {activity?.mode === 'exam' && !activity.reviewedAt
                          ? 'Review exam'
                          : 'Practice exam'}
                      </button>
                    )}
                    <button className="text-button" onClick={() => setConversation(true)}>
                      Conversation
                    </button>
                  </div>
                </div>
                {activity ? (
                  <ActivityCanvas
                    key={activity.id}
                    activity={activity}
                    interactions={workspace.interactions}
                    materials={materials}
                    draft={draft}
                    busy={app.tutor.busy}
                    exploration={workspace.interactiveStates[activity.id]}
                    onInteractiveState={(state) => app.saveExploration(activity.id, state)}
                    onExplore={() => app.event('explore')}
                    onDraft={(text) =>
                      update((value) => ({
                        ...value,
                        drafts: { ...value.drafts, [activity.id]: text },
                      }))
                    }
                    onAttempt={app.checkReasoning}
                    onHint={() => app.event('hint')}
                    onReveal={() => app.event('reveal')}
                    onNext={next}
                    onSource={showSource}
                  />
                ) : (
                  <EmptyCanvas
                    course={course}
                    hasMaterial={materials.length > 0}
                    busy={app.tutor.busy}
                    onNew={() => setNewCourse(true)}
                    onMaterials={() => app.setPage('materials')}
                    onStart={() => start()}
                    onGoal={(goal) =>
                      update((value) => ({
                        ...value,
                        courses: value.courses.map((item) =>
                          item.id === course!.id ? { ...item, goal } : item,
                        ),
                      }))
                    }
                  />
                )}
              </>
            )}
          </Suspense>
        </main>
        {app.page === 'study' && (
          <Composer
            busy={app.tutor.busy}
            receiving={app.tutor.receiving}
            status={app.voiceStatus}
            latest={messages.filter((item) => item.role === 'assistant').at(-1)}
            image={image}
            disabled={!course || !materials.length}
            onSend={async (text) => {
              const sent = image;
              const delivered = await app.sendMessage(text, sent || undefined);
              if (delivered) setImage((current) => (current === sent ? '' : current));
              return delivered;
            }}
            onStop={app.tutor.stop}
            onVoice={() => {
              if (!app.connections.openaiKey && !app.available.openai) setSettings(true);
              else void app.startVoice();
            }}
            onMute={() => app.voice.toggleMute()}
            onDisconnect={() => app.voice.disconnect()}
            onCamera={() => setCamera(true)}
            onFile={(file) => {
              void photoData(file)
                .then(setImage)
                .catch((error) => app.setError(error.message));
            }}
            onClearImage={() => setImage('')}
            onConversation={() => setConversation(true)}
          />
        )}
      </div>
      {newCourse && (
        <CourseForm
          onClose={() => setNewCourse(false)}
          onSave={(course) => {
            app.addCourse(course);
            setNewCourse(false);
          }}
        />
      )}
      {settings && (
        <Connections
          value={app.connections}
          available={app.available}
          onClose={() => setSettings(false)}
          onSave={(value) => {
            app.voice.disconnect();
            app.setConnections(value);
            setSettings(false);
          }}
        />
      )}
      <Suspense fallback={null}>
        {conversation && (
          <Conversation messages={messages} onClose={() => setConversation(false)} />
        )}
        {source && selectedSource && (
          <Source
            material={selectedSource}
            initialPage={source.page}
            onClose={() => setSource(null)}
          />
        )}
        {camera && <Camera onClose={() => setCamera(false)} onPhoto={setImage} />}
      </Suspense>
    </div>
  );
}
