#!/usr/bin/env bash
# Starts the study-room tutor agent and the web client together.
# Credentials come from STUDY_ROOM_ENV_FILE (default: room/.env.local), which needs
# LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET, OPENAI_API_KEY and optionally
# OPENROUTER_API_KEY (desk observer). Nothing is copied into the repository.
set -euo pipefail
cd "$(dirname "$0")"
ENV_FILE="${STUDY_ROOM_ENV_FILE:-$PWD/.env.local}"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE. Copy .env.example to .env.local or set STUDY_ROOM_ENV_FILE." >&2
  exit 1
fi
set -a; source "$ENV_FILE"; set +a
export STUDY_ROOM_ENV_FILE="$ENV_FILE"
PORT="${PORT:-3000}"

if [[ ! -x agent/.venv/bin/python ]]; then
  (cd agent && uv venv --python 3.12 .venv && uv pip install --python .venv/bin/python -r requirements.txt)
fi
if [[ ! -d web/node_modules ]]; then
  (cd web && bun install)
fi

(cd agent && exec .venv/bin/python agent.py dev) &
AGENT_PID=$!
trap 'kill $AGENT_PID 2>/dev/null || true' EXIT
cd web && exec bunx next dev -p "$PORT"
