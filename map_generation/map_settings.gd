# map_settings.gd
extends Resource
class_name MapSettings

@export_group("Map Configuration")
@export var map_width: int = 200
@export var map_depth: int = 200
@export var seed: int = 0
@export_range(0.01, 1.0, 0.01) var tile_scale_factor: float = 0.1
@export_range(1, 50, 1) var max_generation_height_levels := 25

@export_group("Noise Parameters")
@export var height_noise_scale: float = 0.008 # Renamed for clarity
@export var moisture_noise_scale: float = 0.01
@export var mountain_spike_noise_frequency: float = 0.1
@export_range(0.0, 0.3, 0.01) var mountain_spike_strength: float = 0.05
@export var rock_cluster_noise_scale: float = 0.05

@export_group("Transition Rings & Shoreline")
@export_range(0, 5, 1) var land_transition_passes: int = 3
@export_range(0.1, 0.7, 0.05) var land_transition_step_factor: float = 0.33
@export_range(0, 3, 1) var shoreline_width: int = 2

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
@export var flower_scene_variants: Array[PackedScene] = []
@export_range(0.0, 1.0, 0.001) var grass_tile_flower_chance: float = 0.03
@export var plains_tree_scene_variants: Array[PackedScene] = []
@export_range(0.0, 1.0, 0.001) var grass_tile_plains_tree_chance: float = 0.005
@export var tree_scene_variants: Array[PackedScene] = []
@export_range(0.0, 1.0, 0.001) var forest_tile_tree_chance: float = 0.7
@export var large_rock_cluster_scene_variants: Array[PackedScene] = []
@export_range(0.0, 1.0, 0.01) var rock_cluster_threshold: float = 0.7
@export_range(0.0, 0.5, 0.01) var major_prop_max_offset_factor: float = 0.3
