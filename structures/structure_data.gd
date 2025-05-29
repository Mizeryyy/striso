# res://structures/structure_data.gd
class_name StructureData
extends Resource

@export_group("Identification")
@export var id: StringName = &"" 
@export var display_name: String = "Structure"

@export_group("Visuals")
@export var model_p1: PackedScene = null 
@export var model_p2: PackedScene = null 
@export_range(1, 10, 1) var model_tile_radius: int = 2 

@export_group("Placement & Footprint")
@export var footprint_size_tiles: Vector2i = Vector2i(3, 3) 
@export var footprint_offset_tiles: Vector2i = Vector2i(-1, -1) # For 3x3 centered, this is (-1,-1)
@export_range(0, 10, 1) var flatten_radius_tiles: int = 3 
@export_range(0.0, 2.0, 0.01) var flatten_strength: float = 1.0 
@export_range(0, 10, 1) var prop_removal_radius_tiles: int = 4 

@export_group("Placement Rules")
@export var allowed_tile_types: Array[String] = ["grass", "forest_grass"] 
@export var disallowed_tile_types: Array[String] = ["water", "mountain"]
@export_range(0, 10, 1) var min_dist_from_water_tiles: int = 2
@export_range(0, 10, 1) var min_dist_from_mountain_tiles: int = 1
# @export var requires_resource_nearby: StringName = &"" # For later
# @export_range(1, 15, 1) var resource_search_radius_tiles: int = 5 # For later

@export_group("Behavior & Logic (Example: Resource Collector)")
@export var produces_resource: StringName = &"wood" # e.g., "wood", "stone"
@export_range(1, 100, 1) var production_rate: float = 5.0 
@export_range(1, 60, 1) var production_interval: float = 10.0 

func get_footprint_tiles(placement_coord: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var bottom_left_x = placement_coord.x + footprint_offset_tiles.x
	var bottom_left_z = placement_coord.y + footprint_offset_tiles.y 

	for dx in range(footprint_size_tiles.x):
		for dz in range(footprint_size_tiles.y):
			tiles.append(Vector2i(bottom_left_x + dx, bottom_left_z + dz))
	return tiles
