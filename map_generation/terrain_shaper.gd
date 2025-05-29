# res://map_generation/terrain_shaper.gd
class_name TerrainShaper
extends RefCounted

var map_data: MapDataManager 

# Noise instances
var height_noise: FastNoiseLite
var moisture_noise: FastNoiseLite
var mountain_spike_noise: FastNoiseLite
var coastline_detail_noise: FastNoiseLite 
var coastal_indent_noise: FastNoiseLite
var coastal_reach_noise: FastNoiseLite

# Config parameters
var water_threshold_norm: float
var mountain_threshold_norm: float
var forest_moisture_threshold_norm: float
var flat_water_visual_norm_height: float
var water_border_width: int
var coastal_indent_strength_factor: float
var coastal_inland_reach_percent: float
var shoreline_width: int
var beach_slope_noise_strength: float
var land_transition_passes: int
var land_transition_step_factor: float
var mountain_spike_strength: float
var height_clamp_passes: int
var max_generation_height_levels: int


func _init(p_map_data: MapDataManager, p_config: Dictionary, p_noises: Dictionary):
	map_data = p_map_data
	
	water_threshold_norm = p_config.water_threshold_norm
	mountain_threshold_norm = p_config.mountain_threshold_norm
	forest_moisture_threshold_norm = p_config.forest_moisture_threshold_norm
	flat_water_visual_norm_height = p_config.flat_water_visual_norm_height
	water_border_width = p_config.water_border_width
	coastal_indent_strength_factor = p_config.coastal_indent_strength_factor
	coastal_inland_reach_percent = p_config.coastal_inland_reach_percent
	shoreline_width = p_config.shoreline_width
	beach_slope_noise_strength = p_config.beach_slope_noise_strength
	land_transition_passes = p_config.land_transition_passes
	land_transition_step_factor = p_config.land_transition_step_factor
	mountain_spike_strength = p_config.mountain_spike_strength
	height_clamp_passes = p_config.height_clamp_passes
	max_generation_height_levels = p_config.max_generation_height_levels

	height_noise = p_noises.height_noise
	moisture_noise = p_noises.moisture_noise
	mountain_spike_noise = p_noises.mountain_spike_noise
	coastline_detail_noise = p_noises.coastline_detail_noise
	coastal_indent_noise = p_noises.coastal_indent_noise
	coastal_reach_noise = p_noises.coastal_reach_noise

func generate_base_height_noise():
	for x in range(map_data.map_width):
		for z in range(map_data.map_depth):
			map_data.base_normalized_height_map[x][z] = (height_noise.get_noise_2d(float(x), float(z)) + 1.0) / 2.0

