# custom_tile_data.gd
extends Resource
class_name CustomTileData

@export var position: Vector3 # World position of the tile's center
@export var grid_coords: Vector2i
@export var height_level: int # Integer classification of height for gameplay
@export var tile_type: String
@export var walkable: bool = true
@export var movement_cost: int = 1
@export var defense_bonus: int = 0
@export var cover_type: String = "none" 
@export var has_prop: bool = false 
@export var has_structure: bool = false 

@export var occupant: Variant = null 
@export var owner: Variant = null 

func _init(p_grid_coords := Vector2i.ZERO, p_height_level := 0, p_tile_type := "unknown"):
	grid_coords = p_grid_coords
	height_level = p_height_level
	tile_type = p_tile_type
	has_prop = false
	has_structure = false
