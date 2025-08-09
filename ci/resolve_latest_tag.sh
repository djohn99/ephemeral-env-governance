#!/usr/bin/env bash
set -euo pipefail
REPO="${1:?repo}"  # e.g. env/rendering-template
AWS_REGION="${AWS_REGION:?AWS_REGION must be set}"
aws ecr describe-images \
  --repository-name "$REPO" \
  --region "$AWS_REGION" \
  --query 'sort_by(imageDetails,& imagePushedAt)[-1].imageTags[0]' \
  --output text
