#!/usr/bin/env bash
set -euo pipefail
SOURCE_NS="${1:?source ns}"; TARGET_NS="${2:?target ns}"; ECR_REGISTRY="${3:?registry}"
AWS_REGION="${AWS_REGION:?AWS_REGION must be set}"
PATCH_DEFAULT_SA="${PATCH_DEFAULT_SA:-true}"
SECRET_NAME="${SECRET_NAME:-}"

if [[ -z "$SECRET_NAME" ]]; then
  CANDIDATES=$(kubectl -n "$SOURCE_NS" get secret -o json \
    | jq -r '.items[] | select(.type=="kubernetes.io/dockerconfigjson") | .metadata.name')
  for s in $CANDIDATES; do
    RAW=$(kubectl -n "$SOURCE_NS" get secret "$s" -o jsonpath='{.data.\.dockerconfigjson}')
    DECODED=$(printf '%s' "$RAW" | base64 -d || true)
    if echo "$DECODED" | jq -e --arg reg "$ECR_REGISTRY" '.auths | has($reg)' >/dev/null 2>&1; then
      SECRET_NAME="$s"; break
    fi
  done
fi
SECRET_NAME="${SECRET_NAME:-ecr-pull-secret}"
echo "Using secret name: $SECRET_NAME (source: $SOURCE_NS -> target: $TARGET_NS)"

kubectl get ns "$TARGET_NS" >/dev/null 2>&1 || kubectl create ns "$TARGET_NS"

aws ecr get-login-password --region "$AWS_REGION" | \
kubectl create secret docker-registry "$SECRET_NAME" \
  --docker-server="$ECR_REGISTRY" \
  --docker-username=AWS \
  --docker-password-stdin \
  --namespace "$TARGET_NS" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "Secret $SECRET_NAME refreshed in $TARGET_NS."

if [[ "$PATCH_DEFAULT_SA" == "true" ]]; then
  kubectl -n "$TARGET_NS" patch serviceaccount default \
    --type merge -p "{\"imagePullSecrets\":[{\"name\":\"$SECRET_NAME\"}]}" >/dev/null || true
  echo "Patched default ServiceAccount in $TARGET_NS to use $SECRET_NAME."
fi
