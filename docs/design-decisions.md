# Design decisions log

Running log of design decisions, newest first. Whenever a decision is made,
append an entry here with the reasoning, so the "why" is never lost.

---

## 2026-08-10 — Loot items are scene variants of a shared script, not subclasses

**Decision:** `loot_coin.tscn` is a separate scene that attaches `loot_item.gd`
with different defaults (coin mesh, name "Coin") rather than inheriting
`loot_item.tscn` or creating a `CoinLootItem` subclass.

**Why:** Behavior is identical; only the visual mesh and data (name, color)
differ. Sharing the script is the "has-a" reuse path — one behavior, many
configurations. This follows the data-driven type pattern in
`docs/architecture.md`. Could later use Godot scene inheritance (`inherit`
field) if the variant set grows.

## 2026-08-10 — Combined sandbox currency loop starts at 0, enemies drop coins

**Decision:** `combined_sandbox` starts the wallet at 0 and enemies drop
`loot_coin.tscn` on death; picking a coin up credits the wallet via
`add_currency(item.value)`. The separate "Coins collected" HUD counter was
removed — the currency label is the single counter.

**Why:** Starting at 0 makes the economy meaningful — you must kill enemies,
collect coins, and spend on the four build pads, closing the full loop. Two
counters for the same flow (coins collected vs currency balance) was redundant
and confusing; the wallet balance is the single source of truth.

## 2026-08-10 — Combined sandbox: trigger zones replaced with 4 Rapid tower build pads

**Decision:** Removed the `Zones` node (3 `trigger_area` zones) from
`combined_sandbox` and replaced it with four `build_site` pads, one per map
corner at (±3, 0, ±3), each building a functional Rapid tower (stages
`[15, 30, 50]`, `fire_interval 0.3→0.18`, `range 4.5→6.5`, `damage 1→3`).

**Why:** The combined sandbox is the "everything together" demo; trigger zones
added nothing once the individual `trigger_sandbox` exists. Build pads exercise
the currency loop (wallet → deposit → build → celebration) alongside shooting
and waves, making the sandbox a full tower-defense micro-loop. Structure
offsets point towers toward the center so they cover the spawn→rally diagonal
the enemies walk.

## 2026-08-10 — Project also a learning tool; add docs directory

**Decision:** Created `docs/` (architecture, manual configuration reference,
design-decisions log) and made recording design decisions + keeping the
configuration reference in sync a standing convention (see `AGENTS.md`).

**Why:** The goal is that "why is it like this?" and "how do I configure X by
hand?" questions are answerable from the docs instead of re-derived from code.
