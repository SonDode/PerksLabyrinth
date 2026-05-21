extends Node
class_name MazeGenerator

# MazeGenerator.gd - Godot 4.6 compatible
# Generates a maze grid using Recursive Backtracking (DFS).

const NORTH: int = 0
const EAST:  int = 1
const SOUTH: int = 2
const WEST:  int = 3

class MazeCell:
	var walls: Array[bool] = [true, true, true, true]  # N E S W
	var visited: bool = false
	var item: String = ""
	var is_start: bool = false
	var is_exit: bool = false
	var x: int = 0
	var y: int = 0

var width: int  = 12
var height: int = 12
var grid: Array = []
var start_cell: MazeCell
var exit_cell: MazeCell

const DIR_VECTORS: Array = [
	Vector2i(0, -1),   # NORTH
	Vector2i(1,  0),   # EAST
	Vector2i(0,  1),   # SOUTH
	Vector2i(-1, 0),   # WEST
]
const OPPOSITE: Array[int] = [2, 3, 0, 1]  # SOUTH, WEST, NORTH, EAST

func generate(w: int = 12, h: int = 12) -> Array:
	width  = w
	height = h
	_init_grid()
	_carve_from(0, 0)
	_place_start_exit()
	_place_items()
	return grid

func _init_grid() -> void:
	grid.clear()
	for y: int in height:
		var row: Array = []
		for x: int in width:
			var cell: MazeCell = MazeCell.new()
			cell.x = x
			cell.y = y
			row.append(cell)
		grid.append(row)

func get_cell(x: int, y: int) -> MazeCell:
	if x < 0 or y < 0 or x >= width or y >= height:
		return null
	return grid[y][x]

func _carve_from(cx: int, cy: int) -> void:
	var cell: MazeCell = get_cell(cx, cy)
	cell.visited = true

	var directions: Array[int] = [NORTH, EAST, SOUTH, WEST]
	directions.shuffle()

	for dir: int in directions:
		var nx: int = cx + (DIR_VECTORS[dir] as Vector2i).x
		var ny: int = cy + (DIR_VECTORS[dir] as Vector2i).y
		var neighbor: MazeCell = get_cell(nx, ny)
		if neighbor != null and not neighbor.visited:
			cell.walls[dir] = false
			neighbor.walls[OPPOSITE[dir]] = false
			_carve_from(nx, ny)

func _place_start_exit() -> void:
	start_cell = get_cell(0, 0)
	start_cell.is_start = true
	exit_cell = get_cell(width - 1, height - 1)
	exit_cell.is_exit = true
	exit_cell.item = "exit"

func _place_items() -> void:
	var dead_ends: Array = []
	for y: int in height:
		for x: int in width:
			var cell: MazeCell = get_cell(x, y)
			if cell.is_start or cell.is_exit:
				continue
			var wall_count: int = 0
			for w: bool in cell.walls:
				if w:
					wall_count += 1
			if wall_count == 3:
				dead_ends.append(cell)

	dead_ends.shuffle()

	var item_pool: Array[String] = [
		"minimap_perk",
		"tunnel_perk",
		"compass_perk",
		"extra_life",
		"curse",
		"curse",
		"trap",
		"trap",
		"trap",
	]

	var placed: int = 0
	for item: String in item_pool:
		if placed >= dead_ends.size():
			break
		(dead_ends[placed] as MazeCell).item = item
		placed += 1

	var remaining_cells: Array = []
	for y: int in height:
		for x: int in width:
			var cell: MazeCell = get_cell(x, y)
			if cell.item == "" and not cell.is_start and not cell.is_exit:
				remaining_cells.append(cell)
	remaining_cells.shuffle()

	var extra_traps: int = mini(4, remaining_cells.size())
	for i: int in extra_traps:
		(remaining_cells[i] as MazeCell).item = "trap"
