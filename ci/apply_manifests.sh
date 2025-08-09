#!/usr/bin/env bash
set -euo pipefail
DIR="${1:?}"; NS="${2:?}"
echo "Applying Services..."
ls "${DIR}"/*-services.yaml 2>/dev/null | xargs -r -I{} kubectl apply -f {} -n "$NS"
echo "Applying Ingress..."
ls "${DIR}"/*-ingress.yaml 2>/dev/null | xargs -r -I{} kubectl apply -f {} -n "$NS"
echo "Waiting 10s for ingress..."
sleep 10
echo "Applying remaining..."
find "$DIR" -type f \( -name '*.yaml' -o -name '*.yml' \) ! -name '*-ingress.yaml' -exec kubectl apply -f {} -n "$NS" \;
