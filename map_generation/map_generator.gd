# map_generator.gd
extends Node3D
signal map_fully_ready

const BASE_TILE_DIMENSIONS := Vector3(1.0, 0.5, 1.0)
const TERRAIN_COLLISION_LAYER = 1 # Public for HighlighterManager & tile bodies

# --- Script Resource Exports ---
@export_group("Script Dependencies")
@export var asset_utilities_script: Script
@export var custom_tile_data_script: Script
@export var structure_data_script: Script
@export var map_data_manager_script: Script
@export var terrain_shaper_script: Script

# --- Cached Script Class References ---
var AssetUtilities_C
var CustomTileData_C
var StructureData_C
var MapDataManager_C
var TerrainShaper_C

# --- All @export variables (Copied from your provided script) ---
@export_group("Map Configuration")
@export var map_width: int = 200
@export var map_depth: int = 200
@export var seed: int = 0
@export_range(0.01, 1.0, 0.01) var tile_scale_factor: float = 0.1
@export_range(1, 50, 1) var max_generation_height_levels := 25

@export_group("Island Configuration")
@export_range(0, 50, 1) var water_border_width: int = 10
@export_range(0.0, 1.0, 0.05) var coastal_indent_strength_factor: float = 0.8
@export_range(0.05, 0.7, 0.01) var coastal_indent_noise_freq_mult: float = 0.25
@export_range(0.1, 0.8, 0.05) var coastal_inland_reach_percent: float = 0.5
@export_range(0.05, 0.7, 0.01) var coastal_reach_noise_freq_mult: float = 0.35

@export_group("Global Height Smoothing")
@export_range(1, 10, 1) var height_clamp_passes: int = 4

@export_group("Noise Parameters")
@export var noise_scale: float = 0.008
@export var moisture_noise_scale: float = 0.01
@export var mountain_spike_noise_frequency: float = 0.1
@export_range(0.0, 0.3, 0.01) var mountain_spike_strength: float = 0.05
@export var rock_cluster_noise_scale: float = 0.05

@export_group("Transition Rings & Shoreline (Inland/Beach)")
@export_range(0, 5, 1) var land_transition_passes: int = 3
@export_range(0.1, 0.7, 0.05) var land_transition_step_factor: float = 0.33
@export_range(0, 7, 1) var shoreline_width: int = 3
@export_range(0.1, 0.7, 0.05) var beach_slope_noise_strength: float = 0.5

@export_group("Tile Classification & Water Level")
@export_range(0.0, 1.0, 0.01) var water_threshold_norm: float = 0.3
@export_range(0.0, 1.0, 0.01) var flat_water_visual_norm_height: float = 0.2
@export_range(0.0, 1.0, 0.01) var mountain_threshold_norm: float = 0.6
@export_range(0.0, 1.0, 0.01) var forest_moisture_threshold_norm: float = 0.6

@export_group("Tile Textures (Optional)")
@export var grass_texture: Texture2D = null
@export var water_texture: Texture2D = null
@export var mountain_texture: Texture2D = null
@export var forest_texture: Texture2D = null

@export_group("Foliage & Props (Flowers, Trees, Rocks)")
@export var foliage_parent_node: Node3D = null
@export var flower_scene_variants: Array[PackedScene] = []
@export_range(0.0, 1.0, 0.001) var grass_tile_flower_chance: float = 0.03
@export var plains_tree_scene_variants: Array[PackedScene] = []
@export_range(0.0, 1.0, 0.001) var grass_tile_plains_tree_chance: float = 0.005
@export var tree_scene_variants: Array[PackedScene] = []
@export_range(0.0, 1.0, 0.001) var forest_tile_tree_chance: float = 0.7
@export var large_rock_cluster_scene_variants: Array[PackedScene] = []
@export_range(0.0, 1.0, 0.01) var rock_cluster_threshold: float = 0.7
@export_range(0.0, 0.5, 0.01) var major_prop_max_offset_factor: float = 0.3

@export_group("Castle Configuration")
@export var castle_1_scene: PackedScene = null
@export var castle_2_scene: PackedScene = null
@export_range(1, 20, 1) var castle_tile_radius: int = 7
@export_range(1, 25, 1) var castle_flatten_radius_tiles: int = 12
@export_range(1, 30, 1) var castle_prop_removal_radius_tiles: int = 15
@export_range(0, 50, 1) var castle_edge_margin_tiles: int = 20
@export_range(1, 10, 1) var castle_water_avoid_radius_tiles: int = 7
@export_range(0.0, 0.49, 0.01) var castle_zone_1_y_start_factor: float = 0.1
@export_range(0.0, 0.49, 0.01) var castle_zone_1_y_end_factor: float = 0.3
@export_range(0.51, 1.0, 0.01) var castle_zone_2_y_start_factor: float = 0.7
@export_range(0.51, 1.0, 0.01) var castle_zone_2_y_end_factor: float = 0.9
@export_range(0.0, 2.0, 0.01) var castle_flatten_strength: float = 1.2
@export_range(1, 15, 1) var castle_corner_push_radius: int = 7
@export_range(0.01, 0.2, 0.01) var mountain_flatten_target_offset: float = 0.05

@export_group("Water Shader Configuration") # Kept for your custom water option
@export var use_custom_water_shader: bool = true
@export var water_shader_override: Shader = null
@export_range(0.1, 5.0, 0.1) var water_time_speed: float = 1.0
@export_range(0.1, 5.0, 0.1) var water_surface_speed: float = 1.0
@export_range(0.0, 1.0, 0.01) var water_spin: float = 0.05
@export_range(0.1, 2.0, 0.05) var water_brightness: float = 0.7
@export_range(-1.0, 1.0, 0.05) var water_color_intensity: float = 0.2
@export_range(0.5, 10.0, 0.1) var water_horizontal_frequency: float = 2.0
@export_range(0.5, 10.0, 0.1) var water_vertical_frequency: float = 2.0
@export_range(0.5, 10.0, 0.1) var water_size_param: float = 3.0
@export_range(0.1, 2.0, 0.05) var water_banding_bias: float = 0.6
@export_range(0.0, 0.5, 0.005) var water_wave_height: float = 0.02
@export_range(0.0, 0.5, 0.005) var water_texture_height: float = 0.01
@export var water_color1 : Color = Color(0.59, 0.761, 1.0, 1.0)
@export var water_color2 : Color = Color(0.274, 0.474, 0.98, 1.0)
@export var water_color3 : Color = Color(0.059, 0.389, 0.85, 1.0)
@export var water_color4 : Color = Color(0.0, 0.267, 1.0, 1.0)

# --- Materials (Standard materials for tiles) ---
var mat_grass_tile: StandardMaterial3D
var mat_water: Material # Can be StandardMaterial3D or your custom ShaderMaterial
var mat_mountain_tile: StandardMaterial3D
var mat_forest_tile: StandardMaterial3D
var mat_default_tile: StandardMaterial3D # Fallback
var wave_noise_tex: NoiseTexture2D # For custom water
var detail_noise_tex: NoiseTexture2D # For custom water

# --- Current State ---
var current_tile_dimensions: Vector3 # Public, set in generate_new_world

# --- Noise Instances ---
var height_noise: FastNoiseLite; var moisture_noise: FastNoiseLite
var mountain_spike_noise: FastNoiseLite; var rock_density_noise: FastNoiseLite
var coastline_detail_noise: FastNoiseLite; var coastal_indent_noise: FastNoiseLite
var coastal_reach_noise: FastNoiseLite

# --- Child Node References ---
@onready var tiles_node: Node3D = $Tiles
@onready var castles_node: Node3D = $Castles
@onready var structures_node: Node3D = $Structures
var props_node: Node3D

