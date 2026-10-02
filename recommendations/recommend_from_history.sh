#!/usr/bin/env bash
# Recommendation agent #1 — "More of what worked."
# Looks at books I finished or rated >= 4, then scores catalog books:
#   +3  same author as a book I liked
#   +1  per liked book in the same genre
# Out (stdout): title|author|genre|score|agent|reason   one candidate per line

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CATALOG="$ROOT/recommendations/catalog.txt"

sleep "${AGENT_DELAY:-2}"   # stand-in for a slow agent (e.g. an API/LLM call) so progress is visible

{
  # Liked books from the data layer, as title|author|genre
  "$ROOT/data/book_database.sh" list | awk -F, '$4 == "finished" || $5 >= 4 { print $1 "|" $2 "|" $3 }'
  echo "__END__"
} | awk -F'|' '
  phase == 0 {
    if ($0 == "__END__") { phase = 1; next }
    liked_genre[$3]++
    if (!($3 in example)) example[$3] = $1
    liked_author[tolower($2)] = $1
    next
  }
  /^#/ || NF < 3 { next }
  {
    score = 0; reason = ""
    if (tolower($2) in liked_author) { score += 3; reason = "more " $2 " (you liked " liked_author[tolower($2)] ")" }
    if ($3 in liked_genre) {
      score += liked_genre[$3]
      if (reason == "") reason = "you loved " example[$3] " - more " $3
    }
    if (score > 0) print $1 "|" $2 "|" $3 "|" score "|history|" reason
  }' - "$CATALOG"
