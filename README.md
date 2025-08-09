# ephemeral-env-governance
Is a temporary, short-lived environment that’s created on demand—usually for testing, previewing, or validating changes—and then destroyed automatically once it’s no longer needed.

ephemeral-env-governance/
├─ .github/
│  └─ workflows/
│     └─ create-ephemeral-env.yml
├─ ci/
│  ├─ aws_kubeconfig.sh
│  ├─ generate_id.sh
│  ├─ create_ns.sh
│  ├─ create_sa.sh
│  ├─ create_crb.sh
│  ├─ sync_ecr_secret.sh
│  ├─ resolve_latest_tag.sh
│  ├─ prepare_manifests.sh
│  ├─ apply_manifests.sh
│  └─ notify.sh
└─ README.md

After adding: chmod +x ci/*.sh and tag the repo, e.g. v1.0.0.