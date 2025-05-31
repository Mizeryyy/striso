# res://highlighter/HighlighterManager.gd
extends Node

# No scene preload needed if we create meshes programmatically

@export_group("Outline Appearance")
@export var hover_outline_color: Color = Color(0.6, 0.6, 0.6, 0.75)
@export var unit_outline_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var reachable_tile_color: Color = Color(0.3, 0.5, 1.0, 0.6) # Bluish for reachable
@export var outline_thickness: float = 0.08
@export var outline_shader_path: String = "res://highlighter/outline.gdshader"

@onready var map_generator = get_node("/root/Main/MapGenerator") # !!! ADJUST PATH !!!
var camera: Camera3D
var world_3d_resource: World3D

var primary_highlighter_mesh: MeshInstance3D = null
var primary_highlighter_material: ShaderMaterial = null

var reachable_highlighters_pool: Array[MeshInstance3D] = []
var active_reachable_highlighters: Array[MeshInstance3D] = []

var last_hovered_anchor_coords: Vector2i = Vector2i(-1000, -1000)
var last_hovered_is_unit: bool = false
var last_hovered_unit_instance: Unit = null # Store the actual unit instance

var outline_shader: Shader # Loaded in _ready

func _ready():
	await get_tree().process_frame
	# ... (Camera, World3D, MapGenerator setup - same as before) ...
	var current_viewport = get_viewport() # etc.
	if not is_instance_valid(current_viewport): # ...
		printerr("HighlighterManager: Could not get viewport. Highlighter disabled.")
		set_physics_process(false); return
	camera = current_viewport.get_camera_3d() # etc.
	if not is_instance_valid(camera): # ...
		printerr("HighlighterManager: Camera not found. Highlighter disabled.")
		set_physics_process(false); return
	world_3d_resource = current_viewport.world_3d # etc.
	if not is_instance_valid(world_3d_resource): # ...
		printerr("HighlighterManager: Could not get World3D. Highlighter disabled.")
		set_physics_process(false); return
	if not is_instance_valid(map_generator): # ...
		printerr("HighlighterManager: MapGenerator not found. Highlighter disabled.")
		set_physics_process(false); return

	outline_shader = load(outline_shader_path)
	if not outline_shader is Shader:
		printerr("HighlighterManager: Failed to load outline shader from '", outline_shader_path, "'. Highlighter disabled.")
		set_physics_process(false)
		return

	# Create primary highlighter
	primary_highlighter_material = ShaderMaterial.new()
	primary_highlighter_material.shader = outline_shader
	primary_highlighter_material.render_priority = 1 # Try to draw on top of tiles

	primary_highlighter_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new(); plane.size = Vector2(1,1)
	primary_highlighter_mesh.mesh = plane
	primary_highlighter_mesh.material_override = primary_highlighter_material
	add_child(primary_highlighter_mesh)
	primary_highlighter_mesh.visible = false
	
	print_debug("HighlighterManager: Ready.")


