#!/usr/bin/env bash
set -euo pipefail
NS="${1:?}"; SA="${2:-vault-auth}"
cat <<YAML | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${NS}
subjects:
  - kind: ServiceAccount
    name: ${SA}
    namespace: ${NS}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
YAML
