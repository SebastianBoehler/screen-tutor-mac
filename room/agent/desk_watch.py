"""Per-learner desk watching: keeps the newest camera frame, detects material page
changes locally, and asks a fast OpenRouter vision model for a structured look.

Mirrors ScreenTutor's Swift DeskChangeGate / DeskObserver so solo and group modes
behave the same way.
"""

from __future__ import annotations

import asyncio
import base64
import io
import json
import logging
import os
import time
from dataclasses import dataclass, field
from typing import Awaitable, Callable

import httpx
import numpy as np
from PIL import Image

from livekit import rtc

from prompts import OBSERVER_SYSTEM, observer_user_text

log = logging.getLogger("study-room.desk")

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
FP_W, FP_H = 64, 48


def fingerprint(image: Image.Image) -> np.ndarray:
    return np.asarray(image.convert("L").resize((FP_W, FP_H), Image.Resampling.BILINEAR), dtype=np.int16)


def changed_fraction(a: np.ndarray, b: np.ndarray, threshold: int = 14) -> float:
    return float(np.mean(np.abs(a - b) > threshold))


def encode_jpeg(image: Image.Image, longest: int = 1600, max_bytes: int = 220_000) -> bytes:
    image = image.convert("RGB")
    scale = min(1.0, longest / max(image.size))
    if scale < 1:
        image = image.resize((int(image.width * scale), int(image.height * scale)), Image.Resampling.LANCZOS)
    for quality in (82, 70, 58, 46):
        buffer = io.BytesIO()
        image.save(buffer, format="JPEG", quality=quality)
        if buffer.tell() <= max_bytes:
            break
    return buffer.getvalue()


@dataclass
class ChangeGate:
    """Same decisions as the Swift DeskChangeGate."""

    motion_threshold: float = 0.02
    material_threshold: float = 0.006
    settle_seconds: float = 1.5
    minimum_interval: float = 4.0
    stall_seconds: float = 90.0
    previous: np.ndarray | None = None
    analyzed: np.ndarray | None = None
    last_motion: float | None = None
    last_material_change: float | None = None
    last_analysis: float | None = None
    stall_reported: bool = False

    def evaluate(self, fp: np.ndarray, now: float, has_task: bool) -> str | None:
        try:
            if self.previous is not None and changed_fraction(fp, self.previous) > self.motion_threshold:
                self.last_motion = now
            if self.last_material_change is None:
                self.last_material_change = now
            if self.analyzed is None:
                return "first_look"
            if self.last_analysis is not None and now - self.last_analysis < self.minimum_interval:
                return None
            settled = self.last_motion is None or now - self.last_motion >= self.settle_seconds
            if changed_fraction(fp, self.analyzed) > self.material_threshold:
                self.last_material_change = now
                self.stall_reported = False
                return "page_changed" if settled else None
            if has_task and not self.stall_reported and now - self.last_material_change >= self.stall_seconds:
                self.stall_reported = True
                return "no_visible_progress"
            return None
        finally:
            self.previous = fp

    def record_analysis(self, fp: np.ndarray, now: float) -> None:
        self.analyzed = fp
        self.last_analysis = now


@dataclass
class DeskState:
    identity: str
    name: str
    latest: Image.Image | None = None
    latest_at: float = 0.0
    gate: ChangeGate = field(default_factory=ChangeGate)
    observation: dict | None = None
    observed_at: float = 0.0
    analyzing: bool = False

    def note(self) -> str:
        if not self.observation:
            return f"{self.name}: no observation yet."
        o = self.observation
        age = int(time.time() - self.observed_at)
        text = f"{self.name} ({o.get('progress', 'unclear')}, {age}s ago): {o.get('summary', '')}"
        if o.get("work_transcription"):
            text += f"\n  Written work: {o['work_transcription']}"
        issue = o.get("issue")
        if isinstance(issue, dict):
            text += f"\n  Possible {issue.get('kind')} at {issue.get('location')}: {issue.get('description')}"
        return text


InterjectionHandler = Callable[[DeskState, dict], Awaitable[None]]
TaskLookup = Callable[[str], str | None]