func reshape_coastline():
	var map_center_x = float(map_data.map_width - 1) / 2.0
	var map_center_z = float(map_data.map_depth - 1) / 2.0
	var max_dist_from_center = Vector2(map_center_x, map_center_z).length()
	var target_deep_water_h = flat_water_visual_norm_height * 0.05
	target_deep_water_h = clamp(target_deep_water_h, 0.0, water_threshold_norm - 0.15)

	for x_cr in range(map_data.map_width):
		for z_cr in range(map_data.map_depth):
			var current_h = map_data.base_normalized_height_map[x_cr][z_cr]
			var pos_v2 = Vector2(float(x_cr), float(z_cr))
			var dist_to_map_center = pos_v2.distance_to(Vector2(map_center_x, map_center_z))
			var normalized_dist_from_center = 0.0
			if max_dist_from_center > 0.001:
				normalized_dist_from_center = clamp(dist_to_map_center / max_dist_from_center, 0.0, 1.0)

			var island_mask_factor = _inverse_lerp_clamped(0.95, 0.45, normalized_dist_from_center) 
			island_mask_factor = _smoothstep_value(island_mask_factor)
			current_h = lerp(target_deep_water_h, current_h, island_mask_factor)

			if island_mask_factor < 0.98: 
				var indent_noise_val = (coastal_indent_noise.get_noise_2d(float(x_cr), float(z_cr)) + 1.0) / 2.0
				var reach_noise_val = (coastal_reach_noise.get_noise_2d(float(x_cr) * 0.7, float(z_cr) * 0.7) + 1.0) / 2.0
				var effective_inland_reach_norm = coastal_inland_reach_percent * lerp(0.5, 1.5, reach_noise_val) 
				effective_inland_reach_norm = clamp(effective_inland_reach_norm, 0.05, 0.9)
				var transition_point_norm_start = clamp(1.0 - effective_inland_reach_norm, 0.1, 0.9)
				var transition_point_norm_end = clamp(transition_point_norm_start + (effective_inland_reach_norm * 0.7), transition_point_norm_start + 0.05, 0.99)
				var indent_blend = _inverse_lerp_clamped(transition_point_norm_start, transition_point_norm_end, normalized_dist_from_center)
				indent_blend = _smoothstep_value(indent_blend)
				var indent_target_h = lerp(current_h, target_deep_water_h, indent_noise_val * coastal_indent_strength_factor)
				current_h = lerp(current_h, indent_target_h, indent_blend)

			var dist_to_abs_edge_x = min(x_cr, map_data.map_width - 1 - x_cr)
			var dist_to_abs_edge_z = min(z_cr, map_data.map_depth - 1 - z_cr)
			var min_dist_to_abs_edge = min(dist_to_abs_edge_x, dist_to_abs_edge_z)

			if water_border_width > 0 and min_dist_to_abs_edge < water_border_width:
				var edge_falloff_blend = 1.0 - clamp(float(min_dist_to_abs_edge) / float(water_border_width), 0.0, 1.0)
				edge_falloff_blend = _smoothstep_value(edge_falloff_blend)
				current_h = lerp(current_h, target_deep_water_h * 0.2, edge_falloff_blend * edge_falloff_blend * edge_falloff_blend)
			map_data.base_normalized_height_map[x_cr][z_cr] = clamp(current_h, 0.0, 1.0)

func determine_initial_tile_types():
	for x_itt in range(map_data.map_width):
		for z_itt in range(map_data.map_depth):
			var h = map_data.base_normalized_height_map[x_itt][z_itt]
			var m = (moisture_noise.get_noise_2d(float(x_itt), float(z_itt)) + 1.0) / 2.0
			var type_str = ""
			if h < water_threshold_norm: type_str = "water"
			elif h >= mountain_threshold_norm: type_str = "mountain"
			else: type_str = "grass" if m <= forest_moisture_threshold_norm else "forest_grass"
			map_data.initial_tile_type_map[x_itt][z_itt] = type_str
			map_data.final_tile_type_map[x_itt][z_itt] = type_str

func generate_shoreline_rings():
	if shoreline_width <= 0: return
	for r_pass in range(1, shoreline_width + 1): 
		var to_process_this_pass: Array[Dictionary] = []
		for x_sh in range(map_data.map_width):
			for z_sh in range(map_data.map_depth):
				if map_data.final_tile_type_map[x_sh][z_sh] == "water" and map_data.shore_tile_info_map[x_sh][z_sh].ring == 0: 
					var closest_land_type_found = "water"; var closest_land_base_h_found = 0.0; var source_found_for_tile = false 
					for dx_neighbor in [-1, 0, 1]:
						for dz_neighbor in [-1, 0, 1]:
							if dx_neighbor == 0 and dz_neighbor == 0: continue
							var nx = x_sh + dx_neighbor; var nz = z_sh + dz_neighbor
							if map_data.is_valid_coord(nx,nz):
								var neighbor_current_final_type = map_data.final_tile_type_map[nx][nz] 
								var neighbor_current_shore_info = map_data.shore_tile_info_map[nx][nz]
								if neighbor_current_final_type != "water" and neighbor_current_final_type != "mountain": 
									source_found_for_tile = true; closest_land_type_found = neighbor_current_final_type
									closest_land_base_h_found = map_data.base_normalized_height_map[nx][nz]; break 
								elif neighbor_current_final_type != "water" and neighbor_current_shore_info.ring == r_pass - 1: 
									source_found_for_tile = true; closest_land_type_found = neighbor_current_shore_info.source_land_type
									closest_land_base_h_found = neighbor_current_shore_info.source_land_base_h; break 
						if source_found_for_tile: break 
					if source_found_for_tile: to_process_this_pass.append({"coord": Vector2i(x_sh, z_sh), "source_land_type": closest_land_type_found, "source_land_base_h": closest_land_base_h_found, "ring": r_pass})
		if to_process_this_pass.is_empty() and r_pass > 0: break 
		for shore_data_item in to_process_this_pass: 
			var current_coord = shore_data_item.coord
			map_data.final_tile_type_map[current_coord.x][current_coord.y] = shore_data_item.source_land_type 
			map_data.shore_tile_info_map[current_coord.x][current_coord.y] = shore_data_item

