# res://player/structure_placer.gd
extends Node

@export var map_generator: Node3D # Assign your MapGenerator node here in the editor

var current_structure_to_place: StructureData = null 
var current_selected_hotbar_slot: int = -1 
var current_player_id: int = 1 
var placement_indicator_instance: Node3D = null
var last_valid_tile_coord: Vector2i = Vector2i(-9999, -9999) 

@export_range(0.1, 1.0, 0.05) var indicator_transparency: float = 0.5
@export var valid_placement_color: Color = Color(0,1,0,0.5) 
@export var invalid_placement_color: Color = Color(1,0,0,0.5) 

@export var hotbar_structure_ids: Array[StringName] = [
	&"wood_outpost", 
	&"stone_quarry"
] 
var hotbar_structures_data: Array[StructureData] = []

signal hotbar_updated(hotbar_items_data, active_slot)
signal active_hotbar_slot_changed(active_slot)

func _ready():
	if not is_instance_valid(map_generator): # Check if assigned in editor
		printerr("StructurePlacer: CRITICAL - MapGenerator node not assigned in the Inspector! Disabling StructurePlacer.")
		set_process_input(false); set_process(false); return
	
	# Wait for MapGenerator to be fully ready and have loaded its structures
	# This loop tries a few frames. For very complex MapGenerator _ready, a signal might be better.
	var wait_frames = 5 # Max frames to wait
	while not map_generator.is_node_ready() or \
		  not ("available_structures" in map_generator) or \
		  not map_generator.available_structures is Dictionary or \
		  map_generator.available_structures.is_empty():
		
		wait_frames -= 1
		if wait_frames <= 0:
			printerr("StructurePlacer: Timeout waiting for MapGenerator to be ready or load structures. Hotbar might be empty.")
			break
		print("StructurePlacer: Waiting for MapGenerator to be ready and load structures...") # DEBUG
		await get_tree().process_frame # Wait one frame
		# Re-check if map_generator became invalid during await (e.g. scene change)
		if not is_instance_valid(map_generator):
			printerr("StructurePlacer: MapGenerator became invalid while waiting.")
			set_process_input(false); set_process(false); return


	# Now attempt to populate hotbar
	_populate_hotbar_data()
	emit_signal("hotbar_updated", hotbar_structures_data, current_selected_hotbar_slot)
	print("StructurePlacer _ready finished. Hotbar items: ", hotbar_structures_data.size()) # DEBUG


func _populate_hotbar_data():
	hotbar_structures_data.clear()
	# Check again, as MapGenerator might have completed _ready but not populated 'available_structures' if load_available_structures was deferred
	if not is_instance_valid(map_generator) or not ("available_structures" in map_generator) or not map_generator.available_structures is Dictionary:
		printerr("StructurePlacer: Cannot populate hotbar, MapGenerator or its available_structures is not valid/ready.")
		return

	if map_generator.available_structures.is_empty():
		# Attempt to call load_available_structures if it's still empty after waiting, as a last resort.
		# This assumes load_available_structures is safe to call multiple times or checks if already loaded.
		if map_generator.has_method("load_available_structures"):
			print("StructurePlacer: MapGenerator.available_structures is empty, attempting to call load_available_structures().")
			map_generator.load_available_structures() 
		if map_generator.available_structures.is_empty(): # Check again after attempting load
			printerr("StructurePlacer: MapGenerator.available_structures still empty after attempted load. Hotbar will be empty.")
			return


	print("StructurePlacer: Attempting to populate hotbar. MapGenerator available structures: ", map_generator.available_structures.keys())
	for struct_id in hotbar_structure_ids:
		print("StructurePlacer: Processing hotbar ID: ", struct_id)
		if map_generator.available_structures.has(struct_id):
			var loaded_data = map_generator.available_structures[struct_id]
			if loaded_data is StructureData: 
				hotbar_structures_data.append(loaded_data)
			else:
				hotbar_structures_data.append(null)
				printerr("StructurePlacer: Data for ID '", struct_id, "' in MapGenerator is not StructureData type.")
		else:
			hotbar_structures_data.append(null) 
			printerr("StructurePlacer: StructureData with ID '", struct_id, "' not found in MapGenerator for hotbar.")
	print("StructurePlacer: Hotbar populated. Items count: ", hotbar_structures_data.size())


func _cleanup_previous_indicator():
	if is_instance_valid(placement_indicator_instance):
		placement_indicator_instance.queue_free()
	placement_indicator_instance = null