# --- Game State ---
var _castle1_site_coord := Vector2i(-1,-1); var _castle2_site_coord := Vector2i(-1,-1)
var available_structures: Dictionary = {}
var placed_structures_map: Dictionary = {}
var tile_mesh_nodes: Dictionary = {} # Stores StaticBody3D of individual non-merged tiles

# --- Modular Components ---
var map_data_manager: MapDataManager
var terrain_shaper: TerrainShaper

# --- Helper Math Functions ---
func smoothstep_value(val: float) -> float:
	var t = clamp(val, 0.0, 1.0); return t * t * (3.0 - 2.0 * t)
func inverse_lerp_clamped(a: float, b: float, v: float) -> float:
	if abs(b - a) < 0.00001: return 0.0 if v < a else 1.0
	return clamp((v - a) / (b - a), 0.0, 1.0)

func _get_script_class_from_export(script_resource: Script, default_path: String = "", class_identifier: String = "") -> Script:
	if script_resource and script_resource is Script: return script_resource
	elif default_path != "":
		var loaded_script = load(default_path)
		if loaded_script and loaded_script is Script: return loaded_script
		else: printerr("MapGen: CRITICAL - Failed script load for '", class_identifier,"' from: ", default_path); return null
	printerr("MapGen: CRITICAL - Script for '", class_identifier,"' not assigned and no default path."); return null

func _ready():
	print_debug("MapGenerator.gd: _ready() STARTED.")

	AssetUtilities_C = _get_script_class_from_export(asset_utilities_script, "res://asset_utilities.gd", "AssetUtilities")
	CustomTileData_C = _get_script_class_from_export(custom_tile_data_script, "res://custom_tile_data.gd", "CustomTileData")
	StructureData_C = _get_script_class_from_export(structure_data_script, "res://structures/structure_data.gd", "StructureData")
	MapDataManager_C = _get_script_class_from_export(map_data_manager_script, "res://map_generation/map_data_manager.gd", "MapDataManager")
	TerrainShaper_C = _get_script_class_from_export(terrain_shaper_script, "res://map_generation/terrain_shaper.gd", "TerrainShaper")

	if not AssetUtilities_C or not CustomTileData_C or not StructureData_C or not MapDataManager_C or not TerrainShaper_C:
		printerr("MapGenerator: Critical script deps failed. Aborting."); set_process(false); set_physics_process(false); return

	if not is_instance_valid(tiles_node): tiles_node = Node3D.new(); tiles_node.name = "Tiles"; add_child(tiles_node)
	if not is_instance_valid(castles_node): castles_node = Node3D.new(); castles_node.name = "Castles"; add_child(castles_node)
	if not is_instance_valid(structures_node): structures_node = Node3D.new(); structures_node.name = "Structures"; add_child(structures_node)
	if foliage_parent_node and is_instance_valid(foliage_parent_node): props_node = foliage_parent_node
	else:
		props_node = get_node_or_null("Props")
		if not is_instance_valid(props_node): props_node = Node3D.new(); props_node.name = "Props"; add_child(props_node)
	
	_initialize_noise_instances()
	_initialize_tile_materials() # Sets up mat_grass_tile, mat_water, etc.
	load_available_structures()

	map_data_manager = MapDataManager_C.new()
	var terrain_shaper_config = {
		"water_threshold_norm": water_threshold_norm, "mountain_threshold_norm": mountain_threshold_norm,
		"forest_moisture_threshold_norm": forest_moisture_threshold_norm,
		"flat_water_visual_norm_height": flat_water_visual_norm_height,
		"water_border_width": water_border_width, "coastal_indent_strength_factor": coastal_indent_strength_factor,
		"coastal_inland_reach_percent": coastal_inland_reach_percent, "shoreline_width": shoreline_width,
		"beach_slope_noise_strength": beach_slope_noise_strength, "land_transition_passes": land_transition_passes,
		"land_transition_step_factor": land_transition_step_factor, "mountain_spike_strength": mountain_spike_strength,
		"height_clamp_passes": height_clamp_passes, "max_generation_height_levels": max_generation_height_levels
	}
	var noises_for_shaper = {
		"height_noise": height_noise, "moisture_noise": moisture_noise, "mountain_spike_noise": mountain_spike_noise,
		"coastline_detail_noise": coastline_detail_noise, "coastal_indent_noise": coastal_indent_noise,
		"coastal_reach_noise": coastal_reach_noise
	}
	terrain_shaper = TerrainShaper_C.new(map_data_manager, terrain_shaper_config, noises_for_shaper)
	
	generate_new_world()
	print_debug("MapGenerator.gd: _ready() FINISHED.")

func _initialize_noise_instances():
	height_noise = FastNoiseLite.new(); height_noise.seed = seed; height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH; height_noise.frequency = noise_scale
	moisture_noise = FastNoiseLite.new(); moisture_noise.seed = seed + 1; moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH; moisture_noise.frequency = moisture_noise_scale
	mountain_spike_noise = FastNoiseLite.new(); mountain_spike_noise.seed = seed + 2; mountain_spike_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH; mountain_spike_noise.frequency = mountain_spike_noise_frequency
	rock_density_noise = FastNoiseLite.new(); rock_density_noise.seed = seed + 3; rock_density_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH; rock_density_noise.frequency = rock_cluster_noise_scale
	coastline_detail_noise = FastNoiseLite.new(); coastline_detail_noise.seed = seed + 4; coastline_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX; coastline_detail_noise.frequency = noise_scale * 6.0
	coastal_indent_noise = FastNoiseLite.new(); coastal_indent_noise.seed = seed + 6; coastal_indent_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX; coastal_indent_noise.frequency = noise_scale * coastal_indent_noise_freq_mult
	coastal_reach_noise = FastNoiseLite.new(); coastal_reach_noise.seed = seed + 7; coastal_reach_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX; coastal_reach_noise.frequency = noise_scale * coastal_reach_noise_freq_mult

func _initialize_tile_materials():
	var uv_scale_vector = Vector3(1.0, 1.0, 1.0)

	mat_grass_tile = StandardMaterial3D.new()
	if grass_texture: mat_grass_tile.albedo_texture = grass_texture; mat_grass_tile.uv1_scale = uv_scale_vector
	else: mat_grass_tile.albedo_color = Color.GREEN
	

	
	if not use_custom_water_shader or not is_instance_valid(mat_water): # Fallback or if custom disabled
		var std_water_mat = StandardMaterial3D.new()
		if water_texture:
			std_water_mat.albedo_texture = water_texture; std_water_mat.uv1_scale = uv_scale_vector
			if water_texture.has_alpha(): std_water_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
			else: std_water_mat.albedo_color.a = 0.7; std_water_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA # Default alpha
			std_water_mat.albedo_color = Color(1,1,1, std_water_mat.albedo_color.a) # Ensure texture alpha is used with white base
		else:
			std_water_mat.albedo_color = Color(0.2, 0.3, 0.8, 0.7) # Default blue, semi-transparent
			std_water_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		mat_water = std_water_mat

	mat_mountain_tile = StandardMaterial3D.new()
	if mountain_texture: mat_mountain_tile.albedo_texture = mountain_texture; mat_mountain_tile.uv1_scale = uv_scale_vector
	else: mat_mountain_tile.albedo_color = Color.DIM_GRAY
	
	mat_forest_tile = StandardMaterial3D.new()
	if forest_texture: mat_forest_tile.albedo_texture = forest_texture; mat_forest_tile.uv1_scale = uv_scale_vector
	else: mat_forest_tile.albedo_color = Color.DARK_GREEN
	
	mat_default_tile = StandardMaterial3D.new()
	mat_default_tile.albedo_color = Color.MAGENTA

