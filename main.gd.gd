# res://main.gd (or your script attached to the Main node)
extends Node3D # Or whatever your Main node's type is

const UnitScene = preload("res://units/unit.tscn") # Path to your Unit.tscn

# Adjust this path if your MapGenerator is elsewhere or you access it differently
@onready var map_generator: Node3D = $MapGenerator # Assuming MapGenerator is a direct child
@onready var character_node_for_units: Node3D = $Character # Or a different container like $ActiveUnits

# You might want a dedicated Node3D container for spawned units
# If $Character is for a single player-controlled character, create a new Node3D, e.g., "SpawnedUnits"
# and change the line above to:
# @onready var units_container: Node3D = $SpawnedUnits


func _ready():
	# Wait for the map to be fully ready before spawning units on it
	if map_generator.has_signal("map_fully_ready"):
		if not map_generator.is_connected("map_fully_ready", Callable(self, "_on_map_fully_ready")):
			map_generator.connect("map_fully_ready", Callable(self, "_on_map_fully_ready"))
		# If the map might already be ready (e.g., if this _ready() runs after map_generator's _ready())
		# you might need a flag in map_generator to check its status.
		# For now, we assume the signal will fire.
	else:
		# If no signal, assume map is ready after a short delay or its own _ready()
		# This is less robust; the signal is preferred.
		print_debug("MapGenerator does not have 'map_fully_ready' signal. Attempting to spawn unit directly.")
		_spawn_test_unit()


func _on_map_fully_ready():
	print("Main: Map is fully ready. Spawning test unit.")
	_spawn_test_unit()


func _spawn_test_unit():
	if not is_instance_valid(map_generator):
		printerr("Main: MapGenerator node not found or invalid!")
		return

	# 1. Load the UnitData
	var unit_data_to_spawn = load("res://units/data/SoldierData.tres") as UnitData # Example
	if not unit_data_to_spawn:
		printerr("Main: Failed to load UnitData.")
		return

	# 2. Find a valid grass tile to spawn on
	var spawn_grid_coords = Vector2i(-1, -1)
	var spawn_tile_data: CustomTileData = null

	# Iterate through some map area to find a grass tile
	# This is a simple search; a more robust method would be needed for complex maps
	var search_limit = min(map_generator.map_width, map_generator.map_depth, 20) # Search a small area
	for x in range(search_limit):
		for z in range(search_limit):
			var current_coord = Vector2i(x, z)
			var tile_data = map_generator.get_tile_data_at(current_coord) # Assumes get_tile_data_at exists
			if tile_data and tile_data.tile_type == "grass" and not tile_data.has_structure and not tile_data.has_prop:
				spawn_grid_coords = current_coord
				spawn_tile_data = tile_data
				break # Found a tile
		if spawn_grid_coords != Vector2i(-1, -1):
			break

	if not spawn_tile_data:
		printerr("Main: Could not find a suitable grass tile to spawn the unit on.")
		return
	
	# 3. Get world position from the tile data
	# The tile_data.position is the center of the tile.
	# We need the position for the CharacterBody3D's origin (feet).
	# Assuming tile_data.position.y is the center Y of the tile block.
	var tile_world_center_y = spawn_tile_data.position.y
	var tile_height_world = map_generator.current_tile_dimensions.y # Get from MapGenerator
	
	# The top surface of the tile
	var tile_top_y = tile_world_center_y + (tile_height_world / 2.0)
	
	var spawn_world_position = Vector3(spawn_tile_data.position.x, tile_top_y, spawn_tile_data.position.z)

	# 4. Instantiate and initialize the unit
	var new_unit_instance = UnitScene.instantiate() as Unit
	if not new_unit_instance:
		printerr("Main: Failed to instantiate UnitScene.")
		return

	# Add to scene tree BEFORE initializing
	character_node_for_units.add_child(new_unit_instance) # Add to your designated units container
	
	new_unit_instance.initialize_unit(unit_data_to_spawn, spawn_grid_coords, spawn_world_position)

	print("Main: Spawned ", unit_data_to_spawn.unit_name, " on tile ", spawn_grid_coords, " (world: ", spawn_world_position, ")")
