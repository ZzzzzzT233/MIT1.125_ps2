#!/usr/bin/env bash
# Workflow layer: coordinate the recommendation agents.
#
#                     +-> history agent   --+
#   library+interests +-> interests agent --+-> combine | refine -> UI -> save
#                     +-> discovery agent --+
#
# Demonstrates: parallelism (&, $!), streaming progress (kill -0 polling),
# synchronisation (wait), and pipes (cat ... | refine).

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UI="$ROOT/ui/recommendations_screen.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

names=(history interests discovery)
scripts=(recommend_from_history recommend_from_interests recommend_for_discovery)
pids=()

"$UI" banner

# 1. Start all three agents in the background; remember each PID with $!
for i in 0 1 2; do
  "$ROOT/recommendations/${scripts[$i]}.sh" > "$TMP/${names[$i]}.txt" &
  pids[$i]=$!
done

# 2. Stream progress while any agent is still alive
start="$(date +%s)"; tick=0
while :; do
  states=(); running=0
  for i in 0 1 2; do
    if kill -0 "${pids[$i]}" 2>/dev/null; then states+=("${names[$i]}=running"); running=$((running + 1))
    else states+=("${names[$i]}=done"); fi
  done
  "$UI" progress "$tick" "$(( $(date +%s) - start ))" "${states[@]}"
  [ "$running" -eq 0 ] && break
  tick=$((tick + 1)); sleep 0.2
done
echo

# 3. Synchronise: wait for each PID and collect its exit status
for i in 0 1 2; do
  wait "${pids[$i]}"; code=$?
  "$UI" agent_done "${names[$i]}" "$code" "$(grep -c . "$TMP/${names[$i]}.txt")"
done

# 4 + 5. Combine every agent's output and pipe it into the refiner
cat "$TMP"/history.txt "$TMP"/interests.txt "$TMP"/discovery.txt \
  | "$ROOT/recommendations/refine_recommendations.sh" 5 > "$TMP/shortlist.txt"

# 6. Show the shortlist; if I pick one, hand it to the library workflow
if pick="$("$UI" shortlist < "$TMP/shortlist.txt")"; then
  "$ROOT/workflows/manage_library.sh" save-rec "$pick"
fi
