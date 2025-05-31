# res://highlighter/HighlighterManager.gd
extends Node

# No TopFaceHighlighterScene preload needed anymore

@export_group("Outline Appearance")
@export var hover_outline_color: Color = Color(0.6, 0.6, 0.6, 0.75)
@export var unit_outline_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var outline_thickness: float = 0.08
@export var outline_shader_path: String = "res://outline.gdshader" # Export shader path

@onready var map_generator = get_node("/root/Main/MapGenerator") # !!! ADJUST PATH !!!
var camera: Camera3D
var world_3d_resource: World3D

var active_highlighter_mesh: MeshInstance3D = null # We'll create this in _ready
var outline_shader_material: ShaderMaterial = null # Store the material

var last_hovered_anchor_coords: Vector2i = Vector2i(-1000, -1000)
var last_hovered_is_unit: bool = false

func _ready():
	await get_tree().process_frame
	var current_viewport = get_viewport()
	if not is_instance_valid(current_viewport):
		printerr("HighlighterManager: Could not get viewport. Highlighter disabled.")
		set_physics_process(false); return

	camera = current_viewport.get_camera_3d()
	if not is_instance_valid(camera):
		printerr("HighlighterManager: Camera not found. Highlighter disabled.")
		set_physics_process(false); return

	world_3d_resource = current_viewport.world_3d
	if not is_instance_valid(world_3d_resource):
		printerr("HighlighterManager: Could not get World3D. Highlighter disabled.")
		set_physics_process(false); return

	if not is_instance_valid(map_generator):
		printerr("HighlighterManager: MapGenerator not found. Highlighter disabled.")
		set_physics_process(false); return
	
	# --- Create Highlighter Mesh Programmatically ---
	var loaded_shader = load(outline_shader_path)
	if not loaded_shader is Shader:
		printerr("HighlighterManager: Failed to load outline shader from path: '", outline_shader_path, "'. Highlighter will not work.")
		set_physics_process(false)
		return

	outline_shader_material = ShaderMaterial.new()
	outline_shader_material.shader = loaded_shader

	active_highlighter_mesh = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(1,1) # Base 1x1, will be scaled
	# PlaneMesh default orientation is XY plane. We rotate it in _update_highlighter.
	active_highlighter_mesh.mesh = plane_mesh
	active_highlighter_mesh.material_override = outline_shader_material # Use the created ShaderMaterial
	
	add_child(active_highlighter_mesh) # Add to this manager node
	active_highlighter_mesh.visible = false # Initially hidden
	# --- End Create Highlighter Mesh ---

	print_debug("HighlighterManager: Ready and highlighter mesh created.")


