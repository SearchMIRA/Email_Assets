#!/usr/bin/env bash
# Flag GIFs that are too large to animate in Gmail.
#
#   tools/check-gif-sizes.sh              # check every GIF in the repo
#   tools/check-gif-sizes.sh a.gif b.gif  # check specific files
#
# Also runs as a pre-commit hook (see tools/install-hooks.sh).
#
# Thresholds — Gmail publishes no official number, these come from testing
# against this repo's own assets:
#   <= 2 MB   safe everywhere, loads fast on mobile data
#    > 5 MB   heavy; animates but slow to appear
#   >~20 MB   Gmail's image proxy serves the FIRST FRAME ONLY
WARN_MB="${WARN_MB:-2}"
FAIL_MB="${FAIL_MB:-5}"

warn_bytes=$(awk "BEGIN{printf \"%d\", $WARN_MB * 1048576}")
fail_bytes=$(awk "BEGIN{printf \"%d\", $FAIL_MB * 1048576}")

if [ "$#" -gt 0 ]; then
  files=("$@")
else
  IFS=$'\n' read -r -d '' -a files < <(find . -name '*.gif' -not -path './.git/*' | sort && printf '\0')
fi

status=0
warned=0
for f in "${files[@]}"; do
  [ -f "$f" ] || continue
  case "$f" in *.gif|*.GIF) ;; *) continue ;; esac

  size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f")
  mb=$(awk "BEGIN{printf \"%.2f\", $size/1048576}")

  if [ "$size" -gt "$fail_bytes" ]; then
    printf 'FAIL  %-40s %8s MB  (Gmail may show first frame only)\n' "$f" "$mb"
    status=1
  elif [ "$size" -gt "$warn_bytes" ]; then
    printf 'WARN  %-40s %8s MB  (over %s MB target)\n' "$f" "$mb" "$WARN_MB"
    warned=1
  else
    printf 'ok    %-40s %8s MB\n' "$f" "$mb"
  fi
done

if [ "$status" -ne 0 ]; then
  echo
  echo "Shrink with:  TARGET_MB=2 TRIM=8 tools/gif-for-email.sh <file.gif>"
elif [ "$warned" -ne 0 ]; then
  echo
  echo "Above target but will still animate. Shrink with tools/gif-for-email.sh if you want faster loads."
fi
exit $status
