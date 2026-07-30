# Clanker Slop 100 in 1

Godot 4.7 project — collection of 4 mini-games.

## Project structure

```
scenes/
├── menu/          — main menu
└── games/
    ├── zombie_math/
    ├── sands_of_hanoi/
    ├── snow_survival/
    └── pin_puzzles/
.opencode/plans/   — stored plans and proposals
```

Each mini-game has a `title.tscn/gd` (title screen with Start/Back buttons) and a `game.tscn/gd` (actual game, currently placeholder).

## Architecture

- **Scene navigation**: `get_tree().change_scene_to_file()` between .tscn files
- **Menus**: `Control`-rooted scenes with `VBoxContainer` layout + dark `ColorRect` background
- **Game scenes**: `Node2D` root (swap to `Node3D` per-game as needed)
- **Signal connections**: wired in `_ready()` via `.pressed.connect()`

## Conventions

- snake_case for files and directories
- PascalCase for node names
- One scene + one script per screen
- Extend from root node type (Control for UI, Node2D/Node3D for game)

## Settings

- Window stretch: canvas_items (expand)
- Renderer: gl_compatibility
- Physics: Jolt Physics 3D

## Commands

- The `.godot` directory is excluded from version control.