func load_available_structures():
	if not StructureData_C: printerr("StructureData_C script not loaded!"); available_structures.clear(); return
	available_structures.clear(); var dir_path = "res://structures/data/"
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin(); var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var full_file_path = dir_path.path_join(file_name); var structure_data_res = load(full_file_path)
				if structure_data_res and structure_data_res.get_script() == StructureData_C :
					var casted_s_data = structure_data_res as StructureData
					if casted_s_data.id != &"": available_structures[casted_s_data.id] = casted_s_data
			file_name = dir.get_next()
		dir.list_dir_end()
	print("MapGenerator: Finished loading structures. Count: ", available_structures.size())

func generate_new_world():
	print_debug("MapGenerator.gd: generate_new_world() STARTED.")
	if not CustomTileData_C or not MapDataManager_C or not TerrainShaper_C:
		printerr("MapGenerator: Critical script classes not loaded. Aborting generation.")
		return
	if not mat_grass_tile: _initialize_tile_materials() # Ensure materials are ready
	if available_structures.is_empty() and DirAccess.dir_exists_absolute("res://structures/data/"): load_available_structures()

	if max_generation_height_levels < 1: max_generation_height_levels = 1
	_castle1_site_coord = Vector2i(-1,-1); _castle2_site_coord = Vector2i(-1,-1)
	current_tile_dimensions = BASE_TILE_DIMENSIONS * tile_scale_factor
		
	for child in tiles_node.get_children(): child.queue_free()
	tile_mesh_nodes.clear()
	for child in castles_node.get_children(): child.queue_free()
	for child in structures_node.get_children(): child.queue_free()
	if is_instance_valid(props_node): _clear_all_props_from_node()
	placed_structures_map.clear()

	map_data_manager.initialize_arrays(map_width, map_depth)

	terrain_shaper.generate_base_height_noise()
	terrain_shaper.reshape_coastline()
	terrain_shaper.determine_initial_tile_types()
	terrain_shaper.generate_shoreline_rings()
	terrain_shaper.initialize_visual_heightmap_from_shores()
	terrain_shaper.smooth_land_transitions()
	terrain_shaper.apply_mountain_spikes()
	
	var sites = _find_castle_placement_sites()
	if sites.size() == 2:
		_castle1_site_coord = sites[0]; _castle2_site_coord = sites[1]
		_modify_terrain_and_clear_props_for_area(_castle1_site_coord, castle_flatten_radius_tiles, castle_flatten_strength, -1.0, castle_prop_removal_radius_tiles, true)
		_modify_terrain_and_clear_props_for_area(_castle2_site_coord, castle_flatten_radius_tiles, castle_flatten_strength, -1.0, castle_prop_removal_radius_tiles, true)
	
	terrain_shaper.apply_global_height_clamp()

	for x_tdm in range(map_width):
		for z_tdm in range(map_depth):
			var coord = Vector2i(x_tdm,z_tdm)
			var type_str = map_data_manager.final_tile_type_map[x_tdm][z_tdm]
			var final_norm_h = map_data_manager.visual_normalized_height_map[x_tdm][z_tdm]
			var gameplay_level = int(clamp(round(final_norm_h * max_generation_height_levels), 0.0, float(max_generation_height_levels - 1)))
			var tile_data: CustomTileData = setup_tile_data_from_type(type_str, gameplay_level)
			if not tile_data: continue
			tile_data.grid_coords = coord
			var visual_top_y = final_norm_h * (float(max_generation_height_levels) * current_tile_dimensions.y)
			tile_data.position = Vector3( (float(x_tdm) + 0.5) * current_tile_dimensions.x, visual_top_y - (current_tile_dimensions.y * 0.5), (float(z_tdm) + 0.5) * current_tile_dimensions.z)
			map_data_manager.set_tile_data_at(coord, tile_data)

	_generate_all_tile_meshes_individually_and_water_bodies()
	
	_place_castle_models(_castle1_site_coord, _castle2_site_coord)
	_place_all_foliage_props()
	
	print("World generation complete.")
	var pathfinder_node = get_node_or_null("../Pathfinder")
	if is_instance_valid(pathfinder_node) and pathfinder_node.has_method("set_map_data"):
		print_debug("MapGenerator.gd: Updating Pathfinder before emitting signal.")
		pathfinder_node.set_map_data(map_data_manager.grid, Vector2i(map_width, map_depth), current_tile_dimensions)
	else:
		print_debug("MapGenerator.gd: Pathfinder node not found or no set_map_data method.")
	
	print_debug("MapGenerator.gd: generate_new_world() FINISHED. About to emit 'map_fully_ready'.")
	call_deferred("emit_signal", "map_fully_ready")
	print_debug("MapGenerator.gd: 'map_fully_ready' signal emission was DEFERRED.")

func _generate_all_tile_meshes_individually_and_water_bodies():
	tile_mesh_nodes.clear()
	var water_component_visited_flags: Array = []
	if map_width > 0: water_component_visited_flags.resize(map_width)
	for x_wcv_init in range(map_width):
		water_component_visited_flags[x_wcv_init] = []
		if map_depth > 0: water_component_visited_flags[x_wcv_init].resize(map_depth); water_component_visited_flags[x_wcv_init].fill(false)
	
	for z_water_scan in range(map_depth):
		for x_water_scan in range(map_width):
			var current_scan_coord = Vector2i(x_water_scan, z_water_scan)
			if not water_component_visited_flags[current_scan_coord.x][current_scan_coord.y]:
				var tile_data_w: CustomTileData = get_tile_data_at(current_scan_coord)
				if tile_data_w and tile_data_w.tile_type == "water":
					var current_water_component_coords: Array[Vector2i] = []
					_flood_fill_water_component(current_scan_coord, current_water_component_coords, water_component_visited_flags)
					if not current_water_component_coords.is_empty():
						var min_x = map_width; var max_x = -1; var min_z = map_depth; var max_z_val = -1
						var first_tile_in_comp: CustomTileData = get_tile_data_at(current_water_component_coords[0])
						if not first_tile_in_comp: continue
						var water_y = first_tile_in_comp.position.y
						for coord_in_comp in current_water_component_coords:
							min_x = min(min_x, coord_in_comp.x); max_x = max(max_x, coord_in_comp.x)
							min_z = min(min_z, coord_in_comp.y); max_z_val = max(max_z_val, coord_in_comp.y)
							tile_mesh_nodes[coord_in_comp] = true # Mark as part of a merged body
						_create_tile_mesh_body(min_x, min_z, max_x - min_x + 1, max_z_val - min_z + 1, "water", water_y, true)

	for x in range(map_width):
		for z in range(map_depth):
			var coord = Vector2i(x,z)
			if tile_mesh_nodes.has(coord) and tile_mesh_nodes[coord] is bool and tile_mesh_nodes[coord] == true:
				continue
			var tile_data: CustomTileData = get_tile_data_at(coord)
			if tile_data:
				_create_tile_mesh_body(x, z, 1, 1, tile_data.tile_type, tile_data.position.y, false, coord)

