## Static helper for baking a navigation mesh from a grid's geometry.
##
## `bake_from_grid()` parses every static body under `grid` (floor tiles AND
## walls) and bakes a fresh `NavigationMesh` on top of it. This is how a
## `grid_map.gd` floor + walls becomes something `NavigationAgent3D` can path
## over. Returns a new resource on every call, so toggled walls bake into a
## brand-new navmesh without stale polygon data.
##
## Important: like `NavigationServer3D.parse_source_geometry_data()`, the grid
## must already be inside the scene tree when you bake — a parse on a node that
## isn't in the tree silently produces an empty navmesh. Call this in
## `_ready()` or later, never before the node enters the tree. Region and map
## iteration builds are configured synchronous in `project.godot`, so a baked
## navmesh is queryable on the very next physics frame.
class_name NavmeshBaker
extends RefCounted

## Bake cell size. Smaller = finer detail on small maps. 0.1 keeps
## `agent_radius`/`agent_height` within 0.05 of their voxel-ceiled values. The
## world's default navigation map is configured with the same cell size in
## `project.godot` (`navigation/3d/default_cell_size`), so mesh and map match —
## a runtime `map_set_cell_size()` after a region registers would stale the map
## and empty the path queries.
const DEFAULT_CELL_SIZE := 0.1

## Navmesh erosion radius; paths stay this far away from walls. Kept a voxel
## multiple of `DEFAULT_CELL_SIZE` (0.1) so the baked erosion matches exactly.
const DEFAULT_AGENT_RADIUS := 0.4

## Vertical clearance required above walkable surfaces (keeps wall tops out).
const DEFAULT_AGENT_HEIGHT := 1.8

## Highest step the agent can climb. A voxel multiple so baking doesn't round.
const DEFAULT_AGENT_MAX_CLIMB := 0.2


## Bakes a new NavigationMesh from the static geometry under `grid`.
## `grid` must be inside the tree (see class doc). Returns an empty navmesh
## (with a warning) if nothing was parsed.
static func bake_from_grid(grid: Node, agent_radius: float = DEFAULT_AGENT_RADIUS, agent_height: float = DEFAULT_AGENT_HEIGHT) -> NavigationMesh:
	var navmesh := NavigationMesh.new()
	navmesh.agent_radius = agent_radius
	navmesh.agent_height = agent_height
	navmesh.agent_max_climb = DEFAULT_AGENT_MAX_CLIMB
	navmesh.cell_size = DEFAULT_CELL_SIZE
	navmesh.cell_height = DEFAULT_CELL_SIZE
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navmesh, source, grid)
	if not source.has_data():
		push_warning("NavmeshBaker: no geometry parsed from grid — is it inside the scene tree?")
		return navmesh
	NavigationServer3D.bake_from_source_geometry_data(navmesh, source, Callable())
	return navmesh