func initialize_visual_heightmap_from_shores():
	for x_vhm in range(map_data.map_width): 
		for z_vhm in range(map_data.map_depth): 
			var tile_type = map_data.final_tile_type_map[x_vhm][z_vhm]
			var base_h = map_data.base_normalized_height_map[x_vhm][z_vhm] 
			var shore_info = map_data.shore_tile_info_map[x_vhm][z_vhm] 
			if map_data.final_tile_type_map[x_vhm][z_vhm] != "water" and shore_info.ring > 0 : 
				var ring_num = shore_info.ring; var target_land_h = shore_info.source_land_base_h; var base_slope_factor = 0.0
				if shoreline_width > 0: base_slope_factor = float(shoreline_width - ring_num + 1) / float(shoreline_width + 1)
				var coast_noise_val = (coastline_detail_noise.get_noise_2d(float(x_vhm), float(z_vhm)) + 1.0) / 2.0 
				var randomized_slope_factor = base_slope_factor * lerp(1.0 - beach_slope_noise_strength, 1.0 + beach_slope_noise_strength, coast_noise_val)
				map_data.visual_normalized_height_map[x_vhm][z_vhm] = lerp(flat_water_visual_norm_height, target_land_h, clamp(randomized_slope_factor, 0.0, 1.0))
			elif tile_type == "water": 
				map_data.visual_normalized_height_map[x_vhm][z_vhm] = flat_water_visual_norm_height 
			else: 
				map_data.visual_normalized_height_map[x_vhm][z_vhm] = base_h

func smooth_land_transitions():
	for _i in range(land_transition_passes): 
		var read_only_visual_map: Array = []
		for x_r in range(map_data.map_width): read_only_visual_map.append(map_data.visual_normalized_height_map[x_r].duplicate(true))
		
		for x_iter in range(map_data.map_width): 
			for z_iter in range(map_data.map_depth):
				if (map_data.initial_tile_type_map[x_iter][z_iter] == "grass" or map_data.initial_tile_type_map[x_iter][z_iter] == "forest_grass") and map_data.shore_tile_info_map[x_iter][z_iter].ring == 0: 
					var current_h_lts = read_only_visual_map[x_iter][z_iter]; var avg_n_h = 0.0; var count_n = 0
					for dx in [-1,0,1]: for dz in [-1,0,1]:
						var nx = x_iter+dx; var nz = z_iter+dz
						if map_data.is_valid_coord(nx,nz): avg_n_h += read_only_visual_map[nx][nz]; count_n +=1
					if count_n > 0 :
						avg_n_h /= float(count_n); var new_h = lerp(current_h_lts, avg_n_h, land_transition_step_factor)
						var up_clamp = mountain_threshold_norm - 0.001; var max_neighbor_h_non_mountain = current_h_lts; var found_mountain_neighbor = false
						for dx_m in [-1,0,1]: for dz_m in [-1,0,1]:
							var nxm = x_iter+dx_m; var nzm = z_iter+dz_m
							if map_data.is_valid_coord(nxm, nzm):
								if map_data.final_tile_type_map[nxm][nzm] == "mountain": max_neighbor_h_non_mountain = max(max_neighbor_h_non_mountain, read_only_visual_map[nxm][nzm]); found_mountain_neighbor = true
								elif map_data.final_tile_type_map[nxm][nzm] != "water": max_neighbor_h_non_mountain = max(max_neighbor_h_non_mountain, read_only_visual_map[nxm][nzm])
						up_clamp = max_neighbor_h_non_mountain if not found_mountain_neighbor else mountain_threshold_norm - 0.001
						if found_mountain_neighbor : up_clamp = max(up_clamp, read_only_visual_map[x_iter][z_iter]) 
						var low_clamp = flat_water_visual_norm_height + 0.01; var min_neighbor_h_non_water = current_h_lts; var found_water_neighbor = false
						for dx_l in [-1,0,1]: for dz_l in [-1,0,1]:
							var nxl = x_iter+dx_l; var nzl = z_iter+dz_l
							if map_data.is_valid_coord(nxl,nzl):
								if map_data.final_tile_type_map[nxl][nzl] == "water" or map_data.shore_tile_info_map[nxl][nzl].ring > 0: min_neighbor_h_non_water = min(min_neighbor_h_non_water, read_only_visual_map[nxl][nzl]); found_water_neighbor = true
								elif map_data.final_tile_type_map[nxl][nzl] != "mountain": min_neighbor_h_non_water = min(min_neighbor_h_non_water, read_only_visual_map[nxl][nzl])
						low_clamp = min_neighbor_h_non_water
						if found_water_neighbor: low_clamp = max(low_clamp, read_only_visual_map[x_iter][z_iter]) 
						map_data.visual_normalized_height_map[x_iter][z_iter] = clamp(new_h, low_clamp, up_clamp)