func _create_tile_mesh_body(grid_x: int, grid_z: int, width_in_tiles: int, depth_in_tiles: int, tile_type: String, tile_y_center: float, is_water_body: bool = false, single_tile_coord_key: Vector2i = Vector2i(-1,-1)):
	var tile_body = StaticBody3D.new()
	tile_body.collision_layer = TERRAIN_COLLISION_LAYER
	var mesh_inst = MeshInstance3D.new()
	var box_m = BoxMesh.new()
	
	var mesh_world_width = float(width_in_tiles) * current_tile_dimensions.x
	var mesh_world_depth = float(depth_in_tiles) * current_tile_dimensions.z
	box_m.size = Vector3(mesh_world_width, current_tile_dimensions.y, mesh_world_depth)
	mesh_inst.mesh = box_m

	match tile_type:
		"grass":
			mesh_inst.material_override = mat_grass_tile if is_instance_valid(mat_grass_tile) else mat_default_tile
		"water":
			mesh_inst.material_override = mat_water if is_instance_valid(mat_water) else mat_default_tile
		"mountain":
			mesh_inst.material_override = mat_mountain_tile if is_instance_valid(mat_mountain_tile) else mat_default_tile
		"forest_grass":
			mesh_inst.material_override = mat_forest_tile if is_instance_valid(mat_forest_tile) else mat_default_tile
		_:
			mesh_inst.material_override = mat_default_tile if is_instance_valid(mat_default_tile) else StandardMaterial3D.new()

	tile_body.add_child(mesh_inst)
	var col_shape = CollisionShape3D.new(); var box_s = BoxShape3D.new()
	box_s.size = box_m.size; col_shape.shape = box_s
	tile_body.add_child(col_shape)
	
	tiles_node.add_child(tile_body)
	
	var center_x_world = (float(grid_x) * current_tile_dimensions.x) + (mesh_world_width / 2.0)
	var center_z_world = (float(grid_z) * current_tile_dimensions.z) + (mesh_world_depth / 2.0)
	tile_body.global_position = Vector3(center_x_world, tile_y_center, center_z_world)
	
	if not is_water_body or (is_water_body and width_in_tiles == 1 and depth_in_tiles == 1): # Store individual tiles
		if single_tile_coord_key != Vector2i(-1,-1):
			tile_mesh_nodes[single_tile_coord_key] = tile_body

func _update_tile_mesh_at(coord: Vector2i):
	if not is_valid_coord(coord.x, coord.y): return
	if tile_mesh_nodes.has(coord):
		var old_node = tile_mesh_nodes[coord]
		if is_instance_valid(old_node) and old_node is Node:
			old_node.queue_free()
		tile_mesh_nodes.erase(coord)
	
	var tile_data: CustomTileData = get_tile_data_at(coord)
	if tile_data:
		_create_tile_mesh_body(coord.x, coord.y, 1, 1, tile_data.tile_type, tile_data.position.y, (tile_data.tile_type == "water"), coord)
		# If you had logic to update outline shader for occupation here, it's removed
		# because HighlighterManager now handles hover/occupation visuals.

# --- PUBLIC METHODS ---
func get_tile_data_at(coords: Vector2i) -> CustomTileData:
	if map_data_manager: return map_data_manager.get_tile_data_at(coords) as CustomTileData
	# printerr("MapGenerator: map_data_manager not ready in get_tile_data_at for ", coords) # Less verbose
	return null

func is_valid_coord(x: int, z: int) -> bool:
	if map_data_manager:
		return map_data_manager.is_valid_coord(x, z)
	# printerr("MapGenerator: map_data_manager not ready in is_valid_coord.") # Less verbose
	return x >= 0 and x < map_width and z >= 0 and z < map_depth

func world_to_grid_coords_snapped(world_pos: Vector3) -> Vector2i:
	if current_tile_dimensions == Vector3.ZERO:
		printerr("MapGenerator: current_tile_dimensions not set for world_to_grid_coords_snapped.")
		return Vector2i(-1,-1)
	if current_tile_dimensions.x == 0.0 or current_tile_dimensions.z == 0.0: return Vector2i(-1,-1)
	return Vector2i(int(floor(world_pos.x / current_tile_dimensions.x)), int(floor(world_pos.z / current_tile_dimensions.z)))

# --- ALL OTHER ORIGINAL HELPER FUNCTIONS ---
# (setup_tile_data_from_type, _flood_fill_water_component,
#  _modify_terrain_and_clear_props_for_area, _remove_prop_at_tile, can_place_structure_at,
#  place_structure, _is_valid_castle_site, _find_slightly_offset_valid_site,
#  _find_castle_placement_sites, _place_castle_models, _clear_all_props_from_node,
#  _place_all_foliage_props, _spawn_foliage_on_tile)
# These are copied verbatim from the script you provided at the start of the conversation.

func setup_tile_data_from_type(type_str: String, h_level: int) -> CustomTileData:
	if not CustomTileData_C: printerr("CustomTileData_C script not loaded!"); return null
	var td: CustomTileData = CustomTileData_C.new()
	td.height_level = h_level
	td.tile_type = type_str
	match type_str:
		"water": td.walkable = false; td.movement_cost = 100
		"mountain": td.walkable = true; td.movement_cost = 3; td.defense_bonus = 2
		"forest_grass": td.walkable = true; td.movement_cost = 2; td.defense_bonus = 1; td.cover_type = "forest"
		"grass": td.walkable = true; td.movement_cost = 1
		_: td.walkable = true; td.movement_cost = 1
	return td

func _flood_fill_water_component(start_coord: Vector2i, component_coords: Array[Vector2i], visited_flags_ref: Array) -> void:
	var queue: Array[Vector2i] = [start_coord]
	if not visited_flags_ref or start_coord.x < 0 or start_coord.x >= visited_flags_ref.size() or \
	   not visited_flags_ref[start_coord.x] or start_coord.y < 0 or start_coord.y >= visited_flags_ref[start_coord.x].size(): return
	visited_flags_ref[start_coord.x][start_coord.y] = true; component_coords.append(start_coord); var head = 0
	while head < queue.size():
		var current = queue[head]; head += 1
		var neighbors = [Vector2i(0,1), Vector2i(0,-1), Vector2i(1,0), Vector2i(-1,0)]
		for offset in neighbors:
			var nx = current.x + offset.x; var nz = current.y + offset.y
			if is_valid_coord(nx,nz): # Use self.is_valid_coord
				if nx >= 0 and nx < visited_flags_ref.size() and visited_flags_ref[nx] != null and \
				   nz >= 0 and nz < visited_flags_ref[nx].size() and not visited_flags_ref[nx][nz]:
					var neighbor_tile_data: CustomTileData = get_tile_data_at(Vector2i(nx, nz)) # Use self.get_tile_data_at
					if neighbor_tile_data and neighbor_tile_data.tile_type == "water":
						visited_flags_ref[nx][nz] = true; var neighbor_coord = Vector2i(nx,nz)
						component_coords.append(neighbor_coord); queue.append(neighbor_coord)

