"use client";

import type { Board, DeskStatus, StudyTask } from "@/lib/protocol";
import { Markdown } from "./Markdown";

export function StudyBoard({
  board,
  tasks,
  desks,
  myIdentity,
}: {
  board: Board | null;
  tasks: StudyTask[];
  desks: DeskStatus[];
  myIdentity: string;
}) {
  const active = tasks.filter((t) => t.status === "active");
  return (
    <aside className="board">
      {active.length > 0 && (
        <section>
          {active.map((task) => {
            const mine = task.assignee === "everyone" || task.assignee === myIdentity;
            return (
              <div key={task.id} className={`task ${mine ? "mine" : ""}`}>
                <div className="task-label">
                  {task.assignee === "everyone" ? "Task for everyone" : `Task for ${task.assigneeName}`}
                </div>
                <h3>{task.title}</h3>
                <Markdown source={task.task} />
              </div>
            );
          })}
        </section>
      )}
      <section className="board-body">
        {board ? (
          <>
            <h2>{board.title}</h2>
            <Markdown source={board.markdown} />
          </>
        ) : (
          <p className="muted">The tutor&apos;s board appears here. Ask it to explain something on the board.</p>
        )}
      </section>
      {desks.length > 0 && (
        <section className="desks">
          <h4>Desks</h4>
          {desks.map((desk) => (
            <div key={desk.identity} className="desk">
              <span className={`pill ${desk.progress}`}>{desk.progress.replace("_", " ")}</span>
              <strong>{desk.name}</strong>
              <div className="muted desk-summary">
                <Markdown source={desk.summary} />
              </div>
            </div>
          ))}
        </section>
      )}
    </aside>
  );
}
