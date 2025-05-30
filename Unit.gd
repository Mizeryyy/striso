# res://units/unit.gd
extends CharacterBody3D
class_name Unit

signal health_changed(current_health, max_health)
signal unit_died(unit_instance)

const AssetUtils_Script = preload("res://map_generation/asset_utilities.gd") # !!! ADJUST PATH IF NEEDED !!!

@export var unit_data_resource: UnitData

@onready var mesh_root: Node3D = $MeshRoot
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var collision_shape_node: CollisionShape3D = $CollisionShape3D
@onready var interaction_area: Area3D = $InteractionArea

var current_health: int
var current_grid_coords: Vector2i # Anchor tile of the unit's footprint
var _model_instance: Node3D
var _current_tile_dimensions_world: Vector3
var _map_generator_ref: Node # To store reference to MapGenerator for accessing tile data

const MOVEMENT_SPEED: float = 5.0

func _ready():
	print_debug("Unit.gd (", name, "): _ready() called.")
	if not AssetUtils_Script:
		printerr("Unit.gd (", name, "): CRITICAL - Failed to preload AssetUtils_Script. Check path in Unit.gd.")

	if is_instance_valid(navigation_agent):
		navigation_agent.velocity_computed.connect(_on_navigation_agent_velocity_computed)
		navigation_agent.target_reached.connect(_on_navigation_agent_target_reached)

func _physics_process(delta: float):
	# ... (physics process logic remains the same as the last version) ...
	if not is_instance_valid(navigation_agent) or navigation_agent.is_target_reached():
		if velocity.length_squared() > 0.001: 
			velocity = Vector3.ZERO
			move_and_slide()
		return

	if navigation_agent.is_navigation_finished(): 
		if velocity.length_squared() > 0.001:
			velocity = Vector3.ZERO
			move_and_slide()
		return

	var current_agent_position: Vector3 = global_transform.origin
	var next_path_position: Vector3 = navigation_agent.get_next_path_position()
	var new_velocity: Vector3 = (next_path_position - current_agent_position).normalized() * MOVEMENT_SPEED
	
	if new_velocity.length_squared() > 0.01:
		var look_target = global_position + new_velocity
		if look_target.distance_squared_to(global_position) > 0.0001:
			look_at(look_target, Vector3.UP)
	navigation_agent.set_velocity(new_velocity)


func initialize_unit(p_unit_data: UnitData, 
					 p_anchor_grid_coords: Vector2i, # Renamed for clarity
					 p_world_position: Vector3, 
					 p_tile_dimensions: Vector3,
					 p_map_generator: Node): # Added map_generator reference
	print_debug("Unit.gd (", name, "): initialize_unit called with UnitData: ", p_unit_data.unit_name if p_unit_data else "NULL")
	if not p_unit_data:
		printerr("Unit.initialize_unit: Invalid UnitData provided for unit '", name, "'.")
		return
	if p_tile_dimensions == Vector3.ZERO:
		printerr("Unit.initialize_unit: Invalid tile_dimensions (ZERO) provided for unit '", name, "'.")
		return
	if not is_instance_valid(p_map_generator):
		printerr("Unit.initialize_unit: Invalid map_generator reference provided for unit '", name, "'.")
		return

	unit_data_resource = p_unit_data
	current_grid_coords = p_anchor_grid_coords # Store the anchor tile
	global_position = p_world_position
	_current_tile_dimensions_world = p_tile_dimensions
	_map_generator_ref = p_map_generator # Store map generator reference

	if not is_node_ready():
		print_debug("Unit.gd (", name, "): initialize_unit - awaiting ready.")
		await ready
	print_debug("Unit.gd (", name, "): initialize_unit - node is ready.")

	current_health = unit_data_resource.max_health
	_setup_model()
	_setup_collision()
	name = unit_data_resource.unit_name + "_" + str(get_instance_id())
	emit_signal("health_changed", current_health, unit_data_resource.max_health)
	print_debug("Unit.gd (", name, "): Initialization complete. Health: ", current_health)


func _setup_model():
	# ... (this function remains the same as the last version, using AssetUtils_Script) ...
	print_debug("Unit.gd (", name, "): _setup_model called.")
	if not unit_data_resource or not is_instance_valid(mesh_root):
		print_debug("Unit _setup_model: No unit_data_resource or mesh_root. Skipping.")
		return

	if is_instance_valid(_model_instance):
		_model_instance.queue_free()
		_model_instance = null
		print_debug("Unit _setup_model: Cleared previous _model_instance.")

	if unit_data_resource.model_scene:
		print_debug("Unit _setup_model: Attempting to instantiate model: ", unit_data_resource.model_scene.resource_path)
		_model_instance = unit_data_resource.model_scene.instantiate()
		if _model_instance:
			print_debug("Unit _setup_model: Model instantiated. Parent: ", mesh_root.name)
			mesh_root.add_child(_model_instance)
			
			if AssetUtils_Script:
				print_debug("Unit _setup_model: AssetUtils_Script is loaded and valid.")
				print_debug("Unit _setup_model: Calling AssetUtils_Script.scale_node_to_footprint_tiles for '", _model_instance.name, 
							"' with footprint: ", unit_data_resource.footprint_size, 
							" and tile_dims: ", _current_tile_dimensions_world)
				AssetUtils_Script.scale_node_to_footprint_tiles( 
					_model_instance, 
					unit_data_resource.footprint_size,
					_current_tile_dimensions_world 
				)
			else:
				printerr("Unit _setup_model: FAILED TO LOAD AssetUtils_Script. Skipping model scaling.")
		else:
			printerr("Unit _setup_model: Failed to instantiate model scene: ", unit_data_resource.model_scene.resource_path)
	else:
		if is_instance_valid(mesh_root) and mesh_root.get_child_count() > 0 and mesh_root.get_child(0) is Node3D:
			_model_instance = mesh_root.get_child(0)
			print_debug("Unit _setup_model: Using placeholder model '", _model_instance.name, "' in MeshRoot.")
		else:
			print_debug("Unit _setup_model: No model_scene in UnitData and no placeholder in MeshRoot.")