class DeskWatcher:
    """Watches every learner's camera track in the room."""

    def __init__(self, on_interjection: InterjectionHandler, task_for: TaskLookup, on_update: Callable[[], None]):
        self.desks: dict[str, DeskState] = {}
        self._streams: dict[str, asyncio.Task] = {}
        self._on_interjection = on_interjection
        self._task_for = task_for
        self._on_update = on_update
        self._http = httpx.AsyncClient(timeout=30)
        self._loop_task: asyncio.Task | None = None
        self.model = os.environ.get("DESK_OBSERVER_MODEL", "google/gemini-3.5-flash-lite")
        self.api_key = os.environ.get("OPENROUTER_API_KEY")
        if not self.api_key:
            log.warning("OPENROUTER_API_KEY is not set; desk observation is disabled (look_at_desk still works).")

    def start(self) -> None:
        self._loop_task = asyncio.create_task(self._loop())

    async def close(self) -> None:
        for task in self._streams.values():
            task.cancel()
        if self._loop_task:
            self._loop_task.cancel()
        await self._http.aclose()

    def attach(self, track: rtc.RemoteVideoTrack, participant: rtc.RemoteParticipant) -> None:
        identity = participant.identity
        self.detach(identity)
        desk = self.desks.get(identity) or DeskState(identity=identity, name=participant.name or identity)
        self.desks[identity] = desk
        self._streams[identity] = asyncio.create_task(self._read_frames(track, desk))
        log.info("watching desk of %s", desk.name)

    def detach(self, identity: str) -> None:
        task = self._streams.pop(identity, None)
        if task:
            task.cancel()

    def remove(self, identity: str) -> None:
        self.detach(identity)
        self.desks.pop(identity, None)
        self._on_update()

    def find(self, name: str) -> DeskState | None:
        wanted = name.strip().lower()
        for desk in self.desks.values():
            if desk.name.lower() == wanted or desk.identity == wanted:
                return desk
        for desk in self.desks.values():
            if wanted and (wanted in desk.name.lower() or desk.name.lower().split()[0] == wanted.split()[0]):
                return desk
        return None

    def latest_jpeg(self, desk: DeskState) -> bytes | None:
        if desk.latest is None or time.time() - desk.latest_at > 10:
            return None
        return encode_jpeg(desk.latest)

    def summaries(self) -> list[dict]:
        out = []
        for desk in self.desks.values():
            o = desk.observation or {}
            issue = o.get("issue")
            out.append(
                {
                    "identity": desk.identity,
                    "name": desk.name,
                    "progress": o.get("progress", "unclear") if o else "unclear",
                    "summary": o.get("summary", "camera connected") if o else "camera connected",
                    "issue": f"{issue.get('location')}: {issue.get('description')}" if isinstance(issue, dict) else None,
                    "updatedAt": int(desk.observed_at * 1000),
                }
            )
        return out

    async def _read_frames(self, track: rtc.RemoteVideoTrack, desk: DeskState) -> None:
        stream = rtc.VideoStream(track, format=rtc.VideoBufferType.RGBA)
        last = 0.0
        try:
            async for event in stream:
                now = time.time()
                if now - last < 0.5:
                    continue
                last = now
                frame = event.frame
                desk.latest = Image.frombuffer("RGBA", (frame.width, frame.height), bytes(frame.data), "raw", "RGBA", 0, 1)
                desk.latest_at = now
        except asyncio.CancelledError:
            pass
        finally:
            await stream.aclose()

    async def _loop(self) -> None:
        while True:
            await asyncio.sleep(1)
            if not self.api_key:
                continue
            for desk in list(self.desks.values()):
                if desk.analyzing or desk.latest is None or time.time() - desk.latest_at > 5:
                    continue
                fp = fingerprint(desk.latest)
                reason = desk.gate.evaluate(fp, time.time(), self._task_for(desk.identity) is not None)
                if reason:
                    desk.gate.record_analysis(fp, time.time())
                    asyncio.create_task(self.analyze(desk, reason))

    async def analyze(self, desk: DeskState, reason: str) -> dict | None:
        if not self.api_key or desk.latest is None or desk.analyzing:
            return desk.observation
        desk.analyzing = True
        try:
            image = desk.latest
            jpeg = encode_jpeg(image)
            seconds = None
            if desk.gate.last_material_change:
                seconds = int(time.time() - desk.gate.last_material_change)
            body = {
                "model": self.model,
                "messages": [
                    {"role": "system", "content": OBSERVER_SYSTEM},
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "text",
                                "text": observer_user_text(
                                    name=desk.name,
                                    reason=reason,
                                    task=self._task_for(desk.identity),
                                    previous=desk.note() if desk.observation else None,
                                    seconds_without_change=seconds,
                                ),
                            },
                            {
                                "type": "image_url",
                                "image_url": {"url": "data:image/jpeg;base64," + base64.b64encode(jpeg).decode()},
                            },
                        ],
                    },
                ],
                "response_format": {"type": "json_object"},
                "temperature": 0.2,
                "max_tokens": 900,
                "provider": {"sort": "throughput", "data_collection": "deny", "zdr": True},
            }
            response = await self._http.post(
                OPENROUTER_URL,
                headers={"Authorization": f"Bearer {self.api_key}", "X-Title": "ScreenTutor Study Room"},
                json=body,
            )
            response.raise_for_status()
            text = response.json()["choices"][0]["message"]["content"] or ""
            observation = parse_observation(text)
            desk.observation = observation
            desk.observed_at = time.time()
            self._on_update()
            if reason != "requested" and isinstance(observation.get("interjection"), dict):
                await self._on_interjection(desk, observation)
            return observation
        except Exception as error:  # noqa: BLE001 - observer failures must never break the room
            log.warning("desk observation for %s failed: %s", desk.name, error)
            return None
        finally:
            desk.analyzing = False


def parse_observation(text: str) -> dict:
    start, end = text.find("{"), text.rfind("}")
    if start < 0 or end <= start:
        raise ValueError("observer returned no JSON")
    data = json.loads(text[start : end + 1])
    if not isinstance(data, dict):
        raise ValueError("observer JSON is not an object")
    data.setdefault("progress", "unclear")
    data.setdefault("summary", "")
    data.setdefault("work_transcription", "")
    return data
