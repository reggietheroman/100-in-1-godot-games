# Design decisions log

Running log of design decisions, newest first. Whenever a decision is made,
append an entry here with the reasoning, so the "why" is never lost.

---

## 2026-08-12 — Nav enemies don't collide with each other (collision layer 2)

**Decision:** `enemy_nav.tscn` puts its `CharacterBody3D` on collision layer 2
with mask 1 — it still collides with the world (floor/walls/player on layer 1)
but walks through other enemies. `projectile.tscn` uses mask 3 so projectiles
still detect layer-2 enemies. The classic `enemy_mover` stays on layer 1.

**Why:** Pathfinding enemies that collide pile up on the final path segment: the
leader reaches the rally and stops, the next enemy gets blocked just short of the
target, and `is_navigation_finished()` (which requires the whole path including
the final target to be traversed) never returns true — the trailing enemy is
stuck forever, `all_enemies_reached_rally` never fires. The classic mover's
straight-line distance check doesn't have this problem because it only needs to
get within `stop_distance` of the target, so a pile still "reaches". Keeping the
layer split on the nav variant (rather than both) is the minimal change, and the
projectile mask covers both layers so nav enemies stay a drop-in for towers and
shooters.

## 2026-08-12 — Nav agent path progression is manual and index-persistent

**Decision:** `enemy_nav_mover._next_waypoint()` reads `get_current_navigation_path()`
and walks its own `_waypoint_index` forward, skipping waypoints within 0.3 of the
enemy. It does not trust `get_next_path_position()` alone.

**Why:** A navmesh path always starts at the projected start point, which can
coincide exactly with the enemy's spawn (XZ-wise). `get_next_path_position()`
returns that coincident point and the agent only advances past a waypoint when
strictly beyond it, so a mover that stops on a tiny `flat` distance deadlocks at
spawn. A distance-only scan for "the next waypoint" fixes that but then picks up
waypoints the enemy has overshot (they're behind yet still far), oscillating
forever. The index never moves backwards, so once a waypoint is passed it is
never retargeted — and the whole approach no longer depends on the agent's
internal advancement edge cases.

## 2026-08-12 — Navmesh bakes from static colliders at a 0.1-cell map/mesh match

**Decision:** `NavmeshBaker` sets `geometry_parsed_geometry_type =
PARSED_GEOMETRY_STATIC_COLLIDERS` and bakes at `cell_size = 0.1`, matching
`navigation/3d/default_cell_size` and `default_cell_height = 0.1` in
`project.godot`. Radius/height/climb constants are voxel multiples of 0.1.

**Why (three parts):**
1. Parsing visual meshes at runtime forces the renderer to read geometry back
   from the GPU (`RenderingServer`), which Godot warns is a significant perf
   cost — the grid already has collision shapes, so parse those instead.
2. With the default map cell size (0.25) a mesh baked at 0.1 warns, and calling
   `map_set_cell_size()` at runtime AFTER a region registers stales the map and
   empties every path query (same family of sync quirk as the async-iterations
   issue). Configuring the default map cell size in `project.godot` fixes it
   before anything registers.
3. A 0.25 cell ceils `agent_radius` 0.35 → 0.5, so the sandbox's exported radius
   knob didn't do what it said. 0.1 keeps values within a voxel of what you ask
   for. Maps are small (single-digit-to-forty tiles), so the finer bake is free.

## 2026-08-12 — Pathfinding sandbox snaps default spawn/rally to tile centers

**Decision:** `pathfinding_sandbox._ready()` snaps the exported default
`spawn_point`/`rally_point` through `_snap_to_tile()` (click-placed points
already snapped) before assigning them to the spawner.

**Why:** The sandbox's map size is computed from the camera footprint, not a
fixed 12x12 grid — so dev-authored coordinates written for a 12-wide grid (e.g.
`(4.5, 0.6, -4.5)`) land on a tile *corner* of the actual ~39x39 map. The
navmesh erodes `agent_radius` from walls, which removes tile corners, so a nav
agent can never get within its finish distance of the exact target and pushes
against the navmesh edge forever. Tile centers are always walkable.

## 2026-08-11 — Navigation uses synchronous region/map iteration builds

**Decision:** In `project.godot` set `navigation/world/map_use_async_iterations=false`
and `navigation/world/region_use_async_iterations=false` (alongside the existing
`navigation/3d/use_threads=false`).

**Why:** Region and map navmesh "iterations" build on background
`WorkerThreadPool` threads by default. In headless `--script` runs the async
builds never surface to the region/map sync, so `NavigationServer3D.query_path()`
returns empty paths indefinitely. With synchronous builds, a baked navmesh is
queryable on the very next physics frame — which makes headless tests (the
`addons/isometric_kit` suite) deterministic. Our maps are small (single digit
tiles), so the per-frame sync rebuild cost is negligible, and determinism is
more valuable than offloading a near-instant job to a thread.

Also learned: `parse_source_geometry_data()` silently no-ops if the root node is
not inside the scene tree, so a grid must be added to the tree before baking.

## 2026-08-10 — Loot items are scene variants of a shared script, not subclasses

**Decision:** `loot_coin.tscn` is a separate scene that attaches `loot_item.gd`
with different defaults (coin mesh, name "Coin") rather than inheriting
`loot_item.tscn` or creating a `CoinLootItem` subclass.

**Why:** Behavior is identical; only the visual mesh and data (name, color)
differ. Sharing the script is the "has-a" reuse path — one behavior, many
configurations. This follows the data-driven type pattern in
`docs/architecture.md`. Could later use Godot scene inheritance (`inherit`
field) if the variant set grows.

## 2026-08-10 — Tower Defense sandbox currency loop starts at 0, enemies drop coins

**Decision:** `tower_defense` starts the wallet at 0 and enemies drop
`loot_coin.tscn` on death; picking a coin up credits the wallet via
`add_currency(item.value)`. The separate "Coins collected" HUD counter was
removed — the currency label is the single counter.

**Why:** Starting at 0 makes the economy meaningful — you must kill enemies,
collect coins, and spend on the four build pads, closing the full loop. Two
counters for the same flow (coins collected vs currency balance) was redundant
and confusing; the wallet balance is the single source of truth.

## 2026-08-10 — Tower Defense sandbox: trigger zones replaced with 4 Rapid tower build pads

**Decision:** Removed the `Zones` node (3 `trigger_area` zones) from
`tower_defense` and replaced it with four `build_site` pads, one per map
corner at (±3, 0, ±3), each building a functional Rapid tower (stages
`[15, 30, 50]`, `fire_interval 0.3→0.18`, `range 4.5→6.5`, `damage 1→3`).

**Why:** The tower defense sandbox is the "everything together" demo; trigger zones
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
