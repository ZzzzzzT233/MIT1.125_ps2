#!/usr/bin/env bash
# Workflow layer: coordinate library operations.
# Connects UI prompts -> book components -> data layer -> UI display.
# This file decides the ORDER of steps; each step is done by another program.
#
# Usage: manage_library.sh <browse|add|search|update|stats|interests|save-rec "title|author|genre">

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB="$ROOT/data/book_database.sh"
UI="$ROOT/ui/library_screen.sh"
META="$ROOT/books/fetch_book_metadata.sh"
SEARCH="$ROOT/books/search_books.sh"

trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

# "Title | Author | Genre | Year | Link" + status + rating -> database
save_meta() {
  local t a g y l
  IFS='|' read -r t a g y l <<< "$1"
  t="$(trim "$t")"; a="$(trim "$a")"; g="$(trim "$g")"; y="$(trim "$y")"; l="$(trim "$l")"
  [ "$y" = "?" ] && y=""
  if "$DB" add "$t" "$a" "$g" "$2" "$3" "$y" "$l"; then
    "$UI" ok "Saved \"$t\" as $2"
  else
    "$UI" error "Could not save \"$t\""
  fi
}

case "${1:-}" in
  browse)   # Database -> UI
    "$UI" banner "My Library"
    "$DB" list | sort -t, -k4,4 -k1,1 | "$UI" table ;;

  add)      # User input -> Metadata -> Database
    book="$("$UI" ask_book)" || exit 0
    title="$(trim "${book%%|*}")"
    if "$DB" exists "$title"; then "$UI" error "\"$title\" is already in your library"; exit 0; fi
    meta="$("$UI" spin "Looking up metadata..." "$META" "$book")"
    echo "$meta" | awk -F' [|] ' -v OFS=, '{ print $1, $2, $3, "-", "", $4, $5 }' | "$UI" details
    "$UI" confirm "Save this book?" || exit 0
    status="$("$UI" ask_status)" || exit 0
    rating=""; [ "$status" = finished ] && rating="$("$UI" ask_rating)"
    save_meta "$meta" "$status" "$rating" ;;

  search)   # Search request -> Search component -> Results -> UI   (a pipe end to end)
    term="$("$UI" ask_term)" || exit 0
    "$UI" banner "Results for \"$term\""
    echo "$term" | "$SEARCH" | "$UI" table ;;

  update)   # Pick a book -> new status/rating -> Database -> show details
    title="$("$DB" list | "$UI" pick_book)" || exit 0
    status="$("$UI" ask_status)" || exit 0
    "$DB" update-status "$title" "$status"
    if [ "$status" = finished ]; then
      rating="$("$UI" ask_rating)" && "$DB" update-rating "$title" "$rating"
    fi
    "$DB" get "$title" | "$UI" details ;;

  stats)
    "$UI" banner "Reading Stats"
    "$DB" list | "$UI" stats ;;

  interests)  # Database -> editor -> Database
    new="$("$DB" interests | "$UI" ask_interests)" || exit 0
    printf '%s\n' "$new" | "$DB" set-interests
    "$UI" ok "Interests saved ($(printf '%s\n' "$new" | grep -c .) topics)" ;;

  save-rec)   # Recommendation pick -> Metadata -> Database
    IFS='|' read -r t a _ <<< "$2"
    meta="$(echo "$t | $a" | "$META")"
    save_meta "$meta" want-to-read "" ;;

  *) echo "usage: manage_library.sh <browse|add|search|update|stats|interests|save-rec>" >&2; exit 2 ;;
esac
