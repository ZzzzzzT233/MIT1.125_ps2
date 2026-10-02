#!/usr/bin/env bash
# Recommendation component: turn raw candidates into a clean shortlist.
#
# In  (stdin):  title|author|genre|score|agent|reason      (from any agents)
# Out (stdout): score|title|author|genre|agents|reason     (best first)
#
# Steps (each one a stage of the pipeline below):
#   1. drop books already in my library
#   2. merge duplicates: scores add up, so books several agents agree on rise
#   3. rank by total score
#   4. keep the top N (default 5), at most one book per author, and always
#      reserve one slot for a discovery "wildcard" so the list never becomes
#      100% comfort reading
#   cat candidates.txt | ./recommendations/refine_recommendations.sh 5

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
N="${1:-5}"

{
  "$ROOT/data/book_database.sh" titles
  echo "__END__"
  cat                                   # the candidates arriving on stdin
} | awk -F'|' '
  phase == 0 { if ($0 == "__END__") phase = 1; else owned[tolower($0)] = 1; next }
  NF < 6 { next }
  {
    k = tolower($1)
    if (k in owned) next                                  # 1. already in library
    if (!(k in score)) { order[++n] = k; T[k] = $1; A[k] = $2; G[k] = $3; R[k] = $6 }
    score[k] += $4                                        # 2. merge duplicates
    if (index("," agents[k] ",", "," $5 ",") == 0) agents[k] = (agents[k] ? agents[k] "+" : "") $5
  }
  END { for (i = 1; i <= n; i++) { k = order[i]; print score[k] "|" T[k] "|" A[k] "|" G[k] "|" agents[k] "|" R[k] } }
' | sort -t'|' -k1,1nr -k2,2 | awk -F'|' -v n="$N" '   # 3. rank
  { rows[NR] = $0; author[NR] = $3; if (!wild && $5 ~ /discovery/) wild = NR }
  END {                                    # 4. top N, one book per author, + wildcard slot
    for (i = 1; i <= NR && picked < n - 1; i++) {
      if (author[i] in used) continue
      used[author[i]] = 1; print rows[i]; picked++
      if (i == wild) have = 1
    }
    if (wild && !have) { print rows[wild]; exit }
    for (; i <= NR; i++) if (!(author[i] in used)) { print rows[i]; exit }
  }'