func apply_mountain_spikes():
	for x_spike in range(map_data.map_width): 
		for z_spike in range(map_data.map_depth): 
			if map_data.final_tile_type_map[x_spike][z_spike] == "mountain": 
				var cur_vis_h = map_data.visual_normalized_height_map[x_spike][z_spike]
				var spike_val = mountain_spike_noise.get_noise_2d(float(x_spike), float(z_spike))
				map_data.visual_normalized_height_map[x_spike][z_spike] = clamp(cur_vis_h + spike_val * mountain_spike_strength, mountain_threshold_norm, 1.0)

func apply_global_height_clamp():
	var max_allowed_visual_norm_diff = (1.0 / float(max_generation_height_levels)) * 1.5 
	for _pass_clamp in range(height_clamp_passes):
		var read_only_clamp_map: Array = []
		for x_r_c in range(map_data.map_width): read_only_clamp_map.append(map_data.visual_normalized_height_map[x_r_c].duplicate(true))
		
		for x_clamp in range(map_data.map_width):
			for z_clamp in range(map_data.map_depth):
				var current_h_clamp = read_only_clamp_map[x_clamp][z_clamp]; var adjusted_h = current_h_clamp 
				for dx_c_n in [-1, 0, 1]:
					for dz_c_n in [-1, 0, 1]:
						if dx_c_n == 0 and dz_c_n == 0: continue
						var nx_c = x_clamp + dx_c_n; var nz_c = z_clamp + dz_c_n
						if map_data.is_valid_coord(nx_c,nz_c):
							var neighbor_h = read_only_clamp_map[nx_c][nz_c]
							if adjusted_h > neighbor_h + max_allowed_visual_norm_diff: adjusted_h = min(adjusted_h, neighbor_h + max_allowed_visual_norm_diff) 
							elif adjusted_h < neighbor_h - max_allowed_visual_norm_diff: adjusted_h = max(adjusted_h, neighbor_h - max_allowed_visual_norm_diff) 
				map_data.visual_normalized_height_map[x_clamp][z_clamp] = adjusted_h

func _smoothstep_value(val: float) -> float:
	var t = clamp(val, 0.0, 1.0); return t * t * (3.0 - 2.0 * t)
func _inverse_lerp_clamped(a: float, b: float, v: float) -> float:
	if abs(b - a) < 0.00001: return 0.0 if v < a else 1.0
	return clamp((v - a) / (b - a), 0.0, 1.0)