func _modify_terrain_and_clear_props_for_area( center_coord: Vector2i, flatten_radius_tiles: int, flatten_strength_val: float, target_flatten_height_override_norm: float = -1.0, prop_removal_radius_val: int = 0, is_castle_placement: bool = false ):
	var final_target_flatten_height_norm: float
	if target_flatten_height_override_norm >= 0.0: final_target_flatten_height_norm = clamp(target_flatten_height_override_norm, flat_water_visual_norm_height + 0.02, mountain_threshold_norm - 0.02)
	else:
		var land_heights_in_radius: Array[float] = []
		for dx_avg in range(-flatten_radius_tiles, flatten_radius_tiles + 1):
			for dz_avg in range(-flatten_radius_tiles, flatten_radius_tiles + 1):
				if Vector2(dx_avg, dz_avg).length_squared() > float(flatten_radius_tiles * flatten_radius_tiles): continue
				var x_avg = center_coord.x + dx_avg; var z_avg = center_coord.y + dz_avg
				if is_valid_coord(x_avg, z_avg):
					var tile_data_avg: CustomTileData = get_tile_data_at(Vector2i(x_avg, z_avg))
					if tile_data_avg and tile_data_avg.tile_type != "water" and tile_data_avg.tile_type != "mountain":
						var top_y_world = tile_data_avg.position.y + current_tile_dimensions.y * 0.5
						land_heights_in_radius.append(top_y_world / (float(max_generation_height_levels) * current_tile_dimensions.y))
		if not land_heights_in_radius.is_empty():
			final_target_flatten_height_norm = 0.0; for h_val in land_heights_in_radius: final_target_flatten_height_norm += h_val
			final_target_flatten_height_norm /= float(land_heights_in_radius.size())
		else: 
			var center_tile_data: CustomTileData = get_tile_data_at(center_coord)
			if center_tile_data: final_target_flatten_height_norm = (center_tile_data.position.y + current_tile_dimensions.y * 0.5) / (float(max_generation_height_levels) * current_tile_dimensions.y)
			else: final_target_flatten_height_norm = flat_water_visual_norm_height + 0.1
		var mountain_offset = mountain_flatten_target_offset if is_castle_placement else 0.01
		final_target_flatten_height_norm = clamp(final_target_flatten_height_norm, flat_water_visual_norm_height + 0.02, mountain_threshold_norm - mountain_offset - 0.01)
	for dx_f in range(-flatten_radius_tiles, flatten_radius_tiles + 1):
		for dz_f in range(-flatten_radius_tiles, flatten_radius_tiles + 1):
			if Vector2(dx_f, dz_f).length_squared() > float(flatten_radius_tiles * flatten_radius_tiles): continue
			var x_f = center_coord.x + dx_f; var z_f = center_coord.y + dz_f
			if is_valid_coord(x_f, z_f):
				var tile_to_mod_data: CustomTileData = get_tile_data_at(Vector2i(x_f, z_f))
				if not tile_to_mod_data or tile_to_mod_data.tile_type == "water": continue
				var current_visual_h_norm = map_data_manager.visual_normalized_height_map[x_f][z_f]; var new_h_norm = current_visual_h_norm
				var dist_factor_from_center = sqrt(Vector2(dx_f, dz_f).length_squared()) / float(flatten_radius_tiles) if flatten_radius_tiles > 0 else 0.0
				var blend_strength_factor = smoothstep_value(1.0 - dist_factor_from_center)
				var actual_blend_alpha = clamp(blend_strength_factor * flatten_strength_val, 0.0, 1.0)
				var mountain_target_h_norm = final_target_flatten_height_norm
				if is_castle_placement: mountain_target_h_norm = clamp(final_target_flatten_height_norm, flat_water_visual_norm_height + 0.01, mountain_threshold_norm - mountain_flatten_target_offset)
				if tile_to_mod_data.tile_type == "mountain":
					new_h_norm = lerp(current_visual_h_norm, mountain_target_h_norm, actual_blend_alpha)
					if new_h_norm < mountain_threshold_norm: map_data_manager.final_tile_type_map[x_f][z_f] = "grass" 
				else: 
					new_h_norm = lerp(current_visual_h_norm, final_target_flatten_height_norm, actual_blend_alpha)
					new_h_norm = clamp(new_h_norm, flat_water_visual_norm_height + 0.01, mountain_threshold_norm - 0.01)
				map_data_manager.visual_normalized_height_map[x_f][z_f] = new_h_norm
				var max_world_map_h = float(max_generation_height_levels) * current_tile_dimensions.y
				tile_to_mod_data.position.y = (new_h_norm * max_world_map_h) - (current_tile_dimensions.y * 0.5)
				if tile_to_mod_data.tile_type != "water": 
					_update_tile_mesh_at(Vector2i(x_f, z_f)) 
	for dx_p in range(-prop_removal_radius_val, prop_removal_radius_val + 1):
		for dz_p in range(-prop_removal_radius_val, prop_removal_radius_val + 1):
			if Vector2(dx_p, dz_p).length_squared() > float(prop_removal_radius_val * prop_removal_radius_val): continue
			var prop_check_coord = center_coord + Vector2i(dx_p, dz_p)
			if is_valid_coord(prop_check_coord.x, prop_check_coord.y):
				var td_prop: CustomTileData = get_tile_data_at(prop_check_coord)
				if td_prop and td_prop.has_prop: _remove_prop_at_tile(prop_check_coord)

func _remove_prop_at_tile(tile_coord: Vector2i):
	if not map_data_manager: printerr("MapGenerator._remove_prop_at_tile: map_data_manager is not initialized!"); return
	if not is_valid_coord(tile_coord.x, tile_coord.y): return
	var tile_data: CustomTileData = get_tile_data_at(tile_coord)
	if not tile_data or not tile_data.has_prop: return
	if not is_instance_valid(props_node):
		printerr("MapGenerator._remove_prop_at_tile: props_node is not valid!")
		tile_data.has_prop = false; return
	for i in range(props_node.get_child_count() - 1, -1, -1): 
		var prop_node_child = props_node.get_child(i)
		if prop_node_child is Node3D: 
			var prop_node_3d = prop_node_child as Node3D
			var prop_grid_coord = world_to_grid_coords_snapped(prop_node_3d.global_position)
			if prop_grid_coord == tile_coord:
				prop_node_3d.queue_free()
				tile_data.has_prop = false
				return 
	tile_data.has_prop = false

func can_place_structure_at(structure_data: StructureData, placement_coord: Vector2i, player_id: int) -> bool:
	if not StructureData_C: printerr("StructureData_C script not loaded!"); return false
	if not structure_data or not structure_data.get_script() == StructureData_C : printerr("Invalid structure_data object."); return false
	var footprint_tiles = structure_data.get_footprint_tiles(placement_coord) # Assumes StructureData has this
	for tile_g_coord in footprint_tiles:
		if not is_valid_coord(tile_g_coord.x, tile_g_coord.y): return false 
		var tile_data: CustomTileData = get_tile_data_at(tile_g_coord)
		if not tile_data or tile_data.has_structure or tile_data.has_prop or is_instance_valid(tile_data.occupant) or \
		   structure_data.disallowed_tile_types.has(tile_data.tile_type) or \
		  (not structure_data.allowed_tile_types.is_empty() and not structure_data.allowed_tile_types.has(tile_data.tile_type)): return false
		if structure_data.min_dist_from_water_tiles > 0:
			for dx in range(-structure_data.min_dist_from_water_tiles, structure_data.min_dist_from_water_tiles + 1):
				for dz in range(-structure_data.min_dist_from_water_tiles, structure_data.min_dist_from_water_tiles + 1):
					var check_coord = tile_g_coord + Vector2i(dx, dz)
					if is_valid_coord(check_coord.x, check_coord.y):
						var neighbor_tile: CustomTileData = get_tile_data_at(check_coord)
						if neighbor_tile and neighbor_tile.tile_type == "water": return false
	return true

# map_generator.gd
# ... (all the code before these functions) ...