func _activate_placement_mode(structure_data: StructureData, player_id: int):
	_cleanup_previous_indicator() 
	print("StructurePlacer: Activating placement mode for: ", structure_data.id if structure_data else "Null StructureData")

	if not structure_data or not structure_data is StructureData:
		printerr("StructurePlacer: _activate_placement_mode called with invalid structure_data type.")
		current_structure_to_place = null
		return

	current_structure_to_place = structure_data
	current_player_id = player_id 

	var model_to_instance = structure_data.model_p1 
	if current_player_id == 2 and structure_data.model_p2: model_to_instance = structure_data.model_p2
	elif not model_to_instance: model_to_instance = structure_data.model_p2 if structure_data.model_p2 else structure_data.model_p1

	if model_to_instance:
		print("StructurePlacer: Attempting to instantiate indicator model: ", model_to_instance.resource_path if model_to_instance else "Null model scene")
		placement_indicator_instance = model_to_instance.instantiate() as Node3D
		if placement_indicator_instance:
			print("StructurePlacer: Indicator instantiated successfully.")
			get_tree().root.add_child(placement_indicator_instance) 
			placement_indicator_instance.visible = false 
			_set_indicator_material_properties(placement_indicator_instance, invalid_placement_color) 
			
			if map_generator and map_generator.AssetUtilities_C and structure_data.model_tile_radius > 0:
				map_generator.AssetUtilities_C.scale_node_to_tile_radius(placement_indicator_instance, float(structure_data.model_tile_radius), map_generator.current_tile_dimensions.x)
			
			_update_indicator_state() 
		else:
			printerr("StructurePlacer: Failed to instantiate model for placement indicator."); current_structure_to_place = null
	else:
		printerr("StructurePlacer: No model defined in StructureData for indicator: ", structure_data.id)
		current_structure_to_place = null

func _set_indicator_material_properties(node: Node, target_color: Color):
	# ... (This function remains the same)
	if not node: return
	if node is MeshInstance3D:
		var mi = node as MeshInstance3D
		for surface_idx in range(mi.mesh.get_surface_count() if mi.mesh else 0): 
			var current_mat_on_surface = mi.get_surface_override_material(surface_idx)
			var new_mat: StandardMaterial3D
			if current_mat_on_surface and current_mat_on_surface is StandardMaterial3D: new_mat = current_mat_on_surface.duplicate(true) as StandardMaterial3D 
			elif mi.mesh and mi.mesh.surface_get_material(surface_idx) and mi.mesh.surface_get_material(surface_idx) is StandardMaterial3D:
				new_mat = mi.mesh.surface_get_material(surface_idx).duplicate(true) as StandardMaterial3D
			else: new_mat = StandardMaterial3D.new()
			new_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
			var albedo = target_color; albedo.a = indicator_transparency
			new_mat.albedo_color = albedo
			new_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
			mi.set_surface_override_material(surface_idx, new_mat)
	for child in node.get_children():
		if child is Node3D: _set_indicator_material_properties(child, target_color)


func cancel_placement():
	# ... (This function remains the same)
	print("StructurePlacer: Cancelling placement.")
	_cleanup_previous_indicator()
	current_structure_to_place = null
	current_selected_hotbar_slot = -1 
	emit_signal("active_hotbar_slot_changed", current_selected_hotbar_slot)
	last_valid_tile_coord = Vector2i(-9999,-9999)

func _unhandled_input(event: InputEvent):
	# ... (This function remains largely the same, ensure map_generator check at top)
	if not is_instance_valid(map_generator): return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var selected_slot_by_key = -1
		if event.keycode == KEY_1: selected_slot_by_key = 0
		elif event.keycode == KEY_2: selected_slot_by_key = 1
		elif event.keycode == KEY_3: selected_slot_by_key = 2
		elif event.keycode == KEY_4: selected_slot_by_key = 3
		elif event.keycode == KEY_5: selected_slot_by_key = 4

		if event.keycode == KEY_ESCAPE:
			if current_structure_to_place: cancel_placement()
			get_viewport().set_input_as_handled(); return

		if selected_slot_by_key != -1:
			print("StructurePlacer: Hotkey ", selected_slot_by_key + 1, " pressed.")
			if selected_slot_by_key < hotbar_structures_data.size(): # Check if slot is within bounds
				print("StructurePlacer: Hotbar data for slot ", selected_slot_by_key, ": ", hotbar_structures_data[selected_slot_by_key])
				if current_selected_hotbar_slot == selected_slot_by_key and current_structure_to_place:
					print("StructurePlacer: Toggling off current selection.")
					cancel_placement() 
				elif hotbar_structures_data[selected_slot_by_key] != null: # Check if slot has data
					print("StructurePlacer: Activating placement for slot: ", selected_slot_by_key)
					current_selected_hotbar_slot = selected_slot_by_key
					_activate_placement_mode(hotbar_structures_data[selected_slot_by_key], current_player_id)
					emit_signal("active_hotbar_slot_changed", current_selected_hotbar_slot)
				else: 
					print("StructurePlacer: Selected hotbar slot ", selected_slot_by_key, " is empty/invalid.")
					cancel_placement()
			else: 
				print("StructurePlacer: Hotkey for slot ", selected_slot_by_key, " is out of hotbar_structures_data range (size: ", hotbar_structures_data.size(), ").")
				cancel_placement()
			get_viewport().set_input_as_handled(); return
	
	if current_structure_to_place: 
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			print("StructurePlacer: Left mouse button pressed for placement.")
			print("StructurePlacer: Last valid tile coord: ", last_valid_tile_coord)
			print("StructurePlacer: Current structure to place: ", current_structure_to_place.id if current_structure_to_place else "None")
			if last_valid_tile_coord != Vector2i(-9999,-9999): 
				if map_generator.can_place_structure_at(current_structure_to_place, last_valid_tile_coord, current_player_id):
					print("StructurePlacer: Placement validated. Telling MapGenerator to place.")
					map_generator.place_structure(current_structure_to_place, last_valid_tile_coord, current_player_id)
					var data_to_reselect = current_structure_to_place 
					_cleanup_previous_indicator() 
					_activate_placement_mode(data_to_reselect, current_player_id) 
				else: print("StructurePlacer: Cannot place structure here (map_generator.can_place_structure_at failed).")
			else: print("StructurePlacer: Not a valid placement location (last_valid_tile_coord invalid).")
			get_viewport().set_input_as_handled()

