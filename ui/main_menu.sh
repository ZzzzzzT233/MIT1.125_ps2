#!/usr/bin/env bash
# UI layer: main application menu.
# Uses Gum to pick an action, then hands off to the workflow layer.
# Interaction only - all real work lives in workflows/.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB="$ROOT/workflows/manage_library.sh"
REC="$ROOT/workflows/get_recommendations.sh"

"$ROOT/ui/library_screen.sh" banner "Tong's Book Manager" "sci-fi  x  systems  x  the occasional wildcard"

while true; do
  echo
  choice="$(gum choose --header "What would you like to do?" --cursor "> " \
    "Browse Library" "Add Book" "Search Library" "Update Book" \
    "Get Recommendations" "Reading Stats" "Edit Interests" "Quit")" || choice="Quit"

  case "$choice" in
    "Browse Library")      "$LIB" browse ;;
    "Add Book")            "$LIB" add ;;
    "Search Library")      "$LIB" search ;;
    "Update Book")         "$LIB" update ;;
    "Get Recommendations") "$REC" ;;
    "Reading Stats")       "$LIB" stats ;;
    "Edit Interests")      "$LIB" interests ;;
    "Quit")                gum style --foreground 212 "Happy reading!"; exit 0 ;;
  esac
done
