# res://asset_utilities.gd
class_name AssetUtilities
extends RefCounted # Use RefCounted if it only contains static methods

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
	node_to_scale.global_transform = original_global_transform # Restore before applying new combined scale

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
	# print("AssetUtilities (radius): Node '", node_to_scale.name, "' final scale: ", node_to_scale.scale)


# --- NEW FUNCTION ---
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
	node_to_scale.scale = Vector3.ONE # Reset scale to get base AABB
	if node_to_scale.is_inside_tree():
		node_to_scale.force_update_transform() # Ensure AABB is calculated at scale 1

	# Important: get_node_visual_aabb_recursive returns AABB in *global space* if given identity transform
	# for the second arg, assuming the node_to_scale itself is at origin/no rotation.
	# For local AABB at scale 1, we might need a different approach or ensure node is temporarily at origin.
	# However, for non-uniformly scaled models, this can get tricky.
	# Let's assume get_aabb() on the MeshInstance3D itself is more reliable for its local bounds.
	
	var base_aabb_size = Vector3.ZERO
	var visual_found = false
	# Find the first significant VisualInstance3D to get its base AABB
	# This is a simplification; a complex model might need the recursive AABB at local Transform3D.IDENTITY
	for child_node in node_to_scale.get_children_recursive():
		if child_node is MeshInstance3D:
			var mi = child_node as MeshInstance3D
			if mi.mesh:
				base_aabb_size = mi.mesh.get_aabb().size # This AABB is local to the mesh, at its own scale (which is 1 here)
				visual_found = true
				break 
	if not visual_found and node_to_scale is MeshInstance3D: # If node_to_scale itself is the mesh
		var mi_root = node_to_scale as MeshInstance3D
		if mi_root.mesh:
			base_aabb_size = mi_root.mesh.get_aabb().size
			visual_found = true

	node_to_scale.global_transform = original_global_transform # Restore original transform before applying new scale

	if not visual_found or base_aabb_size == Vector3.ZERO:
		printerr("AssetUtilities (footprint): Could not get base AABB for '", node_to_scale.name, "'. Ensure it has a visible MeshInstance3D with a mesh.")
		return

	if base_aabb_size.x <= 0.001 or base_aabb_size.z <= 0.001:
		printerr("AssetUtilities (footprint): Node '", node_to_scale.name, "' base AABB dimensions (x or z) are too small or zero: ", base_aabb_size)
		return

	# Calculate target world dimensions based on footprint and tile size
	var target_world_width = float(target_footprint_tiles.x) * tile_dimensions.x
	var target_world_depth = float(target_footprint_tiles.y) * tile_dimensions.z # footprint.y maps to Z depth

	# Calculate required scale factors for x and z (y scale kept proportional or set differently)
	var scale_x = target_world_width / base_aabb_size.x
	var scale_z = target_world_depth / base_aabb_size.z
	
	# How to handle Y scale?
	# Option 1: Uniform scaling based on the smaller of x/z to maintain aspect ratio visually for XZ.
	# var uniform_xz_scale = min(scale_x, scale_z)
	# node_to_scale.scale = original_scale * Vector3(uniform_xz_scale, uniform_xz_scale, uniform_xz_scale)

	# Option 2: Scale X and Z independently, and Y proportionally to X (or Z, or average).
	# This will stretch/squash the model to fit the footprint exactly.
	var scale_y = scale_x # Or scale_z, or (scale_x + scale_z) / 2.0 to maintain some proportionality.
						  # If Z is the primary visual direction, maybe scale_y = scale_z

	node_to_scale.scale = original_scale * Vector3(scale_x, scale_y, scale_z)

	print("AssetUtilities (footprint): Node '", node_to_scale.name, 
		  "' BaseAABB: ", base_aabb_size, 
		  " TargetWorld: (", target_world_width, ", ", target_world_depth, ")",
		  " FinalCombinedScale: ", node_to_scale.scale)
