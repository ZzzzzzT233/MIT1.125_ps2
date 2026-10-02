#!/usr/bin/env bash
# Data layer: the ONLY application file that reads or writes books.csv
# (and the interests profile). Everything else asks this program.
#
# Usage: book_database.sh <command> [args]
#   list                              all books as CSV rows (no header)
#   search <term>                     rows containing <term> (case-insensitive)
#   get <title>                       the row for one title
#   exists <title>                    exit 0 if the title is in the library
#   titles                            one title per line
#   add <title> <author> <genre> <status> <rating> <year> <link>
#   update-status <title> <status>    status: want-to-read|reading|finished|owned
#   update-rating <title> <rating>    rating: 1-5, or "" to clear
#   interests                         my interests, one per line
#   set-interests                     replace interests with stdin
#
# Schema: title,author,genre,status,rating,year,link

DIR="$(cd "$(dirname "$0")" && pwd)"
DB="${BOOKS_CSV:-$DIR/books.csv}"
INTERESTS="${INTERESTS_FILE:-$DIR/interests.txt}"
HEADER="title,author,genre,status,rating,year,link"

[ -f "$DB" ] || echo "$HEADER" > "$DB"
[ -f "$INTERESTS" ] || : > "$INTERESTS"

# Commas would break the CSV, so replace them; trim surrounding spaces.
clean() { printf '%s' "$1" | tr ',\r\n' ';  ' | sed 's/^ *//; s/ *$//'; }

valid_status() {
  case "$1" in want-to-read|reading|finished|owned) return 0 ;; esac
  echo "invalid status: $1" >&2; return 1
}
valid_rating() {
  case "$1" in ""|1|2|3|4|5) return 0 ;; esac
  echo "invalid rating: $1" >&2; return 1
}

# Rows matching a title exactly (case-insensitive).
rows_for_title() {
  awk -F, -v t="$1" 'NR > 1 && tolower($1) == tolower(t)' "$DB"
}

# Rewrite one column of one book. Args: title column value
set_field() {
  local tmp; tmp="$(mktemp)"
  if awk -F, -v OFS=, -v t="$1" -v c="$2" -v v="$3" '
       NR > 1 && tolower($1) == tolower(t) { $c = v; hit = 1 }
       { print }
       END { exit !hit }' "$DB" > "$tmp"; then
    cat "$tmp" > "$DB"; rm -f "$tmp"
  else
    rm -f "$tmp"; echo "not found: $1" >&2; return 1
  fi
}

cmd="${1:-}"; shift || true
case "$cmd" in
  list)    tail -n +2 "$DB" | grep -v '^[[:space:]]*$' ;;
  search)  tail -n +2 "$DB" | grep -i -F -- "${1:?search term required}" ;;
  get)     rows_for_title "$(clean "${1:?title required}")" | head -n 1 ;;
  exists)  [ -n "$(rows_for_title "$(clean "${1:?title required}")")" ] ;;
  titles)  tail -n +2 "$DB" | cut -d, -f1 | grep -v '^[[:space:]]*$' ;;
  add)
    title="$(clean "${1:?title required}")"
    if [ -n "$(rows_for_title "$title")" ]; then
      echo "already in library: $title" >&2; exit 1
    fi
    status="$(clean "${4:-want-to-read}")"; rating="$(clean "${5:-}")"
    valid_status "$status" && valid_rating "$rating" || exit 1
    echo "$title,$(clean "${2:-Unknown}"),$(clean "${3:-Unknown}"),$status,$rating,$(clean "${6:-}"),$(clean "${7:-}")" >> "$DB"
    ;;
  update-status) valid_status "${2:-}" && set_field "$(clean "$1")" 4 "$2" ;;
  update-rating) valid_rating "${2:-}" && set_field "$(clean "$1")" 5 "${2:-}" ;;
  interests)     grep -v '^[[:space:]]*#' "$INTERESTS" | grep -v '^[[:space:]]*$' ;;
  set-interests) tmp="$(mktemp)"; cat > "$tmp"; cat "$tmp" > "$INTERESTS"; rm -f "$tmp" ;;
  *) sed -n '5,17p' "$0" >&2; exit 2 ;;
esac
