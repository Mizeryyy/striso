# res://main.gd
extends Node3D

const UnitScene = preload("res://units/unit.tscn")

@onready var map_generator_node = $MapGenerator
@onready var units_container_node = $UnitsContainer

func _ready():
	print_debug("Main.gd: _ready() CALLED.")
	if not is_instance_valid(map_generator_node):
		printerr("Main.gd: CRITICAL - MapGenerator node NOT FOUND at path '$MapGenerator'.")
		return
	print_debug("Main.gd: map_generator_node is valid.")
	if not is_instance_valid(units_container_node):
		printerr("Main.gd: CRITICAL - UnitsContainer node NOT FOUND at path '$UnitsContainer'.")
		return
	print_debug("Main.gd: units_container_node is valid.")

	if map_generator_node.has_signal("map_fully_ready"):
		print_debug("Main.gd: MapGenerator has 'map_fully_ready' signal. Attempting to connect.")
		if not map_generator_node.is_connected("map_fully_ready", Callable(self, "_on_map_fully_ready")):
			var error_code = map_generator_node.connect("map_fully_ready", Callable(self, "_on_map_fully_ready"))
			if error_code == OK: print_debug("Main.gd: Successfully connected to 'map_fully_ready'.")
			else: printerr("Main.gd: Failed to connect to 'map_fully_ready'. Error code: ", error_code)
		else:
			print_debug("Main.gd: Already connected to 'map_fully_ready'.")
			if map_generator_node.has_method("is_map_ready") and map_generator_node.is_map_ready():
				print_debug("Main.gd: Map was already ready. Calling _on_map_fully_ready directly.")
				_on_map_fully_ready()
	else:
		printerr("Main.gd: MapGenerator does NOT have 'map_fully_ready' signal.")

func _on_map_fully_ready():
	print_debug("Main.gd: _on_map_fully_ready() SIGNAL RECEIVED.")
	_spawn_test_unit()

