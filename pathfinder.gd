# pathfinder.gd
extends Node
class_name Pathfinder

var grid: Dictionary = {} # Vector2i -> CustomTileData # << UPDATED
var map_size: Vector2i
var tile_dimensions: Vector3

const MOVE_DIAGONAL_COST = 1.414 
const MOVE_STRAIGHT_COST = 1.0   

func set_map_data(p_grid: Dictionary, p_map_size: Vector2i, p_tile_dimensions: Vector3):
	grid = p_grid
	map_size = p_map_size
	tile_dimensions = p_tile_dimensions
	print("Pathfinder received map data.")

func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return abs(a.x - b.x) + abs(a.y - b.y) 

func can_traverse(from_tile_data: CustomTileData, to_tile_data: CustomTileData, max_climb_height_levels: int = 1) -> bool: # << UPDATED
	if not from_tile_data or not to_tile_data:
		return false
	if not to_tile_data.walkable:
		return false
	
	var height_diff_levels = abs(from_tile_data.height_level - to_tile_data.height_level)
	return height_diff_levels <= max_climb_height_levels

func find_path(start_coords: Vector2i, goal_coords: Vector2i, max_climb_levels: int = 1) -> Array[Vector2i]:
	if not grid.has(start_coords) or not grid.has(goal_coords):
		printerr("Start or goal coordinates out of bounds.")
		return []

	var open_set: Array[Vector2i] = [start_coords]
	var came_from: Dictionary = {} 

	var g_score: Dictionary = {} 
	g_score[start_coords] = 0.0

	var f_score: Dictionary = {} 
	f_score[start_coords] = _heuristic(start_coords, goal_coords)

	while not open_set.is_empty():
		var current_coords = open_set[0]
		for node_coords in open_set:
			if f_score.get(node_coords, INF) < f_score.get(current_coords, INF):
				current_coords = node_coords
		
		if current_coords == goal_coords:
			return _reconstruct_path(came_from, current_coords)

		open_set.erase(current_coords)
		var current_tile_data: CustomTileData = grid[current_coords] # << UPDATED

		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue 

				var neighbor_coords = current_coords + Vector2i(dx, dz)

				if not grid.has(neighbor_coords): 
					continue
				
				var neighbor_tile_data: CustomTileData = grid[neighbor_coords] # << UPDATED

				if not can_traverse(current_tile_data, neighbor_tile_data, max_climb_levels):
					continue

				var move_cost = MOVE_STRAIGHT_COST if (dx == 0 or dz == 0) else MOVE_DIAGONAL_COST
				var tentative_g_score = g_score.get(current_coords, INF) + (move_cost * neighbor_tile_data.movement_cost)

				if tentative_g_score < g_score.get(neighbor_coords, INF):
					came_from[neighbor_coords] = current_coords
					g_score[neighbor_coords] = tentative_g_score
					f_score[neighbor_coords] = tentative_g_score + _heuristic(neighbor_coords, goal_coords)
					if not open_set.has(neighbor_coords):
						open_set.append(neighbor_coords)
	
	print("Path not found from ", start_coords, " to ", goal_coords)
	return [] 

func _reconstruct_path(came_from: Dictionary, current_coords: Vector2i) -> Array[Vector2i]:
	var total_path: Array[Vector2i] = [current_coords]
	var current = current_coords
	while came_from.has(current):
		current = came_from[current]
		total_path.push_front(current) 
	return total_path

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var start_test = Vector2i(5,5)
		var end_test = Vector2i(map_size.x - 5, map_size.y - 5)
		if grid.has(start_test) and grid.has(end_test):
			print("Attempting to find path from ", start_test, " to ", end_test)
			var path = find_path(start_test, end_test)
			if not path.is_empty():
				print("Path found: ", path)
			else:
				print("No path found or one of the points is invalid.")
		else:
			print("Test start/end points not valid for current map.")
