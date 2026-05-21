extends Control
class_name MinimapUI

# MinimapUI.gd - Godot 4.6 compatible
# Draws a 2D minimap of the maze.

@export var cell_px: int = 12
@export var wall_color:   Color = Color(0.8, 0.8, 0.8)
@export var floor_color:  Color = Color(0.1, 0.1, 0.15)
@export var player_color: Color = Color(0.2, 0.9, 0.4)
@export var exit_color:   Color = Color(0.0, 1.0, 0.4)
@export var perk_color:   Color = Color(0.2, 0.7, 1.0)
@export var trap_color:   Color = Color(1.0, 0.4, 0.0)
@export var curse_color:  Color = Color(0.7, 0.0, 0.9)

var _maze: MazeGenerator = null
var _player_gx: int = 0
var _player_gy: int = 0
var _revealed: Array[Vector2i] = []

func _ready() -> void:
	visible = false
	GameManager.perk_unlocked.connect(_on_perk_unlocked)

func setup(maze: MazeGenerator) -> void:
	_maze = maze
	_revealed.clear()
	custom_minimum_size = Vector2(
		float(maze.width  * cell_px + 2),
		float(maze.height * cell_px + 2)
	)
	queue_redraw()

func update_player(gx: int, gy: int) -> void:
	_player_gx = gx
	_player_gy = gy
	var v := Vector2i(gx, gy)
	if not _revealed.has(v):
		_revealed.append(v)
	queue_redraw()

func _on_perk_unlocked(perk_name: String) -> void:
	if perk_name == "minimap":
		visible = true
		queue_redraw()

func _draw() -> void:
	if _maze == null:
		return

	var wall_thick: int = maxi(1, cell_px / 8)

	for y: int in _maze.height:
		for x: int in _maze.width:
			var cell: MazeGenerator.MazeCell = _maze.get_cell(x, y)
			var rx: int = x * cell_px + 1
			var ry: int = y * cell_px + 1
			var rect := Rect2(float(rx), float(ry), float(cell_px), float(cell_px))

			var visited: bool = _revealed.has(Vector2i(x, y))

			# Floor
			var fc: Color = floor_color if visited else Color(0.05, 0.05, 0.08)
			draw_rect(rect, fc)

			# Item indicators
			if cell.item != "" and (visited or GameManager.has_perk("tunnel_vision")):
				var ic: Color = _item_color(cell.item)
				draw_rect(Rect2(
					float(rx + cell_px / 4),
					float(ry + cell_px / 4),
					float(cell_px / 2),
					float(cell_px / 2)
				), ic)

			# Walls
			var wt: float = float(wall_thick)
			if cell.walls[0]: # North
				draw_line(Vector2(float(rx), float(ry)), Vector2(float(rx + cell_px), float(ry)), wall_color, wt)
			if cell.walls[1]: # East
				draw_line(Vector2(float(rx + cell_px), float(ry)), Vector2(float(rx + cell_px), float(ry + cell_px)), wall_color, wt)
			if cell.walls[2]: # South
				draw_line(Vector2(float(rx), float(ry + cell_px)), Vector2(float(rx + cell_px), float(ry + cell_px)), wall_color, wt)
			if cell.walls[3]: # West
				draw_line(Vector2(float(rx), float(ry)), Vector2(float(rx), float(ry + cell_px)), wall_color, wt)

	# Exit marker
	if _maze.exit_cell != null:
		var ex: int = _maze.exit_cell.x * cell_px + 1
		var ey: int = _maze.exit_cell.y * cell_px + 1
		draw_rect(Rect2(float(ex + 2), float(ey + 2), float(cell_px - 4), float(cell_px - 4)), exit_color)

	# Player dot
	var px: float = float(_player_gx * cell_px + 1 + cell_px / 2)
	var py: float = float(_player_gy * cell_px + 1 + cell_px / 2)
	draw_circle(Vector2(px, py), float(cell_px) / 3.0, player_color)

func _item_color(item_type: String) -> Color:
	match item_type:
		"minimap_perk", "tunnel_perk", "compass_perk":
			return perk_color
		"extra_life":
			return Color(1.0, 0.3, 0.3)
		"curse":
			return curse_color
		"trap":
			return trap_color
		"exit":
			return exit_color
	return Color.WHITE
