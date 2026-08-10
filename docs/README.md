# Docs

This project is a learning tool as much as a game collection. These docs explain
**why things are the way they are** and **how to configure things by hand**, so
you can look things up instead of re-deriving them.

## How to use this directory

| File | What it answers |
| --- | --- |
| `architecture.md` | Why the code is structured this way — GDScript OO, data-driven types, composition vs inheritance, duck typing. |
| `manual-configuration.md` | Every exported var and signal per system, with what each one does and how to tune it by hand. |
| `design-decisions.md` | A running log of decisions, newest first, with the reasoning behind each one. |

## Conventions for this project

- Whenever a design decision is made, **append it to `design-decisions.md`**.
- Whenever a system's exported vars / signals / behavior change, **keep
  `manual-configuration.md` in sync**.
- `architecture.md` is the "why" document; update it when the philosophy
  changes, not on every tweak.

## Layout cheat-sheet

```
scenes/
├── menu/          — main menu + sandbox list
├── sandbox/       — dev sandboxes exercising isometric_kit systems
└── games/         — the mini-games (sands_of_hanoi is the reference implementation)
addons/isometric_kit/   — reusable 3D systems (see architecture.md)
.opencode/plans/   — stored plans and proposals
docs/              — you are here
```
