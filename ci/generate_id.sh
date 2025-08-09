#!/usr/bin/env bash
set -euo pipefail
H=$(cat /proc/sys/kernel/random/uuid | cut -c1-5 | tr '[:upper:]' '[:lower:]')
echo "dynamic-env-${H}" | tr -cd 'a-z0-9-'
