# res://map_generation/map_data_manager.gd
class_name MapDataManager
extends RefCounted

var map_width: int = 0
var map_depth: int = 0

var visual_normalized_height_map: Array = [] 
var final_tile_type_map: Array = [] 
var initial_tile_type_map: Array = [] 
var base_normalized_height_map: Array = [] 
var shore_tile_info_map: Array = []

var grid: Dictionary = {} # Vector2i -> CustomTileData

func initialize_arrays(p_map_width: int, p_map_depth: int):
	map_width = p_map_width
	map_depth = p_map_depth

	# Clear and resize main arrays
	var arrays_to_clear_resize = [
		visual_normalized_height_map, final_tile_type_map, initial_tile_type_map,
		base_normalized_height_map, shore_tile_info_map
	]
	for arr_ref in arrays_to_clear_resize:
		arr_ref.clear()
		if map_width <= 0: continue # Prevent errors if map_width is invalid
		arr_ref.resize(map_width)
		for x_arr_init in range(map_width): 
			arr_ref[x_arr_init] = [] 
			if map_depth <= 0: continue # Prevent errors if map_depth is invalid
			arr_ref[x_arr_init].resize(map_depth)

	# Initialize array contents
	for x in range(map_width):
		for z in range(map_depth):
			visual_normalized_height_map[x][z] = 0.0
			base_normalized_height_map[x][z] = 0.0
			final_tile_type_map[x][z] = ""
			initial_tile_type_map[x][z] = ""
			shore_tile_info_map[x][z] = {"ring":0, "source_land_type": "water", "source_land_base_h":0.0}
			
	grid.clear()

func get_tile_data_at(coords: Vector2i) -> CustomTileData:
	if not is_valid_coord(coords.x, coords.y): 
		# printerr("MapDataManager: Attempted to get tile data at invalid coord: ", coords)
		return null
	return grid.get(coords, null)

func set_tile_data_at(coords: Vector2i, data: CustomTileData):
	if not is_valid_coord(coords.x, coords.y):
		printerr("MapDataManager: Attempted to set tile data at invalid coord: ", coords)
		return
	grid[coords] = data

func is_valid_coord(x: int, z: int) -> bool:
	return x >= 0 and x < map_width and z >= 0 and z < map_depth
