"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { isValidRoomCode } from "@/lib/protocol";

const words = ["vector", "matrix", "kernel", "gradient", "tensor", "lemma", "proof", "limit", "series", "field"];

function randomCode() {
  const pick = () => words[Math.floor(Math.random() * words.length)];
  return `${pick()}-${pick()}-${Math.floor(Math.random() * 90 + 10)}`;
}

export default function Lobby() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [code, setCode] = useState("");

  useEffect(() => {
    setCode(randomCode());
    try {
      setName(localStorage.getItem("study-room-name") ?? "");
    } catch {}
  }, []);

  const valid = name.trim().length > 0 && isValidRoomCode(code);

  function join(event: React.FormEvent) {
    event.preventDefault();
    if (!valid) return;
    try {
      localStorage.setItem("study-room-name", name.trim());
    } catch {}
    router.push(`/room/${code}?name=${encodeURIComponent(name.trim())}`);
  }

  return (
    <main className="lobby">
      <form className="lobby-card" onSubmit={join}>
        <h1>Study Room</h1>
        <p className="muted">
          Join with your mic and the camera above your desk. The tutor listens to the group, watches each desk,
          and puts formulas, diagrams and tasks on a shared board.
        </p>
        <label>
          Your name
          <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Sebastian" autoFocus />
        </label>
        <label>
          Room code
          <input value={code} onChange={(e) => setCode(e.target.value.toLowerCase())} />
        </label>
        <p className="muted small">Share the room code (or the room link) with your study partners.</p>
        <button type="submit" disabled={!valid}>
          Join room
        </button>
      </form>
    </main>
  );
}