func _physics_process(delta: float):
	# ... (Raycasting logic remains exactly the same as the previous version) ...
	if not is_instance_valid(camera) or \
	   not is_instance_valid(map_generator) or \
	   not is_instance_valid(active_highlighter_mesh) or \
	   not is_instance_valid(world_3d_resource) or \
	   not is_instance_valid(outline_shader_material): # Check material too
		if is_instance_valid(active_highlighter_mesh): active_highlighter_mesh.visible = false
		return

	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	
	var space_state = world_3d_resource.direct_space_state 
	if not is_instance_valid(space_state):
		if is_instance_valid(active_highlighter_mesh): active_highlighter_mesh.visible = false
		return

	var params = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 1000.0)
	var collision_mask_value = 1 
	if map_generator.has_meta("TERRAIN_COLLISION_LAYER"):
		collision_mask_value = map_generator.get_meta("TERRAIN_COLLISION_LAYER")
	elif "TERRAIN_COLLISION_LAYER" in map_generator:
		collision_mask_value = map_generator.TERRAIN_COLLISION_LAYER
	else:
		print_debug("HighlighterManager: TERRAIN_COLLISION_LAYER not found on MapGenerator, using mask 1.")
	params.collision_mask = collision_mask_value
	
	var result = space_state.intersect_ray(params)

	var current_hovered_anchor_coords = Vector2i(-1000, -1000)
	var current_is_unit_hover = false
	var unit_footprint = Vector2i(1,1)
	var unit_instance: Unit = null # To avoid repeated casting

	if result:
		var hit_pos = result.position
		var grid_coords_hit = map_generator.world_to_grid_coords_snapped(hit_pos)

		if map_generator.is_valid_coord(grid_coords_hit.x, grid_coords_hit.y):
			var tile_data = map_generator.get_tile_data_at(grid_coords_hit)
			if tile_data and tile_data.tile_type != "water":
				if is_instance_valid(tile_data.occupant) and tile_data.occupant is Unit:
					unit_instance = tile_data.occupant as Unit
					current_hovered_anchor_coords = unit_instance.current_grid_coords
					if unit_instance.unit_data_resource: # Null check for safety
						unit_footprint = unit_instance.unit_data_resource.footprint_size
					current_is_unit_hover = true
				else:
					current_hovered_anchor_coords = grid_coords_hit
					unit_footprint = Vector2i(1,1)
					current_is_unit_hover = false
	
	if current_hovered_anchor_coords != last_hovered_anchor_coords or current_is_unit_hover != last_hovered_is_unit:
		if current_hovered_anchor_coords != Vector2i(-1000, -1000):
			_update_highlighter(current_hovered_anchor_coords, unit_footprint, current_is_unit_hover)
		else:
			if is_instance_valid(active_highlighter_mesh): active_highlighter_mesh.visible = false

		last_hovered_anchor_coords = current_hovered_anchor_coords
		last_hovered_is_unit = current_is_unit_hover
	elif not is_instance_valid(active_highlighter_mesh) or not active_highlighter_mesh.visible:
		if current_hovered_anchor_coords != Vector2i(-1000, -1000):
			_update_highlighter(current_hovered_anchor_coords, unit_footprint, current_is_unit_hover)


func _update_highlighter(anchor_coords: Vector2i, footprint_size: Vector2i, is_unit: bool):
	if not is_instance_valid(active_highlighter_mesh) or \
	   not is_instance_valid(map_generator) or \
	   not is_instance_valid(outline_shader_material):
		if is_instance_valid(active_highlighter_mesh): active_highlighter_mesh.visible = false
		return

	var tile_dims: Vector3 = map_generator.current_tile_dimensions
	if tile_dims == Vector3.ZERO: 
		active_highlighter_mesh.visible = false
		return

	var footprint_world_width = float(footprint_size.x) * tile_dims.x
	var footprint_world_depth = float(footprint_size.y) * tile_dims.z

	var center_x = (float(anchor_coords.x) + float(footprint_size.x) / 2.0) * tile_dims.x
	var center_z = (float(anchor_coords.y) + float(footprint_size.y) / 2.0) * tile_dims.z
	
	var anchor_tile_data = map_generator.get_tile_data_at(anchor_coords)
	if not anchor_tile_data: 
		active_highlighter_mesh.visible = false
		return
	var top_y = anchor_tile_data.position.y + (tile_dims.y / 2.0) +0.1

	active_highlighter_mesh.global_position = Vector3(center_x, top_y, center_z)
	active_highlighter_mesh.scale = Vector3(footprint_world_width, 1.0, footprint_world_depth)
	#active_highlighter_mesh.rotation_degrees = Vector3(-90, 0, 0) # Rotate plane to be flat on XZ

	# Update shader material uniforms
	outline_shader_material.set_shader_parameter("outline_color", unit_outline_color if is_unit else hover_outline_color)
	outline_shader_material.set_shader_parameter("outline_thickness", outline_thickness)
	
	active_highlighter_mesh.visible = true


func _input(event): # For quick testing of parameters
	# ... (Same as previous version) ...
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_KP_ADD:
			outline_thickness = min(0.25, outline_thickness + 0.01)
			print_debug("Outline thickness: ", outline_thickness)
		elif event.keycode == KEY_KP_SUBTRACT:
			outline_thickness = max(0.005, outline_thickness - 0.01)
			print_debug("Outline thickness: ", outline_thickness)
