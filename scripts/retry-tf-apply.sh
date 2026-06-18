#!/usr/bin/env bash
set -euo pipefail

INTERVAL="${INTERVAL:-300}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-0}"

attempt=0
while true; do
  attempt=$((attempt + 1))
  echo "=== Attempt ${attempt} at $(date) ==="

  if (cd terraform && terraform apply -auto-approve); then
    echo "Success! Instance created."
    cd terraform && terraform output
    exit 0
  fi

  if [[ "${MAX_ATTEMPTS}" -gt 0 && "${attempt}" -ge "${MAX_ATTEMPTS}" ]]; then
    echo "Reached max attempts (${MAX_ATTEMPTS}). Exiting."
    exit 1
  fi

  echo "Apply failed (likely out of host capacity). Retrying in ${INTERVAL}s..."
  sleep "${INTERVAL}"
done
