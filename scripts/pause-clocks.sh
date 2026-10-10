#!/bin/zsh
# Pauses the clock in every debug build that's testing: the Mac app and the app in each booted simulator.
# Run it when you're done testing, so no clock keeps playing sounds in the background.
set -uo pipefail
cd "$(dirname "$0")/.."

BUNDLE=ch.kimiyu.Bilby

if pgrep -f "Debug/Bilby.app/Contents/MacOS/Bilby" >/dev/null; then
  swift scripts/debug-remote.swift pause && echo "Paused the Mac debug app"
fi

for udid in $(xcrun simctl list devices booted -j | python3 -c 'import json,sys; print(*[d["udid"] for ds in json.load(sys.stdin)["devices"].values() for d in ds])'); do
  data=$(xcrun simctl get_app_container "$udid" "$BUNDLE" data 2>/dev/null) || continue
  state="$data/Library/Application Support/Bilby Debug/tournament.json"
  [[ -f $state ]] || state="$data/Library/Application Support/Bilby/tournament.json"
  grep -q '"running"' "$state" 2>/dev/null || continue
  # The remote only reaches a running app.
  xcrun simctl launch "$udid" "$BUNDLE" >/dev/null && sleep 3
  xcrun simctl spawn "$udid" notifyutil -p "$BUNDLE.debug.pause"
  sleep 1
  if grep -q '"running"' "$state"; then echo "Couldn't pause the clock in simulator $udid"; else echo "Paused the clock in simulator $udid"; fi
done
