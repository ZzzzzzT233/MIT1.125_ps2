#!/usr/bin/env bash
# Book component: search the user's library.
#
# In : a search term, as an argument or on stdin
# Out: matching books as CSV rows (title,author,genre,status,rating,year,link)
#   ./books/search_books.sh "history"
#   echo "history" | ./books/search_books.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

term="$*"
if [ -z "$term" ] && [ ! -t 0 ]; then IFS= read -r term; fi
[ -z "$term" ] && { echo "usage: search_books.sh <term>" >&2; exit 1; }

# Delegate storage access to the data layer; matches title, author, genre or status.
"$ROOT/data/book_database.sh" search "$term"
