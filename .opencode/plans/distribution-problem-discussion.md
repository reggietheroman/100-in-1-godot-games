# Sands of Hanoi — Distribution Problem Discussion

## The Question
The user had played 10 games of Sands of Hanoi and lost all 10. They asked:
"Are you able to do a test run of the game based on this distribution and see if
you win? I do not require you to interact with the UI. Try to play 3 games and
let me know if you win any."

They suspected the color-distribution system (generation) was the root cause
of unwinnable boards, rather than their play.

## What the Distribution Is
Config (see `scenes/games/sands_of_hanoi/game.gd`):
- 7 colors (red, blue, green, yellow, orange, purple, pink), cyan unused
- 8 bottles, capacity 4 each; bottle index 7 is an empty workspace
- 7 filled bottles, each starting with 4 **all-different** colors, laid out per
  the complement of the Fano plane (a balanced incomplete block design):
  - every color appears exactly 4 times
  - every pair of colors shares exactly 2 bottles
- Each game shuffles: color-index mapping, which block lands in which bottle,
  and the vertical layer order within each bottle. The block structure is fixed.

Game rules relevant to solvability:
- Pour only onto a matching top color or into an empty bottle
- Pours move all consecutive top layers of one color in a single action
- A bottle with 4 layers of a single color is **sealed** (locked forever)
- Win = all 7 filled bottles are sealed

## Methodology
Wrote a standalone Python BFS solver that replicates the game rules exactly:
- Same pour rule (matching top or empty, whole top run, capped by dst space)
- Same sealing semantics (full + one color → frozen, can't pour from/into)
- Win condition = bottles 0–6 each sealed
- Validated the solver on a known-solvable toy puzzle (2 colors, 3 moves) to
  confirm it could find solutions when they exist

Because the solver does a breadth-first search over the **entire reachable
state space** (not a depth-limited simulation), a failure means the goal is
provably unreachable — not just "the solver was unlucky."

## Findings
- The 3 requested games: **all unsolvable** (BFS exhausted every reachable state)
- A 20-game scan with the same method: **0/20 solvable** under real game rules
- A relaxed variant (seal-lock removed): only **1/20** solvable
- Reachable state spaces were tiny (27–158 states), indicating the boards are
  nearly frozen rather than merely hard

### Root Cause
1. **All 7 bottles start completely full with 4 different colors.**
   Every pour transfers only a single layer (there are no same-color runs to
   stack), and there is just one workspace bottle. The combination of
   "everything full + all-distinct bottles + one empty bottle" has a
   parity-type invariant that prevents sorting — this is the primary reason
   boards are unwinnable.

2. **The seal rule makes it worse.**
   In 1 of the 20 scanned boards the goal *was* reachable, but only by
   temporarily breaking up a sealed (full + single-color) bottle. The real
   game forbids this, so that board became unwinnable too.

## Conclusion
It is not the player's fault — the current distribution is nearly always
unwinnable. Proposed directions for a fix (not yet implemented):
- Start bottles with headroom (not full), so runs can be poured
- Or start with fewer colors per bottle (e.g. classic 2-color bottles), a
  configuration known to be solvable
- Possibly relax the seal rule so completed bottles can be temporarily broken

## Files / Artifacts
- Game code being analyzed: `scenes/games/sands_of_hanoi/game.gd`
- Solver script (temp): `hanoi_solver.py`, `hanoi_scan.py`
  (written under `/var/folders/.../T/opencode`, not part of the repo)