func _spawn_test_unit():
	print_debug("Main.gd: _spawn_test_unit() called.")
	if not is_instance_valid(map_generator_node):
		printerr("Main.gd (_spawn_test_unit): MapGenerator node became invalid.")
		return

	var mg_has_get_tile_data = map_generator_node.has_method("get_tile_data_at")
	var mg_has_is_valid_coord = map_generator_node.has_method("is_valid_coord")
	var mg_has_tile_dims = "current_tile_dimensions" in map_generator_node and map_generator_node.current_tile_dimensions is Vector3
	var mg_has_map_width = "map_width" in map_generator_node
	var mg_has_map_depth = "map_depth" in map_generator_node

	if not (mg_has_get_tile_data and mg_has_is_valid_coord and mg_has_tile_dims and mg_has_map_width and mg_has_map_depth):
		printerr("Main.gd: MapGenerator is missing one or more required members.") # Detailed errors follow
		if not mg_has_get_tile_data: printerr("  - Method: get_tile_data_at(Vector2i)")
		if not mg_has_is_valid_coord: printerr("  - Method: is_valid_coord(int, int)")
		if not mg_has_tile_dims: printerr("  - Property: current_tile_dimensions (as Vector3)")
		if not mg_has_map_width: printerr("  - Property: map_width (as int)")
		if not mg_has_map_depth: printerr("  - Property: map_depth (as int)")
		return

	var unit_data_to_spawn = load("res://units/data/Soldier.tres") as UnitData
	if not unit_data_to_spawn:
		printerr("Main.gd: Failed to load UnitData from 'res://units/data/Soldier.tres'.")
		return
	print_debug("Main.gd: Loaded UnitData: '", unit_data_to_spawn.unit_name, "' with footprint: ", unit_data_to_spawn.footprint_size)

	var anchor_grid_coords = Vector2i(-1, -1)
	var can_place_footprint = false
	var map_width_val: int = map_generator_node.map_width
	var map_depth_val: int = map_generator_node.map_depth
	var unit_footprint: Vector2i = unit_data_to_spawn.footprint_size
	print_debug("Main.gd: Map dimensions from MapGenerator: ", map_width_val, "x", map_depth_val)
	
	var search_limit_x = map_width_val - (unit_footprint.x - 1)
	var search_limit_z = map_depth_val - (unit_footprint.y - 1)
	print_debug("Main.gd: Searching for suitable area for footprint ", unit_footprint, " within effective map area up to (", search_limit_x-1, ",", search_limit_z-1,")")

	for x_anchor in range(search_limit_x):
		for z_anchor in range(search_limit_z):
			var current_anchor_coord = Vector2i(x_anchor, z_anchor)
			var all_tiles_in_footprint_valid = true
			for dx in range(unit_footprint.x):
				for dz in range(unit_footprint.y):
					var check_coord = current_anchor_coord + Vector2i(dx, dz)
					if not map_generator_node.is_valid_coord(check_coord.x, check_coord.y):
						all_tiles_in_footprint_valid = false; break
					var tile_data = map_generator_node.get_tile_data_at(check_coord)
					if not tile_data or tile_data.tile_type != "grass" or \
					   tile_data.has_structure or tile_data.has_prop or is_instance_valid(tile_data.occupant): # Check occupant too
						all_tiles_in_footprint_valid = false; break
				if not all_tiles_in_footprint_valid: break
			if all_tiles_in_footprint_valid:
				anchor_grid_coords = current_anchor_coord
				can_place_footprint = true
				print_debug("Main.gd: Found suitable area for footprint starting at anchor ", anchor_grid_coords)
				break
		if can_place_footprint: break

	if not can_place_footprint:
		printerr("Main.gd: Could not find a suitable area for unit footprint ", unit_footprint, " to spawn on after searching.")
		return

	var tile_dims: Vector3 = map_generator_node.current_tile_dimensions
	if tile_dims == Vector3.ZERO:
		printerr("Main.gd: MapGenerator 'current_tile_dimensions' is Vector3.ZERO.")
		return
	print_debug("Main.gd: Using Tile dimensions for spawn: ", tile_dims)

	var anchor_tile_data = map_generator_node.get_tile_data_at(anchor_grid_coords)
	if not anchor_tile_data:
		printerr("Main.gd: CRITICAL - Could not get tile data for chosen anchor tile ", anchor_grid_coords)
		return

	var footprint_center_world_x = (float(anchor_grid_coords.x) + (float(unit_footprint.x) / 2.0)) * tile_dims.x
	var footprint_center_world_z = (float(anchor_grid_coords.y) + (float(unit_footprint.y) / 2.0)) * tile_dims.z
	var spawn_y_level = anchor_tile_data.position.y + (tile_dims.y / 2.0)
	var spawn_world_position = Vector3(footprint_center_world_x, spawn_y_level, footprint_center_world_z)
	print_debug("Main.gd: Calculated spawn world position (center of footprint): ", spawn_world_position)

	var new_unit_instance = UnitScene.instantiate() as Unit
	if not new_unit_instance:
		printerr("Main.gd: Failed to instantiate UnitScene.")
		return
	print_debug("Main.gd: UnitScene instantiated successfully as '", new_unit_instance.name, "'.")

	units_container_node.add_child(new_unit_instance)
	print_debug("Main.gd: Added unit instance '", new_unit_instance.name, "' to units_container_node '", units_container_node.name, "'.")
	
	# Pass the map_generator_node itself to the unit
	new_unit_instance.initialize_unit(unit_data_to_spawn, anchor_grid_coords, spawn_world_position, tile_dims, map_generator_node)
	print_debug("Main.gd: Called initialize_unit on new unit instance '", new_unit_instance.name, "'.")

	# --- Mark tiles as occupied ---
	print_debug("Main.gd: Attempting to mark tiles as occupied for unit '", new_unit_instance.name, "' with footprint ", unit_footprint)
	for dx in range(unit_footprint.x):
		for dz in range(unit_footprint.y):
			var occupied_coord = anchor_grid_coords + Vector2i(dx, dz)
			var occ_tile_data = map_generator_node.get_tile_data_at(occupied_coord)
			if occ_tile_data:
				print_debug("Main.gd: Marking tile ", occupied_coord, " (type: ", occ_tile_data.tile_type, ") as occupied by unit '", new_unit_instance.name, "'.")
				occ_tile_data.occupant = new_unit_instance # Store reference to the unit
				occ_tile_data.walkable = false          # Make the tile unwalkable
			else:
				printerr("Main.gd: Could not get tile_data for ", occupied_coord, " while trying to mark as occupied.")
	# --- End Mark tiles ---

	print("Main: Spawned '", unit_data_to_spawn.unit_name, "' (instance '", new_unit_instance.name, "') with anchor at grid ", anchor_grid_coords, " (world center: ", spawn_world_position, ")")
