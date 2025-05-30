# res://custom_tile_data.gd (or your actual path)
extends Resource
class_name CustomTileData

@export var position: Vector3
@export var grid_coords: Vector2i
@export var height_level: int
@export var tile_type: String
@export var walkable: bool = true
@export var movement_cost: int = 1
@export var defense_bonus: int = 0
@export var cover_type: String = "none"
@export var has_prop: bool = false
@export var has_structure: bool = false

@export var occupant: Variant = null # <--- ENSURE THIS LINE IS PRESENT AND UNCOMMENTED
@export var owner: Variant = null # This was in your original, keeping it

func _init(p_grid_coords := Vector2i.ZERO, p_height_level := 0, p_tile_type := "unknown"):
	grid_coords = p_grid_coords
	height_level = p_height_level
	tile_type = p_tile_type
	# has_prop, has_structure, occupant, owner will be default (false/null)
