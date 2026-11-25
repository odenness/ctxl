#!/usr/bin/env bash
# ctxl — context-window meter for the Claude Code status line.
# Reads the status line JSON on stdin and prints e.g.  ctx [████░░░░░░] 42% 84k/200k
# Docs for the input fields: https://code.claude.com/docs/en/statusline

if ! command -v jq >/dev/null 2>&1; then
  printf 'ctx: jq not installed\n'
  exit 0
fi

# One jq pass. total_input_tokens is what's in the window now (input + cache reads/writes
# from the latest response), not a running session total.
read -r USED TOTAL PCT < <(jq -r '[
    .context_window.total_input_tokens // "",
    .context_window.context_window_size // "",
    .context_window.used_percentage // ""
  ] | map(tostring) | map(if . == "" then "-" else . end) | join(" ")' 2>/dev/null)

# used_percentage is null early in a session and until the first response after /compact.
if [ -z "$PCT" ] || [ "$PCT" = "-" ] || [ "$USED" = "-" ] || [ "$TOTAL" = "-" ]; then
  printf 'ctx: --\n'
  exit 0
fi

PCT_INT=$(printf '%.0f' "$PCT")
# Clamp so the bar stays 10 cells even if the window is over its limit.
BAR_PCT=$PCT_INT
[ "$BAR_PCT" -gt 100 ] && BAR_PCT=100
[ "$BAR_PCT" -lt 0 ] && BAR_PCT=0

FILLED=$(( BAR_PCT * 10 / 100 ))
EMPTY=$(( 10 - FILLED ))
BAR=""
for (( i=0; i<FILLED; i++ )); do BAR="${BAR}█"; done
for (( i=0; i<EMPTY;  i++ )); do BAR="${BAR}░"; done

USED_K=$(awk -v n="$USED"  'BEGIN { printf "%.0fk", n/1000 }')
TOTAL_K=$(awk -v n="$TOTAL" 'BEGIN { printf "%.0fk", n/1000 }')

RESET=$'\033[0m'
if   [ "$PCT_INT" -ge 80 ]; then COLOR=$'\033[1;31m'; LABEL="⚠ ctx"
elif [ "$PCT_INT" -ge 60 ]; then COLOR=$'\033[1;33m'; LABEL="ctx"
else                             COLOR=$'\033[1;32m'; LABEL="ctx"
fi

printf '%s%s [%s] %d%% %s/%s%s\n' "$COLOR" "$LABEL" "$BAR" "$PCT_INT" "$USED_K" "$TOTAL_K" "$RESET"
