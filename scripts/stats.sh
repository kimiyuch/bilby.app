#!/bin/zsh
# How many people use Bilby, from GitHub's download counts (summed over all releases), plus the
# website's own download counter when ../bilby.web is next to this repository.
# Every run appends a line to stats.log (gitignored), so you can see the numbers change over time.
set -euo pipefail
cd "$(dirname "$0")/.."

source ./release.env
# One line per release asset: "<name> <count>".
counts=$(gh api "repos/$REPO/releases" --paginate -q '.[].assets[] | "\(.name) \(.download_count)"')
sum() { print -r -- "$counts" | awk -v pattern="$1" '$1 ~ pattern { total += $2 } END { print total + 0 }' }

installs=$(sum '^Bilby\.dmg$')
updates=$(sum '^Bilby-.*\.zip$')
checks=$(sum '^appcast\.xml$')

echo "GitHub, all releases"
echo "  New installs (Bilby.dmg)       $installs"
echo "  Updates (Sparkle)              $updates"
echo "  Update checks (appcast.xml)    $checks"

# Sparkle checks about once a day, so new checks per day roughly equal the number of active installs.
if [[ -f stats.log ]]; then
  read -r last_time _ _ last_checks < <(tail -1 stats.log)
  days=$(( ($(date +%s) - last_time) / 86400.0 ))
  if (( days >= 0.5 )); then
    printf '  Active installs (estimate)     ~%.0f  (update checks per day since %s)\n' \
      $(( (checks - last_checks) / days )) "$(date -r "$last_time" +%Y-%m-%d)"
  fi
fi
echo "$(date +%s) $installs $updates $checks" >> stats.log

if [[ -x ../bilby.web/downloads.sh ]]; then
  echo
  echo "Website (bilby.kimiyu.ch/download)"
  ../bilby.web/downloads.sh
fi