func _physics_process(delta: float):
	if not is_instance_valid(camera) or not is_instance_valid(map_generator) or \
	   not is_instance_valid(primary_highlighter_mesh) or not is_instance_valid(world_3d_resource) or \
	   not is_instance_valid(outline_shader):
		if is_instance_valid(primary_highlighter_mesh): primary_highlighter_mesh.visible = false
		_clear_reachable_highlights()
		return

	# --- Raycasting Logic (same as before) ---
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var space_state = world_3d_resource.direct_space_state
	if not is_instance_valid(space_state): return
	var params = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 1000.0)
	var terrain_layer_mask = 1
	if "TERRAIN_COLLISION_LAYER" in map_generator: terrain_layer_mask = map_generator.TERRAIN_COLLISION_LAYER
	params.collision_mask = terrain_layer_mask
	var result = space_state.intersect_ray(params)
	# --- End Raycasting Logic ---

	var current_hovered_anchor_coords = Vector2i(-1000, -1000)
	var current_is_unit_hover = false
	var current_unit_instance: Unit = null
	var unit_footprint = Vector2i(1,1)

	if result:
		var hit_pos = result.position
		var grid_coords_hit = map_generator.world_to_grid_coords_snapped(hit_pos)

		if map_generator.is_valid_coord(grid_coords_hit.x, grid_coords_hit.y):
			var tile_data = map_generator.get_tile_data_at(grid_coords_hit)
			if tile_data and tile_data.tile_type != "water":
				if is_instance_valid(tile_data.occupant) and tile_data.occupant is Unit:
					current_unit_instance = tile_data.occupant as Unit
					current_hovered_anchor_coords = current_unit_instance.current_grid_coords
					if current_unit_instance.unit_data_resource:
						unit_footprint = current_unit_instance.unit_data_resource.footprint_size
					current_is_unit_hover = true
				else:
					current_hovered_anchor_coords = grid_coords_hit
					# unit_footprint remains (1,1)
					current_is_unit_hover = false
	
	# Update primary highlighter and reachable tiles if hover state changed
	if current_hovered_anchor_coords != last_hovered_anchor_coords or current_unit_instance != last_hovered_unit_instance:
		_clear_reachable_highlights() # Clear old reachable tiles first

		if current_hovered_anchor_coords != Vector2i(-1000, -1000):
			_update_primary_highlighter(current_hovered_anchor_coords, unit_footprint, current_is_unit_hover)
			primary_highlighter_mesh.visible = true

			if current_is_unit_hover and is_instance_valid(current_unit_instance):
				_show_reachable_tiles(current_unit_instance)
		else:
			primary_highlighter_mesh.visible = false
			# _clear_reachable_highlights() already called

		last_hovered_anchor_coords = current_hovered_anchor_coords
		last_hovered_is_unit = current_is_unit_hover # This was 'current_is_unit_hover' before, fixed
		last_hovered_unit_instance = current_unit_instance

	elif not is_instance_valid(primary_highlighter_mesh) or not primary_highlighter_mesh.visible:
		if current_hovered_anchor_coords != Vector2i(-1000, -1000):
			_update_primary_highlighter(current_hovered_anchor_coords, unit_footprint, current_is_unit_hover)
			# No need to recall _show_reachable_tiles here unless unit changed, which is handled by above block


func _update_primary_highlighter(anchor_coords: Vector2i, footprint_size: Vector2i, is_unit: bool):
	# ... (This function is the same as _update_highlighter from previous response, but renamed) ...
	# ... It positions and scales primary_highlighter_mesh and sets its color ...
	if not is_instance_valid(primary_highlighter_mesh) or not is_instance_valid(map_generator) or not is_instance_valid(primary_highlighter_material):
		if is_instance_valid(primary_highlighter_mesh): primary_highlighter_mesh.visible = false
		return

	var tile_dims: Vector3 = map_generator.current_tile_dimensions
	if tile_dims == Vector3.ZERO: primary_highlighter_mesh.visible = false; return

	var footprint_world_width = float(footprint_size.x) * tile_dims.x
	var footprint_world_depth = float(footprint_size.y) * tile_dims.z
	var center_x = (float(anchor_coords.x) + float(footprint_size.x) / 2.0) * tile_dims.x
	var center_z = (float(anchor_coords.y) + float(footprint_size.y) / 2.0) * tile_dims.z
	var anchor_tile_data = map_generator.get_tile_data_at(anchor_coords)
	if not anchor_tile_data: primary_highlighter_mesh.visible = false; return
	var top_y = anchor_tile_data.position.y + (tile_dims.y / 2.0) + 0.01 # Slightly above tile

	primary_highlighter_mesh.global_position = Vector3(center_x, top_y, center_z)
	primary_highlighter_mesh.scale = Vector3(footprint_world_width, 1.0, footprint_world_depth)
	#primary_highlighter_mesh.rotation_degrees = Vector3(-90, 0, 0)
	primary_highlighter_material.set_shader_parameter("outline_color", unit_outline_color if is_unit else hover_outline_color)
	primary_highlighter_material.set_shader_parameter("outline_thickness", outline_thickness)
	primary_highlighter_mesh.visible = true


# --- Reachable Tile Logic ---
func _get_or_create_reachable_highlighter() -> MeshInstance3D:
	if not reachable_highlighters_pool.is_empty():
		var highlighter = reachable_highlighters_pool.pop_back() as MeshInstance3D
		highlighter.visible = true
		return highlighter
	
	# Create new if pool is empty
	if not is_instance_valid(outline_shader): return null # Shader must be loaded
	var new_material = ShaderMaterial.new()
	new_material.shader = outline_shader
	new_material.render_priority = 0 # Lower than primary, or same if color is distinct

	var new_mesh_inst = MeshInstance3D.new()
	var plane = PlaneMesh.new(); plane.size = Vector2(1,1)
	new_mesh_inst.mesh = plane
	new_mesh_inst.material_override = new_material
	add_child(new_mesh_inst)
	return new_mesh_inst

