#!/usr/bin/env bash
# UI layer: display library information and collect library input.
# Pure presentation + prompts (Gum). No storage access, no business logic.
#
# Usage: library_screen.sh <screen> [args]
#   banner <text>      big heading
#   table              stdin: CSV book rows -> formatted table
#   details            stdin: one CSV book row -> detail card
#   stats              stdin: CSV book rows -> reading summary
#   ask_book           prompt -> "Title | Author"
#   ask_term           prompt -> search term
#   ask_status         prompt -> want-to-read|reading|finished|owned
#   ask_rating         prompt -> 1-5 or "" (no rating)
#   ask_interests      stdin: current interests -> edited interests
#   pick_book          stdin: CSV book rows -> chosen title
#   confirm <question> exit 0 if yes
#   spin <title> <cmd...>   run cmd behind a spinner, pass its stdout through
#   ok|error <message>

ACCENT=212   # pink — my app colour

screen="${1:-}"; shift || true
case "$screen" in
  banner)
    gum style --foreground "$ACCENT" --bold --border double --padding "0 2" "$@" ;;

  table)
    rows="$(cat)"
    if [ -z "$rows" ]; then gum style --faint "  (no books)"; exit 0; fi
    count="$(printf '%s\n' "$rows" | wc -l | tr -d ' ')"
    body="$(printf '%s\n' "$rows" | awk -F, '
      function cut(s, w) { return length(s) > w ? substr(s, 1, w - 1) "~" : s }
      BEGIN { printf "%-38s %-24s %-16s %-13s %-6s %s\n", "TITLE", "AUTHOR", "GENRE", "STATUS", "RATING", "YEAR" }
      {
        rating = ($5 == "") ? "-" : $5 "/5"
        printf "%-38s %-24s %-16s %-13s %-6s %s\n", cut($1, 38), cut($2, 24), cut($3, 16), $4, rating, ($6 == "" ? "?" : $6)
      }')"
    gum style --border rounded --border-foreground "$ACCENT" --padding "0 1" "$body"
    gum style --faint "  $count book(s)" ;;

  details)
    IFS=, read -r t a g s r y l
    gum style --border rounded --border-foreground "$ACCENT" --padding "0 2" \
      "$(gum style --bold --foreground "$ACCENT" "$t")" \
      "by $a" "" "Genre:  $g" "Status: $s" "Rating: ${r:--}" "Year:   ${y:-?}" "Link:   ${l:--}" ;;

  stats)
    body="$(awk -F, '
      { n++; st[$4]++; g[$3]++; if ($5 != "") { rs += $5; rn++ } }
      END {
        if (!n) { print "No books yet."; exit }
        for (k in g) if (g[k] > best) { best = g[k]; top = k }
        printf "Books in library : %d\n", n
        printf "Finished         : %d\n", st["finished"]
        printf "Reading now      : %d\n", st["reading"]
        printf "Want to read     : %d\n", st["want-to-read"]
        printf "Owned, unread    : %d\n", st["owned"]
        printf "Average rating   : %s\n", rn ? sprintf("%.1f / 5 (%d rated)", rs / rn, rn) : "-"
        printf "Favourite genre  : %s (%d)\n", top, best
      }')"
    gum style --border rounded --border-foreground "$ACCENT" --padding "0 2" "$body" ;;

  ask_book)
    title="$(gum input --prompt "Title  > " --placeholder "e.g. Dune")" || exit 1
    [ -z "$title" ] && exit 1
    author="$(gum input --prompt "Author > " --placeholder "optional - helps the metadata lookup")" || exit 1
    echo "$title | $author" ;;

  ask_term)
    term="$(gum input --prompt "Search > " --placeholder "title, author, genre or status")" || exit 1
    [ -n "$term" ] && echo "$term" ;;

  ask_status)
    gum choose --header "Reading status?" want-to-read reading finished owned ;;

  ask_rating)
    r="$(gum choose --header "Rating?" "no rating" 5 4 3 2 1)" || exit 1
    [ "$r" = "no rating" ] && r=""
    echo "$r" ;;

  ask_interests)
    gum write --header "One interest per line (ctrl+d to save, esc to cancel)" \
      --width 50 --height 12 --value "$(cat)" < /dev/tty ;;

  pick_book)
    titles=(); while IFS=, read -r t _; do [ -n "$t" ] && titles+=("$t"); done
    [ ${#titles[@]} -eq 0 ] && { gum style --faint "  (no books)"; exit 1; }
    gum choose --header "Which book?" "${titles[@]}" < /dev/tty ;;

  confirm) gum confirm "$*" ;;
  spin)    msg="$1"; shift; gum spin --spinner dot --title "$msg" --show-output -- "$@" ;;
  ok)      gum style --foreground 2 "  ✓ $*" ;;
  error)   gum style --foreground 1 "  ✗ $*" ;;
  *)       sed -n '5,20p' "$0" >&2; exit 2 ;;
esac
