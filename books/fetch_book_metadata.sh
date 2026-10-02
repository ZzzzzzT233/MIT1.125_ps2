#!/usr/bin/env bash
# Book component: enrich basic book information with metadata.
#
# In : "Title | Author"                        (argument, or one line on stdin)
# Out: "Title | Author | Genre | Year | Link"  (always 5 fields)
#
# Lookup order: 1) local catalog (fast, offline)
#               2) Open Library search API (needs curl + jq + network)
#               3) give up gracefully: Genre=Unknown, Year=?
#   echo "Dune | Frank Herbert" | ./books/fetch_book_metadata.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CATALOG="$ROOT/recommendations/catalog.txt"

trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

# Map a bag of Open Library subjects onto my own small set of genres.
guess_genre() {
  case "$1" in
    *"science fiction"*)                       echo "Science Fiction" ;;
    *fantasy*)                                 echo "Fantasy" ;;
    *computer*|*programming*|*software*|*engineering*) echo "Engineering" ;;
    *biography*)                               echo "Biography" ;;
    *poetry*)                                  echo "Poetry" ;;
    *mystery*|*detective*)                     echo "Mystery" ;;
    *philosophy*)                              echo "Philosophy" ;;
    *psychology*)                              echo "Psychology" ;;
    *history*)                                 echo "History" ;;
    *science*)                                 echo "Science" ;;
    *fiction*)                                 echo "Literary Fiction" ;;
    *)                                         echo "Unknown" ;;
  esac
}

input="$*"
[ -z "$input" ] && IFS= read -r input
title="$(trim "${input%%|*}")"
author=""; case "$input" in *"|"*) author="$(trim "${input#*|}")" ;; esac
[ -z "$title" ] && { echo "usage: fetch_book_metadata.sh \"Title | Author\"" >&2; exit 1; }

genre=""; year=""
query="$(printf '%s %s' "$title" "$author" | sed 's/[^A-Za-z0-9]\{1,\}/+/g; s/^+//; s/+$//')"
link="https://openlibrary.org/search?q=$query"

# 1) Local catalog
hit="$(awk -F'|' -v t="$title" '!/^#/ && tolower($1) == tolower(t) { print; exit }' "$CATALOG")"
if [ -n "$hit" ]; then
  IFS='|' read -r _ c_author genre year _ <<< "$hit"
  [ -z "$author" ] && author="$c_author"

# 2) Open Library
elif command -v curl >/dev/null && command -v jq >/dev/null; then
  json="$(curl -sG -m 6 "https://openlibrary.org/search.json" \
            --data-urlencode "title=$title" --data-urlencode "author=$author" \
            -d limit=1 -d fields=key,author_name,first_publish_year,subject 2>/dev/null)"
  if [ -n "$json" ] && jq -e '.docs[0]' >/dev/null 2>&1 <<< "$json"; then
    year="$(jq -r '.docs[0].first_publish_year // empty' <<< "$json")"
    [ -z "$author" ] && author="$(jq -r '.docs[0].author_name[0] // empty' <<< "$json")"
    key="$(jq -r '.docs[0].key // empty' <<< "$json")"
    [ -n "$key" ] && link="https://openlibrary.org$key"
    subjects="$(jq -r '(.docs[0].subject // [])[:40] | join(" ")' <<< "$json" | tr '[:upper:]' '[:lower:]')"
    genre="$(guess_genre "$subjects")"
  fi
fi

echo "$title | ${author:-Unknown} | ${genre:-Unknown} | ${year:-?} | $link"
