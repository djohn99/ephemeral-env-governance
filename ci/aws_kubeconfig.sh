#!/usr/bin/env bash
set -euo pipefail
CLUSTER="${1:?}"; REGION="${2:?}"
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"
