# foliage_item.gd
class_name FoliageItem
extends Resource

@export_group("Mesh & Basic Spawning")
@export var mesh: Mesh = null 
@export_range(0.0, 1.0, 0.01) var spawn_probability: float = 0.5

@export_group("Transform Randomization")
@export_range(0.01, 5.0, 0.01) var min_scale: float = 0.8
@export_range(0.01, 5.0, 0.01) var max_scale: float = 1.2
@export var random_rotation_y: bool = true
@export var align_to_slope: bool = false # Set to true to use raycast normal
@export_range(-0.5, 0.5, 0.01) var placement_offset_min_x: float = -0.25
@export_range(-0.5, 0.5, 0.01) var placement_offset_max_x: float = 0.25
@export_range(-0.5, 0.5, 0.01) var placement_offset_min_z: float = -0.25
@export_range(-0.5, 0.5, 0.01) var placement_offset_max_z: float = 0.25

@export_group("Raycast Placement")
# How high above the THEORETICAL tile top surface to start the ray.
# Make this large enough to be above any expected terrain variation.
@export var ray_start_y_offset: float = 5.0 
@export var max_ray_length: float = 10.0    # How far down the ray shoots.
# Applied AFTER raycast hit. Use this to sink roots or slightly lift.
# If your mesh origin is at its base, 0.0 should place the base at the hit point.
@export var vertical_offset: float = 0.0    

@export_group("Placement Conditions (Still relevant for initial filtering)")
@export_range(0.0, 1.0, 0.01) var min_tile_height_norm: float = 0.0
@export_range(0.0, 1.0, 0.01) var max_tile_height_norm: float = 1.0
@export_range(-1, 50, 1) var min_dist_to_water: int = -1
@export_range(-1, 50, 1) var max_dist_to_water: int = -1
# This max_slope_angle_degrees will be used with the raycast hit normal if align_to_slope is true
@export_range(-1, 90.0, 1.0) var max_slope_angle_degrees: float = 45.0 

func _init():
	if min_scale > max_scale: min_scale = max_scale
	if min_tile_height_norm > max_tile_height_norm: min_tile_height_norm = max_tile_height_norm
	if placement_offset_min_x > placement_offset_max_x: placement_offset_min_x = placement_offset_max_x
	if placement_offset_min_z > placement_offset_max_z: placement_offset_min_z = placement_offset_max_z
