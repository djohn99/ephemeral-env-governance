#!/usr/bin/env bash
set -euo pipefail
NS="${1:?}"; SA="${2:-vault-auth}"
cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${SA}
  namespace: ${NS}
YAML
