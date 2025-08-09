#!/usr/bin/env bash
set -euo pipefail
WEBHOOK="${1:?}"; UID="${2:?}"; TTL="${3:?}"
JOB_URL="${GITHUB_SERVER_URL:-}${GITHUB_SERVER_URL:+/}${GITHUB_REPOSITORY:-}${GITHUB_REPOSITORY:+/actions/runs/}${GITHUB_RUN_ID:-}"
MSG="<h2>Ephemeral Environment Created 🎉</h2><b>ID:</b> ${UID}<br><b>TTL:</b> ${TTL} minutes<br><b>Run:</b> <a href='${JOB_URL}'>Open</a>"
curl -sS -X POST -H 'Content-Type: application/json' -d "{\"text\":\"${MSG}\"}" "$WEBHOOK" >/dev/null
