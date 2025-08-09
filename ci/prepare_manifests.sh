#!/usr/bin/env bash
set -euo pipefail

RESOLVE_LATEST=0
while [[ $# -gt 0 ]]; do
  case $1 in
    --workdir) WORKDIR="$2"; shift 2;;
    --base-env) BASE="$2"; shift 2;;
    --uid) UID="$2"; shift 2;;
    --services) SERVICES_CSV="$2"; shift 2;;
    --versions) VERSIONS_JSON="$2"; shift 2;;
    --ecr-registry) ECR_REG="$2"; shift 2;;
    --ecr-repo-map) ECR_MAP_JSON="$2"; shift 2;;
    --resolve-latest) RESOLVE_LATEST=1; shift;;
    --services-file) SERVICES_FILE="$2"; shift 2;;           # optional (not used by workflow, but supported)
    --ecr-repo-map-file) ECR_MAP_FILE="$2"; shift 2;;        # optional
    *) echo "Unknown arg $1" >&2; exit 1;;
  esac
done

[ -n "${WORKDIR:-}" ] && [ -n "${BASE:-}" ] && [ -n "${UID:-}" ] && [ -n "${ECR_REG:-}" ] || { echo "missing args" >&2; exit 1; }
export AWS_REGION="${AWS_REGION:-$(aws configure get region || true)}"

# load optional file inputs
if [[ -n "${SERVICES_FILE:-}" && -z "${SERVICES_CSV:-}" ]]; then
  SERVICES_CSV=$(grep -v '^\s*$' "$SERVICES_FILE" | tr '\n' ',' | sed 's/,$//')
fi
if [[ -z "${ECR_MAP_JSON:-}" && -n "${ECR_MAP_FILE:-}" && -f "$ECR_MAP_FILE" ]]; then
  ECR_MAP_JSON="$(cat "$ECR_MAP_FILE")"
fi
# fallback: build map from ECR_REPO_PREFIX
if [[ -z "${ECR_MAP_JSON:-}" && -n "${ECR_REPO_PREFIX:-}" && -n "${SERVICES_CSV:-}" ]]; then
  prefix="${ECR_REPO_PREFIX%/}"
  ECR_MAP_JSON="$(python - <<'PY' "$SERVICES_CSV" "$prefix"
import json, sys
svcs=sys.argv[1].split(',')
prefix=sys.argv[2]
print(json.dumps({s.strip(): f"{prefix}/{s.strip()}" for s in svcs if s.strip()}))
PY
)"
fi

# sanity
[ -n "${SERVICES_CSV:-}" ] || { echo "No services provided" >&2; exit 1; }
[ -n "${ECR_MAP_JSON:-}" ]  || { echo "No ECR repo map provided" >&2; exit 1; }

SRC="./${WORKDIR}/${BASE}"
OUT="./ephemeral-ws-${UID}"
mkdir -p "$OUT"

ENV_TAG="${BASE##*-}"
ECR_MAP="$(printf '%s' "$ECR_MAP_JSON")"
VERSIONS="$(printf '%s' "$VERSIONS_JSON")"
IFS=',' read -r -a SERVICES <<< "$SERVICES_CSV"

repo_for(){ jq -r --arg k "$1" '.[$k]' <<<"$ECR_MAP"; }
tag_for(){
  local svc="$1" tag; tag=$(jq -r --arg k "$svc" '.[$k] // "latest"' <<<"$VERSIONS")
  if [[ "$tag" == "latest" && $RESOLVE_LATEST -eq 1 ]]; then
    local repo; repo="$(repo_for "$svc")"
    [[ -n "$repo" && "$repo" != "null" ]] && tag="$(bash ci/resolve_latest_tag.sh "$repo")"
  fi; echo "$tag"
}

for SVC in "${SERVICES[@]}"; do
  SVC="${SVC// /}"
  REPO="$(repo_for "$SVC")"; [[ -n "$REPO" && "$REPO" != "null" ]] || { echo "No ECR repo map for $SVC" >&2; exit 1; }
  TAG="$(tag_for "$SVC")"

  for folder in deployments services ingress; do
    for ext in yaml yml; do
      SRCF="${SRC}/${folder}/${SVC}.${ext}"
      DESTF="${OUT}/${SVC}-${folder}.${ext}"
      if [ -f "$SRCF" ]; then
        cp "$SRCF" "$DESTF"
        yq e ".metadata.namespace = \"${UID}\"" -i "$DESTF"
        if [ "$folder" = "deployments" ]; then
          # Replace image ending with :<env tag> OR forcibly set image if not found
          sed -i -E "s#(^[[:space:]]*image:[[:space:]]*).*(:${ENV_TAG})#\1${ECR_REG}/${REPO}:${TAG}#g" "$DESTF" || true
          if ! grep -q "${ECR_REG}/${REPO}:${TAG}" "$DESTF"; then
            yq e ".spec.template.spec.containers[] |= (.image = \"${ECR_REG}/${REPO}:${TAG}\")" -i "$DESTF"
          fi
        fi
      fi
    done
  done

  # copy global configmaps
  for ext in yaml yml; do
    for CM in "${SRC}/configmaps/"*.${ext}; do
      [ -e "$CM" ] || continue
      DESTF="${OUT}/$(basename "$CM")"
      cp "$CM" "$DESTF"
      yq e ".metadata.namespace = \"${UID}\"" -i "$DESTF"
    done
  done
done

# global replacements
find "$OUT" -type f \( -name '*.yaml' -o -name '*.yml' \) -exec sed -i "s#cache-${BASE}#${UID}#g" {} +
find "$OUT" -type f \( -name '*.yaml' -o -name '*.yml' \) -exec sed -i "s#${BASE}#${UID}#g" {} +
find "$OUT" -type f \( -name '*.yaml' -o -name '*.yml' \) -exec sed -i "s#HOSTING_REGION: EKS-BAH#HOSTING_REGION: ${UID}#g" {} +