func _clear_reachable_highlights():
	for highlighter in active_reachable_highlighters:
		if is_instance_valid(highlighter):
			highlighter.visible = false
			reachable_highlighters_pool.push_back(highlighter)
	active_reachable_highlighters.clear()

func _show_reachable_tiles(unit: Unit):
	if not is_instance_valid(unit) or not unit.unit_data_resource or not is_instance_valid(map_generator):
		return
	_clear_reachable_highlights() # Clear previous ones

	var unit_data = unit.unit_data_resource
	var start_coords_set: Array[Vector2i] = [] # All tiles the unit currently occupies
	for dx in range(unit_data.footprint_size.x):
		for dz in range(unit_data.footprint_size.y):
			start_coords_set.append(unit.current_grid_coords + Vector2i(dx, dz))

	var max_move_points = unit_data.movement_range
	var tile_dims = map_generator.current_tile_dimensions

	var queue: Array = [] # Stores [grid_coord, remaining_move_points]
	var visited: Dictionary = {} # Stores grid_coord -> min_cost_to_reach (or just true)
	var reachable_tiles_coords: Array[Vector2i] = []

	for start_coord in start_coords_set:
		queue.push_back([start_coord, max_move_points])
		visited[start_coord] = max_move_points # Cost to reach start is 0, so remaining is max

	var head = 0
	while head < queue.size():
		var current_item = queue[head]
		head += 1
		var current_coord: Vector2i = current_item[0]
		var remaining_points: int = current_item[1]

		# Add to reachable if not a starting tile itself (optional, depends on if you want to highlight start tiles)
		if not start_coords_set.has(current_coord):
			reachable_tiles_coords.append(current_coord)

		# Explore neighbors (N, S, E, W)
		var neighbors_offsets = [Vector2i(0,1), Vector2i(0,-1), Vector2i(1,0), Vector2i(-1,0)]
		for offset in neighbors_offsets:
			var neighbor_coord = current_coord + offset
			if not map_generator.is_valid_coord(neighbor_coord.x, neighbor_coord.y):
				continue

			var neighbor_tile_data = map_generator.get_tile_data_at(neighbor_coord)
			if not neighbor_tile_data or not neighbor_tile_data.walkable or \
			   (is_instance_valid(neighbor_tile_data.occupant) and neighbor_tile_data.occupant != unit): # Cannot move into occupied by others
				continue

			var cost_to_neighbor = neighbor_tile_data.movement_cost
			var new_remaining_points = remaining_points - cost_to_neighbor

			if new_remaining_points >= 0:
				# If never visited or found a cheaper path (more remaining points)
				if not visited.has(neighbor_coord) or new_remaining_points > visited[neighbor_coord]:
					visited[neighbor_coord] = new_remaining_points
					queue.push_back([neighbor_coord, new_remaining_points])
	
	# Now, visualize the reachable_tiles_coords
	for r_coord in reachable_tiles_coords:
		var highlighter = _get_or_create_reachable_highlighter()
		if not highlighter: continue

		var r_tile_data = map_generator.get_tile_data_at(r_coord)
		if not r_tile_data: continue # Should exist if found in BFS

		active_reachable_highlighters.append(highlighter)
		
		var top_y = r_tile_data.position.y + (tile_dims.y / 2.0) + 0.006 # Slightly different offset
		highlighter.global_position = Vector3(r_tile_data.position.x, top_y, r_tile_data.position.z)
		highlighter.scale = Vector3(tile_dims.x, 1.0, tile_dims.z)
		#highlighter.rotation_degrees = Vector3(-90,0,0)

		if highlighter.get_material_override() is ShaderMaterial:
			var mat = highlighter.get_material_override() as ShaderMaterial
			mat.set_shader_parameter("outline_color", reachable_tile_color)
			mat.set_shader_parameter("outline_thickness", outline_thickness * 0.8) # Maybe thinner for reachable
		highlighter.visible = true


func _input(event):
	# ... (Same test input as before) ...
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_KP_ADD:
			outline_thickness = min(0.25, outline_thickness + 0.01)
			print_debug("Outline thickness: ", outline_thickness)
		elif event.keycode == KEY_KP_SUBTRACT:
			outline_thickness = max(0.005, outline_thickness - 0.01)
			print_debug("Outline thickness: ", outline_thickness)
