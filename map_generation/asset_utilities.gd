# res://asset_utilities.gd
class_name AssetUtilities
extends Node
static func get_node_visual_aabb_recursive(node: Node3D, current_transform_to_node: Transform3D) -> AABB:
	var combined_aabb := AABB()
	var first_visual_found := false

	if node is VisualInstance3D:
		var visual_node := node as VisualInstance3D
		var visual_aabb_local = visual_node.get_aabb()
		var visual_aabb_transformed = current_transform_to_node * visual_aabb_local
		combined_aabb = visual_aabb_transformed
		first_visual_found = true

	for i in range(node.get_child_count()):
		var child = node.get_child(i)
		if child is Node3D:
			var child_node_3d := child as Node3D
			var child_overall_transform = current_transform_to_node * child_node_3d.transform
			var child_aabb_contribution = get_node_visual_aabb_recursive(child_node_3d, child_overall_transform)

			if child_aabb_contribution.size != Vector3.ZERO:
				if first_visual_found:
					combined_aabb = combined_aabb.merge(child_aabb_contribution)
				else:
					combined_aabb = child_aabb_contribution
					first_visual_found = true
	return combined_aabb

static func scale_node_to_tile_radius(node_to_scale: Node3D, target_tile_radius: float, tile_xz_dimension: float) -> void:
	if not is_instance_valid(node_to_scale) or target_tile_radius <= 0 or tile_xz_dimension <= 0:
		printerr("AssetUtilities (radius): Invalid args. Node: ", node_to_scale, " Rad: ", target_tile_radius, " Dim: ", tile_xz_dimension)
		return

	var original_global_transform := node_to_scale.global_transform
	var original_scale := node_to_scale.scale
	node_to_scale.scale = Vector3.ONE
	if node_to_scale.is_inside_tree(): node_to_scale.force_update_transform()

	var visual_aabb_at_one_scale = get_node_visual_aabb_recursive(node_to_scale, Transform3D.IDENTITY)
	node_to_scale.global_transform = original_global_transform

	if visual_aabb_at_one_scale.size == Vector3.ZERO:
		printerr("AssetUtilities (radius): Could not get AABB for '", node_to_scale.name, "'.")
		return

	var current_max_xz_dimension = max(visual_aabb_at_one_scale.size.x, visual_aabb_at_one_scale.size.z)
	if current_max_xz_dimension <= 0.001:
		printerr("AssetUtilities (radius): Node '", node_to_scale.name, "' base XZ too small: ", current_max_xz_dimension)
		return
		
	var target_diameter_world_units = target_tile_radius * 2.0 * tile_xz_dimension
	var required_scale_factor = target_diameter_world_units / current_max_xz_dimension
	node_to_scale.scale = original_scale * required_scale_factor

static func scale_node_to_footprint_tiles(node_to_scale: Node3D,
										  target_footprint_tiles: Vector2i,
										  tile_dimensions: Vector3) -> void:
	if not is_instance_valid(node_to_scale) or \
	   target_footprint_tiles.x <= 0 or target_footprint_tiles.y <= 0 or \
	   tile_dimensions.x <= 0 or tile_dimensions.z <= 0:
		printerr("AssetUtilities (footprint): Invalid args. Node: ", node_to_scale,
				 " Footprint: ", target_footprint_tiles, " TileDims: ", tile_dimensions)
		return

	var original_global_transform := node_to_scale.global_transform
	var original_scale := node_to_scale.scale
	node_to_scale.scale = Vector3.ONE
	if node_to_scale.is_inside_tree():
		node_to_scale.force_update_transform()

	var base_aabb_at_one_scale = get_node_visual_aabb_recursive(node_to_scale, Transform3D.IDENTITY)
	var base_aabb_size = base_aabb_at_one_scale.size
	
	node_to_scale.global_transform = original_global_transform

	if base_aabb_size == Vector3.ZERO:
		printerr("AssetUtilities (footprint): Could not get base AABB for '", node_to_scale.name, "'. Ensure it has a visible MeshInstance3D with a mesh.")
		return

	if base_aabb_size.x <= 0.001 or base_aabb_size.z <= 0.001:
		printerr("AssetUtilities (footprint): Node '", node_to_scale.name, "' base AABB dimensions (x or z) are too small or zero: ", base_aabb_size)
		return

	var target_world_width = float(target_footprint_tiles.x) * tile_dimensions.x
	var target_world_depth = float(target_footprint_tiles.y) * tile_dimensions.z

	var scale_x = target_world_width / base_aabb_size.x
	var scale_z = target_world_depth / base_aabb_size.z
	
	# For Y-scale, let's try to maintain original proportions relative to the XZ scaling.
	# If base_aabb_size.y is valid, scale it proportionally to the average of X and Z scales.
	# This is one option; another is to keep original_scale.y or scale it like scale_x.
	var scale_y = original_scale.y # Default to keeping original Y scale factor
	if base_aabb_size.y > 0.001:
		# Option: Scale Y proportionally to how XZ was scaled on average
		# var avg_xz_base_dim = (base_aabb_size.x + base_aabb_size.z) / 2.0
		# var avg_xz_target_dim = (target_world_width + target_world_depth) / 2.0
		# if avg_xz_base_dim > 0.001:
		#    scale_y = (avg_xz_target_dim / avg_xz_base_dim)
		# This might be too complex. A simpler approach:
		scale_y = (scale_x + scale_z) / 2.0 # Scale Y by the average of X and Z factors

	node_to_scale.scale = original_scale * Vector3(scale_x, scale_y, scale_z)

	print_debug("AssetUtilities (footprint): Node '", node_to_scale.name,
		  "' BaseAABB: ", base_aabb_size,
		  " TargetWorld: (", target_world_width, ", ", target_world_depth, ")",
		  " FinalCombinedScale: ", node_to_scale.scale)