func _update_indicator_state():
	# ... (This function remains the same)
	if not current_structure_to_place or not is_instance_valid(placement_indicator_instance) or not is_instance_valid(map_generator):
		if is_instance_valid(placement_indicator_instance): placement_indicator_instance.visible = false
		return

	var camera = get_viewport().get_camera_3d(); if not camera: return
	var world_3d = get_viewport().world_3d 
	if not world_3d:
		if map_generator is Node3D and map_generator.is_inside_tree(): world_3d = map_generator.get_world_3d() 
		else:
			var root_node = get_tree().root
			if root_node is Node3D: world_3d = root_node.get_world_3d()
			else: printerr("StructurePlacer: Could not obtain World3D."); if is_instance_valid(placement_indicator_instance): placement_indicator_instance.visible = false; return
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 2000 
	var space_state = world_3d.direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var collision_mask_to_use = 1 
	if map_generator and "TERRAIN_COLLISION_LAYER" in map_generator: collision_mask_to_use = map_generator.TERRAIN_COLLISION_LAYER
	query.collision_mask = collision_mask_to_use
	var result = space_state.intersect_ray(query)

	if result:
		var hit_position = result.position
		if map_generator.has_method("world_to_grid_coords_snapped"):
			var tile_coord: Vector2i = map_generator.world_to_grid_coords_snapped(hit_position)
			var tile_data: CustomTileData = map_generator.get_tile_data_at(tile_coord) 
			if tile_data: 
				var model_pos_x: float; var model_pos_z: float
				var footprint_center_offset_x_tiles = current_structure_to_place.footprint_offset_tiles.x + (current_structure_to_place.footprint_size_tiles.x - 1.0) * 0.5
				var footprint_center_offset_z_tiles = current_structure_to_place.footprint_offset_tiles.y + (current_structure_to_place.footprint_size_tiles.y - 1.0) * 0.5
				model_pos_x = (float(tile_coord.x) + footprint_center_offset_x_tiles) * map_generator.current_tile_dimensions.x + map_generator.current_tile_dimensions.x * 0.5
				model_pos_z = (float(tile_coord.y) + footprint_center_offset_z_tiles) * map_generator.current_tile_dimensions.z + map_generator.current_tile_dimensions.z * 0.5
				var central_footprint_tile_coord = tile_coord + Vector2i(floor(footprint_center_offset_x_tiles), floor(footprint_center_offset_z_tiles))
				var central_tile_data_for_y: CustomTileData = map_generator.get_tile_data_at(central_footprint_tile_coord)
				if not central_tile_data_for_y: central_tile_data_for_y = tile_data 
				var indicator_y = central_tile_data_for_y.position.y + (map_generator.current_tile_dimensions.y * 0.5) 
				placement_indicator_instance.global_position = Vector3(model_pos_x, indicator_y, model_pos_z)
				placement_indicator_instance.visible = true
				var can_place = map_generator.can_place_structure_at(current_structure_to_place, tile_coord, current_player_id)
				if can_place: _set_indicator_material_properties(placement_indicator_instance, valid_placement_color); last_valid_tile_coord = tile_coord
				else: _set_indicator_material_properties(placement_indicator_instance, invalid_placement_color); last_valid_tile_coord = Vector2i(-9999,-9999)
				return 
	if is_instance_valid(placement_indicator_instance): placement_indicator_instance.visible = false
	last_valid_tile_coord = Vector2i(-9999,-9999)

func _process(delta):
	if current_structure_to_place and is_instance_valid(placement_indicator_instance):
		_update_indicator_state()
	elif is_instance_valid(placement_indicator_instance): 
		placement_indicator_instance.visible = false
