# Game Designs

## Cross-cutting
- Desktop + mobile browser
- Portrait orientation on mobile

## Zombie Math
- **POV**: Top-down
- **Controls**: Move left/right between 3 lanes
- **Shooting**: Continuous auto-fire, bullet goes straight up current lane only
- **Enemies**: Zombies spawn at top, walk downward — stop at bottom and attack until one side dies
- **Glass panes**: Walk-through obstacle, occupies full lane. Has math op (×N, +N, −N) applied to soldier count. Panes are bad (subtract) or good (multiply/add), but can't be dodged if you're in that lane.
- **Movement**: Soldiers advance upward (running toward the zombie horde). Screen scrolls vertically.
- **Distribution**: Squad spans all 3 lanes, weighted toward the selected lane. More soldiers = wider spread across lanes.
- **Overflow**: Higher soldier counts force soldiers into non-chosen lanes, making glass panes unavoidable.
- **Lose**: Soldiers reach 0
- **Progression**: Zombies get faster over time, user periodically gains more soldiers

## Sands of Hanoi
- **POV**: Flat 2D
- **Concept**: Towers of Hanoi variation — sorting colored sand layers into pure-color bottles
- **Layout**: 8 bottles (4 layers each) in a 4×2 grid
- **Workspace**: 1 empty bottle (index 7, white outline) acts as workspace/temporary storage
- **Pouring rule**: Can only pour onto sand of the same color (or into an empty bottle). You pour all consecutive top layers of the same color in one action.
- **Sealing**: A bottle with 4 layers of a single color is sealed (locked, no longer usable)
- **Goal**: Each of the 7 filled bottles contains 4 layers of only 1 color
- **Interaction**: Click/tap a bottle to select it (yellow highlight), then click/tap another to pour
- **Initial state**: Complement-of-Fano BIBD — 7 colors × 4 layers each, distributed across 7 bottles so each color pair shares exactly 2 bottles. Guarantees solvability with the workspace bottle.
- **Generation**: Color indices shuffled, bottle order shuffled, layers shuffled per bottle

### Implementation

**Files**: `scenes/games/sands_of_hanoi/game.gd`, `game.tscn`

**Architecture**:
- `Bottle` class: holds `layers` array (strings), `max_layers`, `rect` (position/size on screen), `sealed` flag
- Game root: `Node2D` with custom `_draw()` for rendering
- UI: `CanvasLayer` with Back button, Move counter, instruction label, win label
- Input: `_unhandled_input()` handles both mouse and touch events

**Rendering**:
- Dark background, beige bottle bodies, dark inner well
- Colored rectangles for sand layers (drawn bottom-to-top)
- Green tint overlay on sealed bottles
- Yellow highlight border on selected bottle
- White outline on workspace bottle

**Layout** (portrait-first):
- 4 columns × 2 rows, centered; dimensions auto-fit viewport with `_layout()` in `_ready()`

## Snow Survival
- **Reference**: Clone of Pizza Ready
- **POV**: Isometric
- **Description**: TBD

## Pin Puzzles
- **POV**: Flat 2D
- **Description**: TBD

## Throne Defender
- **Reference**: Clone of [Thronefall](https://store.steampowered.com/app/2239150/Thronefall/)
- **POV**: Top-down/isometric castle defense
- **Description**: TBD
