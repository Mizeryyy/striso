# res://map_manager.gd
extends Node
class_name MapManager

# Define the dimensions of a single tile in world units
const TILE_DIMENSIONS_WORLD: Vector3 = Vector3(2.0, 0.5, 2.0) # Example: 2x2 wide/deep, 0.5 high

# Simple conversion for this test
func grid_to_world_center(grid_coords: Vector2i) -> Vector3:
	var world_x = (float(grid_coords.x) + 0.5) * TILE_DIMENSIONS_WORLD.x
	var world_z = (float(grid_coords.y) + 0.5) * TILE_DIMENSIONS_WORLD.z # grid_coords.y maps to world Z
	var world_y = 0.0 # Assuming flat ground for this test, at Y=0 for the base of the tile
					  # The unit's own height/collision will place it on top.
	return Vector3(world_x, world_y, world_z)

func get_tile_dimensions() -> Vector3:
	return TILE_DIMENSIONS_WORLD
