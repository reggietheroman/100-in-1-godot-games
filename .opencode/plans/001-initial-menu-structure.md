# Initial Menu Structure

## Goal

Create a 2D main menu with 4 mini-game options, each with a title screen and placeholder game scene.

## Scene layout

### Main menu (`scenes/menu/menu.tscn`)
- `Control` root (full rect)
- `ColorRect` background (dark)
- `VBoxContainer` centered
  - Title label: "Clanker Slop 100 in 1"
  - 4 buttons: Zombie Math, Sands of Hanoi, Snow Survival, Pin Puzzles

### Each mini-game (`scenes/games/<game>/`)
- `title.tscn/gd` — `Control` root, game name label, "Start Game" and "Back to Menu" buttons
- `game.tscn/gd` — `Node2D` root, "Under Construction" placeholder, "Back to Menu" button

## Navigation flow

```
Main Menu → Game Title → Game Placeholder
                ↓
         Back to Menu
```

All transitions use `get_tree().change_scene_to_file()`.

## Future considerations

- Game scenes use `Node2D` root — easy to swap to `Node3D` per-game if needed
- `SubViewport` can embed 3D content in 2D menus later
