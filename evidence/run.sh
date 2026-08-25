#!/usr/bin/env bash
# Times the Keychain read in the three states the reader actually meets.
# Everything happens in a throwaway keychain under RUNNER_TEMP, so the runner's
# login keychain is never touched.
set -uo pipefail

KC="${RUNNER_TEMP:-/tmp}/oc-evidence.keychain-db"
PW="evidence"
SERVICE="Claude Code-credentials"
PAYLOAD='{"claudeAiOauth":{"accessToken":"a","refreshToken":"r","expiresAt":0}}'
RUNS=7

# Raw shell timing. Independent of the repo, so it stands even if the module
# run below fails to resolve.
raw() {
  local label="$1" i start end ms
  for i in $(seq 1 $RUNS); do
    start=$(python3 -c 'import time;print(int(time.time()*1000))')
    security find-generic-password -s "$SERVICE" -w >/dev/null 2>&1
    local rc=$?
    end=$(python3 -c 'import time;print(int(time.time()*1000))')
    ms=$((end - start))
    echo "raw    ${label}  run ${i}  ${ms}ms  exit=${rc}"
  done
}

echo "===== environment ====="
sw_vers
node --version
echo

echo "===== state 1: item absent ====="
raw "absent           "
npx -y tsx measure.ts "absent" || echo "(module run unavailable)"
echo

security create-keychain -p "$PW" "$KC"
security set-keychain-settings "$KC"
ORIG=$(security list-keychains -d user | sed 's/[" ]//g' | tr '\n' ' ')
security list-keychains -d user -s $ORIG "$KC"
security unlock-keychain -p "$PW" "$KC"
security add-generic-password -a claude -s "$SERVICE" -w "$PAYLOAD" "$KC"

echo "===== state 2: item present, keychain unlocked ====="
raw "present+unlocked "
npx -y tsx measure.ts "present+unlocked" || echo "(module run unavailable)"
echo

security lock-keychain "$KC"
echo "===== state 3: item present, keychain LOCKED ====="
echo "This is the headless steady state, and the case the review asked about."
raw "present+locked   "
npx -y tsx measure.ts "present+locked" || echo "(module run unavailable)"
echo

security list-keychains -d user -s $ORIG
security delete-keychain "$KC" 2>/dev/null
echo "cleaned up"