func place_structure(structure_data: StructureData, placement_coord: Vector2i, player_id: int):
	if not StructureData_C: 
		printerr("MapGenerator: StructureData_C script not loaded in place_structure!")
		return
	if not structure_data or not structure_data.get_script() == StructureData_C : 
		printerr("MapGenerator: Invalid structure_data object in place_structure.")
		return
	if not can_place_structure_at(structure_data, placement_coord, player_id): 
		printerr("MapGenerator: Structure placement denied by can_place_structure_at for ", structure_data.id, " at ", placement_coord)
		return

	var target_flatten_height_norm_struct: float
	var footprint_tiles_for_avg = structure_data.get_footprint_tiles(placement_coord) # Assumes StructureData has this
	var sum_h = 0.0
	var count_h = 0
	for ft_coord_avg in footprint_tiles_for_avg:
		if is_valid_coord(ft_coord_avg.x, ft_coord_avg.y): # Use self.is_valid_coord
			var td_avg: CustomTileData = get_tile_data_at(ft_coord_avg) # Use self.get_tile_data_at
			if td_avg and td_avg.tile_type != "water" and td_avg.tile_type != "mountain":
				sum_h += (td_avg.position.y + current_tile_dimensions.y * 0.5) / (float(max_generation_height_levels) * current_tile_dimensions.y)
				count_h += 1
	if count_h > 0: 
		target_flatten_height_norm_struct = sum_h / float(count_h)
	else: 
		var center_tile_for_avg: CustomTileData = get_tile_data_at(placement_coord)
		if center_tile_for_avg: 
			target_flatten_height_norm_struct = (center_tile_for_avg.position.y + current_tile_dimensions.y * 0.5) / (float(max_generation_height_levels) * current_tile_dimensions.y)
		else: 
			target_flatten_height_norm_struct = flat_water_visual_norm_height + 0.1 
	
	_modify_terrain_and_clear_props_for_area(placement_coord, structure_data.flatten_radius_tiles, structure_data.flatten_strength, target_flatten_height_norm_struct, structure_data.prop_removal_radius_tiles, false)

	var footprint_tiles = structure_data.get_footprint_tiles(placement_coord)
	for tile_g_coord_fp in footprint_tiles: 
		if is_valid_coord(tile_g_coord_fp.x, tile_g_coord_fp.y):
			var tile_data_fp: CustomTileData = get_tile_data_at(tile_g_coord_fp)
			if tile_data_fp: 
				tile_data_fp.has_structure = true
				tile_data_fp.walkable = false # Structures typically block walkability
				# If you have an occupant field for structures too, set it here.
				# tile_data_fp.occupant = "structure_" + structure_data.id 
	
	var model_scene_to_use = structure_data.model_p1 if player_id == 1 else structure_data.model_p2
	if not model_scene_to_use: model_scene_to_use = structure_data.model_p1 # Default to P1 model if P2 is null
	
	if model_scene_to_use:
		var structure_instance: Node3D = model_scene_to_use.instantiate() as Node3D
		if structure_instance:
			if not is_instance_valid(structures_node): # Ensure structures_node is valid
				printerr("MapGenerator: structures_node is not valid in place_structure!")
				structure_instance.queue_free()
				return
			structures_node.add_child(structure_instance)
			
			var center_tile_data: CustomTileData = get_tile_data_at(placement_coord) 
			if center_tile_data:
				# Calculate position for the structure model
				# This often means centering it over its footprint
				var structure_base_y = center_tile_data.position.y + (current_tile_dimensions.y * 0.5) # Top of anchor tile
				
				var model_pos_x = (float(placement_coord.x + structure_data.footprint_offset_tiles.x) + (float(structure_data.footprint_size_tiles.x) / 2.0)) * current_tile_dimensions.x - (current_tile_dimensions.x / 2.0 if structure_data.footprint_size_tiles.x % 2 == 0 else 0.0) # Adjust for even footprints
				var model_pos_z = (float(placement_coord.y + structure_data.footprint_offset_tiles.y) + (float(structure_data.footprint_size_tiles.y) / 2.0)) * current_tile_dimensions.z - (current_tile_dimensions.z / 2.0 if structure_data.footprint_size_tiles.y % 2 == 0 else 0.0) # Adjust for even footprints
				
				# If footprint_offset_tiles is relative to the anchor, and footprint_size_tiles is the extent:
				# The center of the footprint would be:
				# anchor_x_world + (footprint_width_world / 2.0)
				# anchor_z_world + (footprint_depth_world / 2.0)
				# where anchor_x_world is placement_coord.x * tile_dim.x + tile_dim.x * 0.5 (center of anchor tile)
				
				var anchor_tile_center_x = (float(placement_coord.x) + 0.5) * current_tile_dimensions.x
				var anchor_tile_center_z = (float(placement_coord.y) + 0.5) * current_tile_dimensions.z

				# Assuming footprint_offset_tiles is from the anchor tile's origin (bottom-left corner)
				# And footprint_size_tiles is the number of tiles it covers
				var footprint_world_width = float(structure_data.footprint_size_tiles.x) * current_tile_dimensions.x
				var footprint_world_depth = float(structure_data.footprint_size_tiles.y) * current_tile_dimensions.z

				var final_model_pos_x = (float(placement_coord.x + structure_data.footprint_offset_tiles.x) * current_tile_dimensions.x) + (footprint_world_width / 2.0)
				var final_model_pos_z = (float(placement_coord.y + structure_data.footprint_offset_tiles.y) * current_tile_dimensions.z) + (footprint_world_depth / 2.0)


				structure_instance.global_position = Vector3(final_model_pos_x, structure_base_y, final_model_pos_z)
				
				# Scaling (using AssetUtilities_C if available and method exists)
				if AssetUtilities_C and is_instance_valid(AssetUtilities_C):
					if structure_data.model_tile_radius > 0 and AssetUtilities_C.has_method("scale_node_to_tile_radius"):
						AssetUtilities_C.scale_node_to_tile_radius(structure_instance, float(structure_data.model_tile_radius), current_tile_dimensions.x)
					# You might add a new scaling method for rectangular footprints if needed:
					# elif structure_data.footprint_size_tiles != Vector2i.ONE and AssetUtilities_C.has_method("scale_node_to_footprint_tiles"):
					#    AssetUtilities_C.scale_node_to_footprint_tiles(structure_instance, structure_data.footprint_size_tiles, current_tile_dimensions)

				placed_structures_map[placement_coord] = structure_instance 
			else: 
				printerr("MapGenerator: No center tile data for structure placement at ", placement_coord)
				structure_instance.queue_free()
		else: 
			printerr("MapGenerator: Failed to instantiate structure model for ", structure_data.id)
	else: 
		printerr("MapGenerator: No model scene for structure ", structure_data.id, " for player ", player_id)
	
	print("MapGenerator: Placed structure '", structure_data.id, "' for player ", player_id, " at anchor ", placement_coord)


func _is_valid_castle_site(coord: Vector2i, type_map_to_check: Array) -> int:
	if not (coord.x >= castle_edge_margin_tiles and coord.x < map_width - castle_edge_margin_tiles and \
			coord.y >= castle_edge_margin_tiles and coord.y < map_depth - castle_edge_margin_tiles):
		return 0
	if not is_valid_coord(coord.x, coord.y): # Use self.is_valid_coord
		return 0
	
	# Ensure type_map_to_check is valid and coord is within its bounds
	if not (coord.x >= 0 and coord.x < type_map_to_check.size() and \
			coord.y >= 0 and coord.y < type_map_to_check[coord.x].size()):
		printerr("MapGenerator: _is_valid_castle_site - coord out of bounds for type_map_to_check.")
		return 0
		
	var tile_type = type_map_to_check[coord.x][coord.y]
	if tile_type == "water" or tile_type == "mountain":
		return 0
	
	for dx_water in range(-castle_water_avoid_radius_tiles, castle_water_avoid_radius_tiles + 1):
		for dz_water in range(-castle_water_avoid_radius_tiles, castle_water_avoid_radius_tiles + 1):
			var nx_water = coord.x + dx_water
			var nz_water = coord.y + dz_water
			if is_valid_coord(nx_water, nz_water): # Use self.is_valid_coord
				if not (nx_water >= 0 and nx_water < type_map_to_check.size() and \
						nz_water >= 0 and nz_water < type_map_to_check[nx_water].size()):
					continue # Should not happen if is_valid_coord is correct
				if type_map_to_check[nx_water][nz_water] == "water":
					return 0
					
	if tile_type == "grass" or tile_type == "forest_grass":
		return 2 # Best score
	return 1 # Okay score


