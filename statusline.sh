#!/usr/bin/env bash
# ctxl — context-window meter for the Claude Code status line.
# Reads the status line JSON on stdin and prints e.g.  ctx [████░░░░░░] 42% 84k/200k
# Docs for the input fields: https://code.claude.com/docs/en/statusline

export LC_ALL=en_US.UTF-8   # so ${#var} counts characters, not bytes

INPUT=$(cat)

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
  ] | map(tostring) | map(if . == "" then "-" else . end) | join(" ")' <<<"$INPUT" 2>/dev/null)

RESET=$'\033[0m'

# used_percentage is null early in a session and until the first response after /compact.
if [ -z "$PCT" ] || [ "$PCT" = "-" ] || [ "$USED" = "-" ] || [ "$TOTAL" = "-" ]; then
  LEFT='ctx: --'; LEFT_COLORED=$LEFT
else
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

  if   [ "$PCT_INT" -ge 80 ]; then COLOR=$'\033[1;31m'; LABEL="⚠ ctx"
  elif [ "$PCT_INT" -ge 60 ]; then COLOR=$'\033[1;33m'; LABEL="ctx"
  else                             COLOR=$'\033[1;32m'; LABEL="ctx"
  fi

  LEFT="${LABEL} [${BAR}] ${PCT_INT}% ${USED_K}/${TOTAL_K}"
  LEFT_COLORED="${COLOR}${LEFT}${RESET}"
fi

# ── Right side: 5-hour session usage as a filling circle ─────────────────────
# rate_limits only exists for claude.ai Pro/Max/Ultra and only after the first response.
read -r S_PCT S_RESET < <(jq -r '[
    .rate_limits.five_hour.used_percentage // "-",
    .rate_limits.five_hour.resets_at // "-"
  ] | map(tostring) | join(" ")' <<<"$INPUT" 2>/dev/null)

RIGHT=""; RIGHT_COLORED=""

# ── Optional session cost in £ (toggle with: ctxl cost) ──────────────────────
CTXL_DIR="${CTXL_HOME:-$HOME/.claude/ctxl}"
if [ -e "$CTXL_DIR/show-cost" ]; then
  RATE_FILE="$CTXL_DIR/gbp-rate"
  RATE=$(cat "$RATE_FILE" 2>/dev/null || true)
  [[ "$RATE" =~ ^[0-9]*\.?[0-9]+$ ]] || RATE=0.77
  # Refresh the cached rate at most once a day, in the background so we never block.
  if [ ! -e "$RATE_FILE" ] || [ -n "$(find "$RATE_FILE" -mtime +0 2>/dev/null)" ]; then
    touch "$RATE_FILE.tmp" 2>/dev/null
    ( curl -sfL --max-time 5 'https://api.frankfurter.dev/v1/latest?from=USD&to=GBP' \
        | jq -r '.rates.GBP // empty' > "$RATE_FILE.tmp" \
      && [ -s "$RATE_FILE.tmp" ] && mv "$RATE_FILE.tmp" "$RATE_FILE" || touch "$RATE_FILE" ) \
      >/dev/null 2>&1 &
  fi
  USD=$(jq -r '.cost.total_cost_usd // 0' <<<"$INPUT" 2>/dev/null)
  GBP=$(awk -v u="${USD:-0}" -v r="$RATE" 'BEGIN { printf "£%.2f", u*r }')
  RIGHT="$GBP"
  RIGHT_COLORED=$'\033[1;35m'"${GBP}${RESET}"
fi
if [ -n "$S_PCT" ] && [ "$S_PCT" != "-" ]; then
  S_INT=$(printf '%.0f' "$S_PCT")
  if   [ "$S_INT" -ge 100 ]; then CIRCLE="●"
  elif [ "$S_INT" -ge 75 ];  then CIRCLE="◕"
  elif [ "$S_INT" -ge 50 ];  then CIRCLE="◑"
  elif [ "$S_INT" -ge 25 ];  then CIRCLE="◔"
  else                            CIRCLE="○"
  fi
  if   [ "$S_INT" -ge 80 ]; then S_COLOR=$'\033[1;31m'
  elif [ "$S_INT" -ge 60 ]; then S_COLOR=$'\033[1;33m'
  else                           S_COLOR=$'\033[1;36m'
  fi

  S_TEXT="${CIRCLE} ${S_INT}%"
  if [ -n "$S_RESET" ] && [ "$S_RESET" != "-" ]; then
    LEFT_S=$(( ${S_RESET%.*} - $(date +%s) ))
    if [ "$LEFT_S" -gt 0 ]; then
      S_TEXT="${S_TEXT} ↻$(( LEFT_S / 3600 ))h$(printf '%02d' $(( LEFT_S % 3600 / 60 )))m"
    fi
  fi
  if [ -n "$RIGHT" ]; then RIGHT="${RIGHT}  "; RIGHT_COLORED="${RIGHT_COLORED}  "; fi
  RIGHT="${RIGHT}${S_TEXT}"
  RIGHT_COLORED="${RIGHT_COLORED}${S_COLOR}${S_TEXT}${RESET}"
fi

# Pad between the two halves so the circle sits at the right edge.
# Claude Code passes the width in COLUMNS; keep 4 columns spare or the line gets truncated.
WIDTH=$(( ${COLUMNS:-0} - 4 ))
GAP=$(( WIDTH - ${#LEFT} - ${#RIGHT} ))
if [ -z "$RIGHT" ]; then
  printf '%s\n' "$LEFT_COLORED"
elif [ "$GAP" -ge 2 ]; then
  printf '%s%*s%s\n' "$LEFT_COLORED" "$GAP" "" "$RIGHT_COLORED"
else
  printf '%s  %s\n' "$LEFT_COLORED" "$RIGHT_COLORED"   # too narrow / unknown width: just follow on
fi
