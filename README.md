# Tong's Book Manager (MIT 1.125 — Problem Set #2)

A small personal book manager for the terminal, built from small Bash programs and [Gum](https://github.com/charmbracelet/gum). It keeps track of my sci-fi and systems/engineering reading. Three recommendation agents run in parallel, and their combined output is piped into a refiner that builds a shortlist.

**Demo video:** [video_tiny.mp4](video_tiny.mp4)

## How to run

```bash
brew install gum          # required; curl + jq (both preinstalled on macOS) enable live metadata lookups
./app.sh
```

Every component can also be run on its own:

```bash
./data/book_database.sh list
echo "engineering" | ./books/search_books.sh
echo "Piranesi | Susanna Clarke" | ./books/fetch_book_metadata.sh
cat <(./recommendations/recommend_from_history.sh) <(./recommendations/recommend_for_discovery.sh) \
  | ./recommendations/refine_recommendations.sh 5
```

## Architecture

```text
app.sh → ui/main_menu.sh → workflows/ → books/ + recommendations/ → data/book_database.sh → data/books.csv
```

`app.sh` only checks for Gum and starts `ui/main_menu.sh`. The menu turns a Gum selection into a call to one of two workflows. `workflows/manage_library.sh` sets the order of library operations, for example *prompt → `fetch_book_metadata.sh` → `book_database.sh add`* or *prompt `| search_books.sh |` `library_screen.sh table`*. `workflows/get_recommendations.sh` starts the three agents in the background with `&` and saves each PID with `$!`. While they run, it polls them with `kill -0` and redraws a single status line (`running` / `done` plus an elapsed timer). It then calls `wait` on each PID, joins their outputs with `cat … | refine_recommendations.sh`, and passes the shortlist to `ui/recommendations_screen.sh`. If I pick a book, that pick goes back through `manage_library.sh save-rec` into the database.

Each layer talks to the next through plain text on stdin/stdout:

- library rows are CSV
- metadata is `Title | Author | Genre | Year | Link`
- recommendation candidates are `title|author|genre|score|agent|reason`

`data/book_database.sh` is the only file that opens `books.csv` or `interests.txt`. The UI scripts only display things and collect input.

## What I personalized

- **The agents reflect how I read.** The history agent favors authors I've already liked (+3) and genres I rate highly. The interests agent matches my editable profile (`hard-sf`, `first-contact`, `ai`, `systems`, `unix`, …) against catalog tags. The discovery agent is there to get me out of my sci-fi/engineering bubble: it only suggests genres that appear nowhere in my library, and it picks a different random book each run.
- **The refiner encodes my rules for a good shortlist:**
  - when agents agree, their scores add up, so consensus picks rank first
  - at most one book per author
  - one slot is always kept for a **wildcard** from the discovery agent
- **Extra features I wanted:** reading stats (counts by status, average rating, favorite genre), an in-app **Edit Interests** editor (`gum write`) that immediately changes what the interests agent recommends, and an **Update Book** flow for moving a book from want-to-read → reading → finished with a rating.
- **Metadata:** the curated local catalog is checked first, so lookups work offline. If the book isn't there, the app falls back to the Open Library API.

## Files

| File | Input → Output |
|---|---|
| `app.sh` | — → starts the menu |
| `ui/main_menu.sh` | Gum choice → workflow call |
| `ui/library_screen.sh` | CSV rows → tables, detail cards, stats; Gum prompts → values |
| `ui/recommendations_screen.sh` | agent states → live status line; shortlist → chosen book |
| `workflows/manage_library.sh` | browse / add / search / update / stats / interests / save-rec |
| `workflows/get_recommendations.sh` | runs agents with `&` + `$!` + `wait`, then a pipe into refine |
| `books/fetch_book_metadata.sh` | `Title \| Author` → `Title \| Author \| Genre \| Year \| Link` |
| `books/search_books.sh` | term (argument or stdin) → matching CSV rows |
| `recommendations/recommend_*.sh` | library/interests + `catalog.txt` → scored candidates |
| `recommendations/refine_recommendations.sh` | candidates on stdin → top-N shortlist on stdout |
| `recommendations/catalog.txt` | the candidate pool the agents draw from |
| `data/book_database.sh` | `list, search, get, exists, titles, add, update-status, update-rating, interests, set-interests` |
| `data/books.csv` | `title,author,genre,status,rating,year,link` |
| `data/interests.txt` | my interests, one per line |

The agents `sleep` for 1–3 seconds (configurable with `AGENT_DELAY`) to stand in for slow work such as an API or LLM call, so the parallel progress display is visible. Set `AGENT_DELAY=0` for instant runs.
