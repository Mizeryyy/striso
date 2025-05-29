# placeable_mesh_rule.gd
extends Resource
class_name PlaceableMeshRule

## The path to the Mesh resource (e.g., .obj, .gltf, .tres) or PackedScene.
@export var mesh_path: String = ""

## Tile types this mesh can spawn on (e.g., "grass", "forest_grass", "mountain", "sand", "water").
@export var target_tile_types: Array[String] = ["grass"]

## Probability (0.0 to 1.0) of this mesh spawning on an eligible tile.
@export_range(0.0, 1.0, 0.01) var spawn_probability: float = 0.1

## If true, only one decoration (of any type marked unique) can be on a single tile.
## If multiple unique rules match a tile, the first one in the 'placeable_mesh_rules' array that spawns will take the slot.
@export var unique_on_tile: bool = true

## Minimum normalized height (0-1 based on map's visual height range) for spawning.
@export_range(0.0, 1.0, 0.01) var min_spawn_height_norm: float = 0.0
## Maximum normalized height (0-1 based on map's visual height range) for spawning.
@export_range(0.0, 1.0, 0.01) var max_spawn_height_norm: float = 1.0

## Minimum distance from a water tile (actual water, not shoreline) for spawning. -1 means no restriction.
@export_range(-1, 50, 1) var min_dist_to_water: int = -1
## Maximum distance from a water tile for spawning. -1 means no restriction.
@export_range(-1, 50, 1) var max_dist_to_water: int = -1 # e.g., for plants that like to be near but not in water

## Minimum random scale factor.
@export_range(0.1, 5.0, 0.1) var min_scale: float = 0.8
## Maximum random scale factor.
@export_range(0.1, 5.0, 0.1) var max_scale: float = 1.2

## Apply random Y rotation.
@export var random_y_rotation: bool = true
## Vertical offset from the tile's determined top surface.
@export var y_offset: float = 0.0

## Future use: align Y axis of the mesh to the tile's surface normal (for sloped terrain).
@export var align_y_to_normal: bool = false # Not yet implemented

func _init(p_mesh_path := "", p_target_types := ["grass"], p_prob := 0.1):
	mesh_path = p_mesh_path
	target_tile_types = p_target_types
	spawn_probability = p_prob