func _setup_collision():
	# ... (this function remains the same as the last version, using AssetUtils_Script for AABB) ...
	print_debug("Unit.gd (", name, "): _setup_collision called.")
	if not unit_data_resource or not is_instance_valid(collision_shape_node) or _current_tile_dimensions_world == Vector3.ZERO:
		print_debug("Unit _setup_collision: Pre-checks failed. Skipping.")
		return

	var tile_dims = _current_tile_dimensions_world
	var footprint = unit_data_resource.footprint_size
	var unit_target_height = 1.8 

	if is_instance_valid(_model_instance):
		if _model_instance.is_inside_tree(): _model_instance.force_update_transform()
		if AssetUtils_Script: 
			var model_local_aabb = AssetUtils_Script.get_node_visual_aabb_recursive(_model_instance, Transform3D.IDENTITY)
			if model_local_aabb.size.y > 0.01:
				unit_target_height = model_local_aabb.size.y
				print_debug("Unit _setup_collision: Using scaled model height: ", unit_target_height)
			else:
				print_debug("Unit _setup_collision: Scaled model height negligible. Using default height: ", unit_target_height)
		else:
			print_debug("Unit _setup_collision: AssetUtils_Script not available for AABB. Using default height.")
	else:
		print_debug("Unit _setup_collision: _model_instance not valid. Using default height: ", unit_target_height)

	if collision_shape_node.shape is BoxShape3D:
		var box_shape = collision_shape_node.shape as BoxShape3D
		box_shape.size = Vector3( footprint.x * tile_dims.x, unit_target_height, footprint.y * tile_dims.z )
		collision_shape_node.position.y = unit_target_height / 2.0
		print_debug("Unit _setup_collision: BoxShape size: ", box_shape.size, " pos.y: ", collision_shape_node.position.y)
	elif collision_shape_node.shape is CapsuleShape3D:
		var capsule_shape = collision_shape_node.shape as CapsuleShape3D
		var radius = min(footprint.x * tile_dims.x, footprint.y * tile_dims.z) / 2.0; radius = max(0.01, radius)
		var capsule_cylinder_height = max(0.01, unit_target_height - (2.0 * radius))
		capsule_shape.radius = radius; capsule_shape.height = capsule_cylinder_height
		collision_shape_node.position.y = (capsule_cylinder_height / 2.0) + radius
		print_debug("Unit _setup_collision: CapsuleShape radius: ", radius, " height: ", capsule_cylinder_height, " pos.y: ", collision_shape_node.position.y)
	else:
		print_debug("Unit _setup_collision: CollisionShape is not Box or Capsule.")


func take_damage(amount: int):
	if not unit_data_resource: return
	current_health = max(0, current_health - amount)
	print_debug("Unit.gd (", name, "): Took ", amount, " damage. Health now: ", current_health)
	emit_signal("health_changed", current_health, unit_data_resource.max_health)
	if current_health <= 0:
		die()

func die():
	print_debug("Unit.gd (", name, "): die() called. Clearing occupation.")
	
	# --- CLEAR OCCUPIED TILES ---
	if is_instance_valid(_map_generator_ref) and unit_data_resource and \
	   _map_generator_ref.has_method("get_tile_data_at"): # Check method exists
		var unit_footprint: Vector2i = unit_data_resource.footprint_size
		# current_grid_coords is the anchor of the footprint
		for dx in range(unit_footprint.x):
			for dz in range(unit_footprint.y):
				var tile_coord_to_clear = current_grid_coords + Vector2i(dx, dz)
				# Also ensure map_generator can validate coords if needed, or do it here
				# if _map_generator_ref.has_method("is_valid_coord") and not _map_generator_ref.is_valid_coord(tile_coord_to_clear.x, tile_coord_to_clear.y):
				#    continue

				var tile_data = _map_generator_ref.get_tile_data_at(tile_coord_to_clear)
				if tile_data:
					# Only clear if this unit was indeed the occupant
					if tile_data.occupant == self:
						print_debug("Unit.gd (", name, "): Clearing occupation from tile ", tile_coord_to_clear)
						tile_data.occupant = null
						tile_data.walkable = true # Make it walkable again
						# If you used has_structure: tile_data.has_structure = false
						# TODO: Notify Pathfinder to update this tile's walkability if necessary
					elif tile_data.occupant != null:
						# This case should ideally not happen if logic is correct,
						# but good for debugging if another unit overwrote occupation.
						print_debug("Unit.gd (", name, "): Tile ", tile_coord_to_clear, " was occupied by someone else (", tile_data.occupant, ") or already clear.")
				else:
					print_debug("Unit.gd (", name, "): No tile data found at ", tile_coord_to_clear, " while trying to clear occupation.")
	else:
		printerr("Unit.gd (", name, "): Cannot clear occupation - _map_generator_ref invalid or no get_tile_data_at method.")
	# --- END CLEAR OCCUPIED TILES ---

	emit_signal("unit_died", self)
	queue_free() # Remove the unit from the scene

func _on_navigation_agent_velocity_computed(safe_velocity: Vector3):
	velocity = safe_velocity
	move_and_slide()

func _on_navigation_agent_target_reached():
	print_debug("Unit.gd (", name, "): Navigation agent reached target.")
	velocity = Vector3.ZERO
