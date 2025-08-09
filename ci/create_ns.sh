#!/usr/bin/env bash
set -euo pipefail
NS="${1:?}"
kubectl create namespace "$NS" 2>/dev/null || true
