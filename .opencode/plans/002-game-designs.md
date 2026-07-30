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
- **Layout**: 9 bottles — 8 small (4 layers each), 1 big (8 layers)
- **Big bottle**: Starts empty in center (acts as workspace/temporary storage)
- **Pouring rule**: Can only pour onto sand of the same color (or into an empty bottle). You pour all consecutive top layers of the same color in one action.
- **Sealing**: A bottle with 4 layers of a single color is sealed (locked, no longer usable)
- **Goal**: Each of the 8 small bottles contains 4 layers of only 1 color
- **Interaction**: Click/tap a bottle to select it (yellow highlight), then click/tap another to pour
- **Initial state**: Paired reciprocal pattern — colors are paired, each pair has a reciprocal split (e.g., bottle A has 3A+1B, bottle B has 3B+1A). Capacity 4 per small bottle, 8 for big. Guarantees solvability.
- **Generation**: Colors shuffled and paired randomly, split size (1-4) randomized per pair

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

**Layout** (portrait-first):
- 4 columns × 2 rows of small bottles at top, big bottle centered below
- Dimensions auto-fit viewport with `_layout()` in `_ready()`

## Snow Survival
- **POV**: Isometric
- **Description**: TBD

## Pin Puzzles
- **POV**: Flat 2D
- **Description**: TBD
