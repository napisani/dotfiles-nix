#!/usr/bin/env bash

# ── Atuin AI auth (self-hosted atuin-ai-server) ─────────────────────────
# Single shared Doppler key: ATUIN_AI_AUTH_TOKEN.
#   - homelab/prd         -> k8s secret AUTH_TOKEN (server-side gate)
#   - workstation_env_vars -> exported here by secret_inject (0063)
# Atuin's env-override mechanism reads `ai.api_token` from the
# ATUIN_AI__API_TOKEN env var, so map the shared key onto it.
if [ -n "${ATUIN_AI_AUTH_TOKEN:-}" ]; then
	export ATUIN_AI__API_TOKEN="${ATUIN_AI_AUTH_TOKEN}"
fi
