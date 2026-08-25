#!/usr/bin/env bash
# Times the Keychain read in the three states the reader actually meets.
# Everything happens in a throwaway keychain under RUNNER_TEMP, so the runner's
# login keychain is never touched.
#
# The bounded module reader runs first in each state. The raw command runs
# second under a hard alarm, because an unbounded `security` call against a
# locked keychain is exactly the thing under investigation and must not be
# allowed to wedge the job.
set -uo pipefail

KC="${RUNNER_TEMP:-/tmp}/oc-evidence.keychain-db"
PW="evidence"
SERVICE="Claude Code-credentials"
PAYLOAD='{"claudeAiOauth":{"accessToken":"a","refreshToken":"r","expiresAt":0}}'
RUNS=5
ALARM=15

raw() {
  local label="$1" i start end ms rc
  for i in $(seq 1 $RUNS); do
    start=$(python3 -c 'import time;print(int(time.time()*1000))')
    perl -e "alarm $ALARM; exec @ARGV" -- security find-generic-password -s "$SERVICE" -w >/dev/null 2>&1
    rc=$?
    end=$(python3 -c 'import time;print(int(time.time()*1000))')
    ms=$((end - start))
    if [ "$rc" -ge 128 ]; then
      echo "raw    ${label}  run ${i}  ${ms}ms  KILLED at ${ALARM}s alarm (rc=${rc})"
    else
      echo "raw    ${label}  run ${i}  ${ms}ms  exit=${rc}"
    fi
  done
}

echo "===== environment ====="
sw_vers
node --version
echo

echo "--- warming tsx once so install time is not counted ---"
npx -y tsx --version || true
echo

echo "===== state 1: item absent ====="
npx -y tsx measure.ts "absent" || echo "(module run unavailable)"
raw "absent           "
echo

security create-keychain -p "$PW" "$KC"
security set-keychain-settings "$KC"
ORIG=$(security list-keychains -d user | sed 's/[" ]//g' | tr '\n' ' ')
security list-keychains -d user -s $ORIG "$KC"
security unlock-keychain -p "$PW" "$KC"
security add-generic-password -a claude -s "$SERVICE" -w "$PAYLOAD" "$KC"

echo "===== state 2: item present, keychain unlocked ====="
npx -y tsx measure.ts "present+unlocked" || echo "(module run unavailable)"
raw "present+unlocked "
echo

security lock-keychain "$KC"
echo "===== state 3: item present, keychain LOCKED ====="
echo "This is the headless steady state, and the case the review asked about."
npx -y tsx measure.ts "present+locked" || echo "(module run unavailable)"
raw "present+locked   "
echo

security list-keychains -d user -s $ORIG
security delete-keychain "$KC" 2>/dev/null
echo "cleaned up"
