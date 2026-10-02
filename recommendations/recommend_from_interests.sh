#!/usr/bin/env bash
# Recommendation agent #2 — "What I say I care about."
# Matches my interests profile (data/interests.txt, via the data layer)
# against catalog tags and genres:
#   +2  per matching tag      +1  if the genre itself is an interest
# Out (stdout): title|author|genre|score|agent|reason   one candidate per line

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CATALOG="$ROOT/recommendations/catalog.txt"

sleep "${AGENT_DELAY:-3}"   # stand-in for a slow agent so progress is visible

{
  "$ROOT/data/book_database.sh" interests
  echo "__END__"
} | awk -F'|' '
  phase == 0 {
    if ($0 == "__END__") { phase = 1; next }
    gsub(/^[ \t]+|[ \t]+$/, ""); want[tolower($0)] = 1
    next
  }
  /^#/ || NF < 5 { next }
  {
    score = 0; hits = ""
    n = split(tolower($5), tags, " ")
    for (i = 1; i <= n; i++)
      if (tags[i] in want) { score += 2; hits = hits (hits ? ", " : "") tags[i] }
    if (tolower($3) in want) { score += 1; hits = hits (hits ? ", " : "") tolower($3) }
    if (score > 0) print $1 "|" $2 "|" $3 "|" score "|interests|matches your interests: " hits
  }' - "$CATALOG"