func _find_slightly_offset_valid_site(preferred_coord: Vector2i, max_radius: int, type_map_to_check: Array, p_zone_y_min_abs: int, p_zone_y_max_abs: int) -> Vector2i:
	var best_site_found = Vector2i(-1,-1)
	var best_site_score = 0
	
	var min_allowed_x_abs = castle_edge_margin_tiles
	var max_allowed_x_abs = map_width - 1 - castle_edge_margin_tiles

	var initial_score = _is_valid_castle_site(preferred_coord, type_map_to_check)
	if initial_score > 0 and \
	   preferred_coord.y >= p_zone_y_min_abs and preferred_coord.y <= p_zone_y_max_abs and \
	   preferred_coord.x >= min_allowed_x_abs and preferred_coord.x <= max_allowed_x_abs :
		if initial_score == 2:
			return preferred_coord
		best_site_found = preferred_coord
		best_site_score = initial_score
		
	for r in range(1, max_radius + 1):
		var temp_perimeter_coords: Array[Vector2i] = []
		# Iterate around the perimeter of a square of radius r
		for i in range(-r, r + 1):
			temp_perimeter_coords.append(preferred_coord + Vector2i(i, -r)) # Top edge
			temp_perimeter_coords.append(preferred_coord + Vector2i(i, r))  # Bottom edge
		for i in range(-r + 1, r): # Avoid double-counting corners
			temp_perimeter_coords.append(preferred_coord + Vector2i(-r, i)) # Left edge
			temp_perimeter_coords.append(preferred_coord + Vector2i(r, i))  # Right edge
			
		var unique_perimeter_coords: Array[Vector2i] = []
		for coord_to_check_unique in temp_perimeter_coords:
			if not unique_perimeter_coords.has(coord_to_check_unique):
				unique_perimeter_coords.append(coord_to_check_unique)
				
		for offset_coord in unique_perimeter_coords:
			if not (offset_coord.x >= min_allowed_x_abs and offset_coord.x <= max_allowed_x_abs and \
					offset_coord.y >= p_zone_y_min_abs and offset_coord.y <= p_zone_y_max_abs):
				continue
				
			var site_score = _is_valid_castle_site(offset_coord, type_map_to_check)
			if site_score == 2: # Found a perfect site
				return offset_coord
			elif site_score == 1 and best_site_score < 1: # Found an okay site, and current best is none or worse
				best_site_found = offset_coord
				best_site_score = 1
				
	return best_site_found


func _find_castle_placement_sites() -> Array[Vector2i]:
	var p1_y_min_abs = int(float(map_depth) * castle_zone_1_y_start_factor)
	var p1_y_max_abs = int(float(map_depth) * castle_zone_1_y_end_factor) - 1
	var p2_y_min_abs = int(float(map_depth) * castle_zone_2_y_start_factor)
	var p2_y_max_abs = int(float(map_depth) * castle_zone_2_y_end_factor) - 1
	
	var x_min_with_margin = castle_edge_margin_tiles
	var x_max_with_margin = map_width - 1 - castle_edge_margin_tiles
	
	var final_p1_y_min = clamp(p1_y_min_abs, castle_edge_margin_tiles, map_depth - 1 - castle_edge_margin_tiles)
	var final_p1_y_max = clamp(p1_y_max_abs, castle_edge_margin_tiles, map_depth - 1 - castle_edge_margin_tiles)
	var final_p2_y_min = clamp(p2_y_min_abs, castle_edge_margin_tiles, map_depth - 1 - castle_edge_margin_tiles)
	var final_p2_y_max = clamp(p2_y_max_abs, castle_edge_margin_tiles, map_depth - 1 - castle_edge_margin_tiles)

	if x_min_with_margin > x_max_with_margin or \
	   final_p1_y_min > final_p1_y_max or \
	   final_p2_y_min > final_p2_y_max:
		printerr("MapGenerator: Castle placement zones are invalid after clamping.")
		return []

	var ideal_p1_tl = Vector2i(x_min_with_margin, final_p1_y_min)
	var ideal_p2_br = Vector2i(x_max_with_margin, final_p2_y_max)
	var ideal_p1_tr = Vector2i(x_max_with_margin, final_p1_y_min)
	var ideal_p2_bl = Vector2i(x_min_with_margin, final_p2_y_max)
	
	var best_overall_p1_site = Vector2i(-1,-1)
	var best_overall_p2_site = Vector2i(-1,-1)
	var max_overall_dist_sq = -1.0

	# Try TL-BR pairing
	var p1_s1 = _find_slightly_offset_valid_site(ideal_p1_tl, castle_corner_push_radius, map_data_manager.final_tile_type_map, final_p1_y_min, final_p1_y_max)
	var p2_s1 = _find_slightly_offset_valid_site(ideal_p2_br, castle_corner_push_radius, map_data_manager.final_tile_type_map, final_p2_y_min, final_p2_y_max)
	if p1_s1.x != -1 and p2_s1.x != -1:
		var d1 = p1_s1.distance_squared_to(p2_s1)
		if d1 > max_overall_dist_sq:
			max_overall_dist_sq = d1
			best_overall_p1_site = p1_s1
			best_overall_p2_site = p2_s1
			
	# Try TR-BL pairing
	var p1_s2 = _find_slightly_offset_valid_site(ideal_p1_tr, castle_corner_push_radius, map_data_manager.final_tile_type_map, final_p1_y_min, final_p1_y_max)
	var p2_s2 = _find_slightly_offset_valid_site(ideal_p2_bl, castle_corner_push_radius, map_data_manager.final_tile_type_map, final_p2_y_min, final_p2_y_max)
	if p1_s2.x != -1 and p2_s2.x != -1:
		var d2 = p1_s2.distance_squared_to(p2_s2)
		if d2 > max_overall_dist_sq:
			# max_overall_dist_sq = d2 # This was commented in original, keeping it commented
			best_overall_p1_site = p1_s2
			best_overall_p2_site = p2_s2
			
	if best_overall_p1_site.x != -1 and best_overall_p2_site.x != -1:
		return [best_overall_p1_site, best_overall_p2_site]

	# Fallback: exhaustive search if ideal corners didn't yield a good pair
	printerr("MapGenerator: Castle placement - ideal corner pairs failed, trying fallback search.")
	var all_p1_sites: Array[Vector2i] = []
	var all_p2_sites: Array[Vector2i] = []
	
	for x_f in range(x_min_with_margin, x_max_with_margin + 1):
		for y_p1_f in range(final_p1_y_min, final_p1_y_max + 1):
			var c1 = Vector2i(x_f, y_p1_f)
			if _is_valid_castle_site(c1, map_data_manager.final_tile_type_map) > 0:
				all_p1_sites.append(c1)
		for y_p2_f in range(final_p2_y_min, final_p2_y_max + 1):
			var c2 = Vector2i(x_f, y_p2_f)
			if _is_valid_castle_site(c2, map_data_manager.final_tile_type_map) > 0:
				all_p2_sites.append(c2)
				
	if all_p1_sites.is_empty() or all_p2_sites.is_empty():
		printerr("MapGenerator: Castle placement - no valid sites found in fallback search for one or both players.")
		return []

	# Sort by score (descending) to prioritize better sites, then shuffle for variety among equally good sites
	all_p1_sites.sort_custom(func(a,b): return _is_valid_castle_site(a, map_data_manager.final_tile_type_map) > _is_valid_castle_site(b, map_data_manager.final_tile_type_map))
	all_p2_sites.sort_custom(func(a,b): return _is_valid_castle_site(a, map_data_manager.final_tile_type_map) > _is_valid_castle_site(b, map_data_manager.final_tile_type_map))
	
	all_p1_sites.shuffle()
	all_p2_sites.shuffle()
	
	var fallback_p1 = Vector2i(-1,-1)
	var fallback_p2 = Vector2i(-1,-1)
	var max_fallback_dist_sq = -1.0
	
	# Limit search space for performance in fallback
	var p1_candidates = all_p1_sites.slice(0, min(all_p1_sites.size(), 20)) # Check top 20 candidates
	var p2_candidates = all_p2_sites.slice(0, min(all_p2_sites.size(), 20))

	for p1s_fb in p1_candidates:
		for p2s_fb in p2_candidates:
			var dsq_fb = p1s_fb.distance_squared_to(p2s_fb)
			if dsq_fb > max_fallback_dist_sq:
				max_fallback_dist_sq = dsq_fb
				fallback_p1 = p1s_fb
				fallback_p2 = p2s_fb
				
	if fallback_p1.x == -1 or fallback_p2.x == -1:
		printerr("MapGenerator: Castle placement - fallback search also failed to find a pair.")
		return []
		
	return [fallback_p1, fallback_p2]


