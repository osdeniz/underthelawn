#!/bin/sh
# Runs every *Check*.tscn (and FourMowers, Legibility) and prints one line each.
# A suite that prints no verdict is "??", never "ok" — a harness that cannot
# fail is worse than none (G14.x). Usage: tools/run_tests.sh [pattern]
#   UTL_LIMIT  seconds per test (default 150)
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
LIMIT="${UTL_LIMIT:-150}"
PATTERN="${1:-}"
cd "$(dirname "$0")/.." || exit 1
pass=0; fail=0; unknown=0
for scene in tests/*Check*.tscn tests/FourMowers.tscn tests/Legibility.tscn tests/FullFlow.tscn tests/Case2Flow*.tscn; do
  [ -f "$scene" ] || continue
  name=$(basename "$scene" .tscn)
  case "$name" in *"$PATTERN"*) ;; *) continue;; esac
  out=$( ( "$GODOT" --path . --resolution 1170x2532 "res://$scene" 2>&1 & pid=$!;
           ( i=0; while [ $i -lt "$LIMIT" ]; do sleep 1; kill -0 $pid 2>/dev/null || exit 0; i=$((i+1)); done; kill -9 $pid 2>/dev/null ) & w=$!;
           wait $pid; kill $w 2>/dev/null ) | grep -E "GECTI|BASARISIZ|AYNI|OKUNUYOR|FAIL" )
  if echo "$out" | grep -qE "GECTI|AYNI|OKUNUYOR"; then
    printf "ok   %s\n" "$name"; pass=$((pass+1))
  elif echo "$out" | grep -qE "BASARISIZ|FAIL"; then
    printf "FAIL %s\n%s\n" "$name" "$(echo "$out" | grep FAIL | head -5)"; fail=$((fail+1))
  else
    printf "??   %s (verdict yok)\n" "$name"; unknown=$((unknown+1))
  fi
done
printf -- "--- %d ok, %d FAIL, %d ?? ---\n" "$pass" "$fail" "$unknown"
[ "$fail" -eq 0 ] && [ "$unknown" -eq 0 ]
