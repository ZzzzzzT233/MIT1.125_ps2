#!/usr/bin/env bash
# Recommendation agent #3 — "Get out of the sci-fi bubble."
# Finds genres that do NOT appear anywhere in my library and picks one
# random book from each. Exploration, not similarity: a different run
# gives different wildcards (set DISCOVERY_SEED for repeatable output).
# Out (stdout): title|author|genre|score|agent|reason   one candidate per line

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CATALOG="$ROOT/recommendations/catalog.txt"
SEED="${DISCOVERY_SEED:-$RANDOM}"

sleep "${AGENT_DELAY:-1}"   # stand-in for a slow agent so progress is visible

{
  "$ROOT/data/book_database.sh" list | cut -d, -f3
  echo "__END__"
} | awk -F'|' -v seed="$SEED" '
  phase == 0 {
    if ($0 == "__END__") { phase = 1; next }
    seen[tolower($0)] = 1
    next
  }
  /^#/ || NF < 3 { next }
  !(tolower($3) in seen) {
    if (!($3 in count)) genres[++g] = $3
    pool[$3, ++count[$3]] = $0
  }
  END {
    srand(seed)
    for (i = 1; i <= g; i++) {
      split(pool[genres[i], int(rand() * count[genres[i]]) + 1], b, "|")
      print b[1] "|" b[2] "|" b[3] "|2|discovery|wildcard: you have never read any " b[3]
    }
  }' - "$CATALOG"