func _place_castle_models(p1_coord: Vector2i, p2_coord: Vector2i):
	if p1_coord.x == -1 or p2_coord.x == -1:
		printerr("MapGenerator: Invalid castle coordinates for placement in _place_castle_models."); return
	if not castle_1_scene or not castle_2_scene:
		printerr("MapGenerator: Castle scene(s) not assigned in _place_castle_models."); return

	var castle_scenes = [castle_1_scene, castle_2_scene]
	var castle_coords = [p1_coord, p2_coord]
	var placed_castles_nodes: Array[Node3D] = []

	for i in range(2):
		var packed_scene_to_use = castle_scenes[i]
		if not packed_scene_to_use:
			printerr("MapGenerator: Castle scene for player ", i+1, " is null.")
			continue
			
		var castle_instance: Node3D = packed_scene_to_use.instantiate() as Node3D
		if not castle_instance:
			printerr("MapGenerator: Failed to instantiate castle scene for player ", i+1)
			continue
		
		if not is_instance_valid(castles_node):
			printerr("MapGenerator: castles_node is not valid in _place_castle_models!")
			castle_instance.queue_free()
			continue
		castles_node.add_child(castle_instance)
		
		var center_tile_data: CustomTileData = get_tile_data_at(castle_coords[i])
		if not center_tile_data:
			printerr("MapGenerator: No tile data for castle placement at ", castle_coords[i])
			castle_instance.queue_free()
			continue
			
		var castle_base_y = center_tile_data.position.y + (current_tile_dimensions.y * 0.5) # Top of the tile
		castle_instance.global_position = Vector3(center_tile_data.position.x, castle_base_y, center_tile_data.position.z) # Center of the anchor tile
		
		if AssetUtilities_C and is_instance_valid(AssetUtilities_C) and AssetUtilities_C.has_method("scale_node_to_tile_radius"):
			AssetUtilities_C.scale_node_to_tile_radius(castle_instance, float(castle_tile_radius), current_tile_dimensions.x)
		
		placed_castles_nodes.append(castle_instance)
		
		# Mark tiles under castle footprint as having a structure
		var footprint_r = castle_tile_radius # Use castle_tile_radius for footprint marking
		for dx in range(-footprint_r, footprint_r + 1):
			for dz in range(-footprint_r, footprint_r + 1):
				if Vector2(dx, dz).length_squared() > float(footprint_r * footprint_r):
					continue
				var tile_coord_fp = castle_coords[i] + Vector2i(dx,dz)
				var td_fp: CustomTileData = get_tile_data_at(tile_coord_fp)
				if td_fp:
					td_fp.has_structure = true
					td_fp.walkable = false # Castles are not walkable
					# td_fp.occupant = "castle_" + str(i+1) # Optional: mark occupant
					
	if placed_castles_nodes.size() == 2:
		var c1n = placed_castles_nodes[0]
		var c2n = placed_castles_nodes[1]
		if c1n and c2n: # Ensure both were successfully placed
			var c1p = c1n.global_position
			var c2p = c2n.global_position
			
			var target_look_c2 = Vector3(c2p.x, c1p.y, c2p.z) # Look at other castle on same Y plane
			if c1p.distance_squared_to(target_look_c2) > 0.001: # Avoid look_at self
				c1n.look_at(target_look_c2, Vector3.UP)
				
			var target_look_c1 = Vector3(c1p.x, c2p.y, c1p.z)
			if c2p.distance_squared_to(target_look_c1) > 0.001:
				c2n.look_at(target_look_c1, Vector3.UP)
			
			# Optional: Rotate them to face away from each other after looking (e.g. gates face outward)
			c1n.rotate_y(PI) 
			c2n.rotate_y(PI)

# ... (rest of your MapGenerator.gd script: _clear_all_props_from_node, _place_all_foliage_props, etc.)
func _clear_all_props_from_node():
	if is_instance_valid(props_node):
		for child_idx in range(props_node.get_child_count() - 1, -1, -1):
			var child_to_remove = props_node.get_child(child_idx)
			if is_instance_valid(child_to_remove):
				child_to_remove.queue_free()

func _place_all_foliage_props():
	if not is_instance_valid(props_node): return
	for x in range(map_width):
		for z in range(map_depth):
			var tc=Vector2i(x,z)
			var td:CustomTileData=get_tile_data_at(tc)
			if not td||td.has_prop||td.has_structure||is_instance_valid(td.occupant)||td.tile_type=="water":continue
			var tc1=false;var tc2=false
			if _castle1_site_coord.x!=-1&&tc.distance_to(_castle1_site_coord)<float(castle_prop_removal_radius_tiles):tc1=true
			if _castle2_site_coord.x!=-1&&tc.distance_to(_castle2_site_coord)<float(castle_prop_removal_radius_tiles):tc2=true
			if tc1||tc2:continue
			match td.tile_type:
				"grass":
					if flower_scene_variants.size()>0&&randf()<grass_tile_flower_chance:_spawn_foliage_on_tile(td,flower_scene_variants.pick_random())
					elif plains_tree_scene_variants.size()>0&&randf()<grass_tile_plains_tree_chance:_spawn_foliage_on_tile(td,plains_tree_scene_variants.pick_random())
				"forest_grass":
					if tree_scene_variants.size()>0&&randf()<forest_tile_tree_chance:_spawn_foliage_on_tile(td,tree_scene_variants.pick_random())
				"mountain":
					if large_rock_cluster_scene_variants.size()>0:
						var rnv=(rock_density_noise.get_noise_2d(float(x),float(z))+1.0)/2.0
						if rnv>rock_cluster_threshold&&randf()<0.75:_spawn_foliage_on_tile(td,large_rock_cluster_scene_variants.pick_random())

func _spawn_foliage_on_tile(tile_data: CustomTileData, prop_scene: PackedScene):
	if not prop_scene||tile_data.has_prop||tile_data.has_structure||is_instance_valid(tile_data.occupant)||not is_instance_valid(props_node)||current_tile_dimensions==Vector3.ZERO:return
	var p_inst=prop_scene.instantiate()
	if not p_inst is Node3D:
		if is_instance_valid(p_inst): p_inst.queue_free()
		return
	props_node.add_child(p_inst)
	var max_off=current_tile_dimensions.x*0.5*major_prop_max_offset_factor
	var prop_y_pos = tile_data.position.y + (current_tile_dimensions.y * 0.5) # Top of the tile
	p_inst.global_position=Vector3(tile_data.position.x+randf_range(-max_off,max_off), prop_y_pos, tile_data.position.z+randf_range(-max_off,max_off))
	p_inst.rotation.y=randf_range(0,TAU)
	tile_data.has_prop=true
