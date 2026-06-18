#!/usr/bin/env bash
set -euo pipefail

INTERVAL="${INTERVAL:-300}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-0}"
SUMMARY_LOG="${SUMMARY_LOG:-/tmp/tf-retry.log}"
RAW_LOG="${RAW_LOG:-/tmp/tf-retry-raw.log}"

log_summary() {
  echo "$(date '+%Y-%m-%d %H:%M:%S %Z') | $*" >> "$SUMMARY_LOG"
}

attempt=0
while true; do
  attempt=$((attempt + 1))
  log_summary "ATTEMPT ${attempt} started"

  if {
    echo "=== Attempt ${attempt} at $(date) ==="
    cd terraform && terraform apply -auto-approve
  } >> "$RAW_LOG" 2>&1; then
    {
      echo "=== Outputs at $(date) ==="
      cd terraform && terraform output
    } >> "$RAW_LOG" 2>&1
    public_ip="$(cd terraform && terraform output -raw public_ip 2>/dev/null || true)"
    log_summary "SUCCESS | public_ip=${public_ip:-unknown}"
    exit 0
  fi

  if tail -30 "$RAW_LOG" | grep -q "Out of host capacity"; then
    log_summary "FAILED | out of host capacity"
  else
    log_summary "FAILED | see ${RAW_LOG}"
  fi

  if [[ "${MAX_ATTEMPTS}" -gt 0 && "${attempt}" -ge "${MAX_ATTEMPTS}" ]]; then
    log_summary "STOPPED | max attempts (${MAX_ATTEMPTS})"
    exit 1
  fi

  sleep "${INTERVAL}"
done