# Architecture — why things are the way they are

This document answers "why is the code structured like this?". It is the *why*
document; for the *what* (exported vars, signals), see `manual-configuration.md`.

## Is GDScript object-oriented?

**Yes, with caveats.** Every script is a class: it `extends` something, and can
have member vars, methods, signals, inner classes, and static helpers. But
GDScript is *structural* in a way Java/C# are not — there is no strong nominal
typing between your own classes. You mostly interact through **duck typing**
(`node.has_method("take_damage")`, `body.is_in_group("enemy")`) rather than
`enemy is EnemyMover`. That single fact drives most of the design decisions
below.

## Why we don't build an inheritance tree of systems (towers, enemies, ...)

The classic OO reflex is to subclass: `RapidTower extends Tower`, `CannonTower
extends Tower`. We deliberately do not. The reasons:

1. **Behavior differences are numeric, not structural.** Rapid vs Cannon vs
   Sniper differ in `fire_interval`, `range`, `damage`, `splash_radius` — all
   numbers with identical code paths. You subclass when *methods* differ. Here
   the method (acquire target → aim → fire) is identical; only data changes.
   Three subclasses with identical methods is strictly worse than one class +
   three configs. This is the "favor composition over inheritance" / data-driven
   instinct.

2. **Godot already provides the base class.** Every system `extends` an engine
   node (`Node3D`, `Area3D`, `CharacterBody3D`, `Control`). The engine supplies
   the node lifecycle, transforms, tree traversal, and groups. Writing a
   `TowerBase` on top of `Node3D` re-implements what the engine already gives us.

3. **Duck-typed contracts make subclassing fragile.** The spawner says "give me
   a scene that walks to `target` and emits `reached_rally_point`" — it does not
   check `is EnemyMover`. A *different* enemy implementation plugs in with zero
   changes. Hard-wiring a base class would throw that away. Loose coupling buys
   flexibility at the cost of type safety; Godot's tooling nudges you toward the
   loose side.

4. **A `.tscn` scene is itself a named configuration.** In Godot, a scene *is* a
   "type": it bundles a script with specific meshes, node children, and exported
   var values. `tower.tscn`, `enemy.tscn`, `loot_item.tscn` are distinct classes
   that share behavior through their scripts. `loot_coin.tscn` attaches the same
   `loot_item.gd` with different defaults + a different mesh — that's **has-a**
   (same behavior, different data/visual), not **is-a**.

5. **Inheritance is still there — at the right boundary.** We extend engine
   classes (`Node3D`, `Area3D`, `CharacterBody3D`, `Control`, `Camera3D`) — the
   one hierarchy that pays off. Pure logic uses `RefCounted` + `class_name`
   (e.g. `VisibleFootprint`, `LootDrop`, Sands of Hanoi's `Bottle`) — OO data
   modeling without node overhead.

## The data-driven type pattern

The "type system" for towers/structures is:

1. **A script** that reads exported vars (`tower.gd`).
2. **A scene** that attaches the script + meshes (`tower.tscn`).
3. **A config array of dicts** in the sandbox listing each type's values
   (`tower_configs` in `tower_sandbox.gd`, `site_configs` in `build_sandbox.gd`).
4. **A copy loop** in `_ready()` that instantiates the scene and copies dict
   keys onto the instance's exported vars.

Per-level evolution is a second dimension: `level_stats` / `level_colors`
(arrays indexed by level) applied via `apply_level()`. `build_site` overrides
these with its own `tower_level_stats`.

The costs of this approach: config dicts are untyped (typos silently ignored,
no autocomplete), and each sandbox duplicates the instantiate→copy loop. The
benefits: one source of truth per system, trivial to add a new type (one dict
entry), and easy to swap scenes satisfying the same duck contract.

## Glue: groups + signals, not inheritance

Systems find each other through **groups** (`add_to_group("player")`,
`"enemy"`, `"wallet"`, `"deposit"`, `"tower"`, `"build_site"`, `"loot"`,
`"projectile"`, `"wall"`) and communicate through **signals** (`picked_up`,
`deposited_changed`, `leveled_up`, `died`, `damaged`, `hit`, `fired`,
`enemy_killed`, `reached_rally_point`, ...). This keeps every component
decoupled: a deposit pad just needs *a* wallet in the group; it never needs to
know who owns it.

## Why configs are dicts-in-arrays rather than Resources

Godot's more idiomatic "typed data" would be `class_name TowerType extends
Resource` + `.tres` files. We chose dicts because they are the lowest-friction
way to define types inline in code and stay editable as `@export` arrays in the
Inspector. This is a tooling upgrade candidate (resources add autocomplete and
typo checking) — it is **not** an inheritance change; resources are data, not
behavior.

## When to reach for a base class

- If several systems share real behavior AND data (not just a var name), e.g.
  the duplicated `_apply_color()` across player/enemy/tower — a shared base or a
  helper is a reasonable future change.
- If a system's methods genuinely diverge by type (different AI, different
  behavior), inheritance becomes worth it.

Rule of thumb used here: **subclass when methods differ; configure when only
numbers/colors differ.**
