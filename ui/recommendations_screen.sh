#!/usr/bin/env bash
# UI layer: display recommendation progress and final results.
#
# Usage: recommendations_screen.sh <screen> [args]
#   banner                          heading
#   progress <tick> <secs> name=status ...   redraw ONE live status line
#   agent_done <name> <exit> <count>         final line for one agent
#   shortlist                       stdin: refined shortlist -> show it, let me
#                                   pick one; prints "title|author|genre" or exits 1

ACCENT=212
FRAMES='|/-\'

screen="${1:-}"; shift || true
case "$screen" in
  banner)
    gum style --foreground "$ACCENT" --bold --border double --padding "0 2" \
      "Recommendation agents" "history | interests | discovery  (running in parallel)" ;;

  progress)
    tick="$1"; secs="$2"; shift 2
    line=""
    for s in "$@"; do
      name="${s%%=*}"; st="${s#*=}"
      if [ "$st" = running ]; then c=33; else c=32; fi    # yellow / green
      line="$line  $name: \033[${c}m$st\033[0m"
    done
    # \r + "clear line" overwrites the previous status line = streaming progress
    printf '\r\033[K \033[35m%s\033[0m %5ss %b' "${FRAMES:$((tick % 4)):1}" "$secs" "$line" ;;

  agent_done)
    if [ "$2" -eq 0 ]; then gum style --foreground 2 "  ✓ $1 agent: $3 candidate(s)"
    else gum style --foreground 1 "  ✗ $1 agent failed (exit $2)"; fi ;;

  shortlist)
    rows="$(cat)"
    if [ -z "$rows" ]; then gum style --faint "  No new recommendations - you own everything I know about!" >&2; exit 1; fi
    body="$(printf '%s\n' "$rows" | awk -F'|' '{
      tag = ($5 ~ /discovery/) ? "  [WILDCARD]" : ""
      printf "%d. %s - %s%s\n   %s | score %s | via %s\n   %s\n\n", NR, $2, $3, tag, $4, $1, $5, $6 }')"
    gum style --border rounded --border-foreground "$ACCENT" --padding "0 2" \
      "$(gum style --bold "Your shortlist")" "" "$body" >&2
    titles=(); while IFS='|' read -r _ t _; do titles+=("$t"); done <<< "$rows"
    pick="$(gum choose --header "Save one to your want-to-read list?" "${titles[@]}" "<- Back to menu" < /dev/tty)" || exit 1
    [ "$pick" = "<- Back to menu" ] && exit 1
    printf '%s\n' "$rows" | awk -F'|' -v p="$pick" '$2 == p { print $2 "|" $3 "|" $4; exit }' ;;

  *) sed -n '3,9p' "$0" >&2; exit 2 ;;
esac
