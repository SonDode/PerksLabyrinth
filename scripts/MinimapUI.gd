extends Control
class_name MinimapUI

# ============================================================================
#  MinimapUI.gd — Minimapa 2D
#  Desenează labirintul de sus (pereți, obiecte, ieșire, punctul jucătorului).
#  Doar celulele „dezvăluite" (vizitate) se văd clar — așa harta se descoperă
#  pe măsură ce explorezi. Devine vizibilă după ce iei perk-ul de minimapă.
# ============================================================================

@export var cell_px: int = 12                          # mărimea unei celule în pixeli (recalculată în setup)
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
var _revealed: Array[Vector2i] = []   # celulele descoperite până acum

func _ready() -> void:
	visible = false
	GameManager.perk_unlocked.connect(_on_perk_unlocked)

# Pregătește minimapa pentru un labirint; target_px = lățimea dorită în pixeli
func setup(maze: MazeGenerator, target_px: float = 150.0) -> void:
	_maze = maze
	_revealed.clear()
	# Mărimea unei celule se adaptează la dimensiunea labirintului ca să încapă în casetă
	cell_px = maxi(4, int(target_px / float(maxi(maze.width, maze.height))))
	custom_minimum_size = Vector2(
		float(maze.width  * cell_px + 2),
		float(maze.height * cell_px + 2)
	)
	queue_redraw()

# Mută punctul jucătorului și marchează celula curentă ca descoperită
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

# Cheat admin: dezvăluie tot labirintul + ieșirea
func reveal_all() -> void:
	if _maze == null:
		return
	visible = true
	for y: int in _maze.height:
		for x: int in _maze.width:
			var v := Vector2i(x, y)
			if not _revealed.has(v):
				_revealed.append(v)
	queue_redraw()

# Desenarea propriu-zisă (apelată automat de Godot la queue_redraw)
func _draw() -> void:
	if _maze == null:
		return

	var cpx: float = float(cell_px)
	var wall_thick: float = maxf(1.0, cpx / 8.0)

	for y: int in _maze.height:
		for x: int in _maze.width:
			var cell: MazeGenerator.MazeCell = _maze.get_cell(x, y)
			var rx: float = float(x) * cpx + 1.0
			var ry: float = float(y) * cpx + 1.0
			var rect := Rect2(rx, ry, cpx, cpx)

			var visited: bool = _revealed.has(Vector2i(x, y))

			# Podeaua celulei: mai luminoasă dacă a fost descoperită
			var fc: Color = floor_color if visited else Color(0.05, 0.05, 0.08)
			draw_rect(rect, fc)

			# Marcaj pentru obiect (vizibil dacă ai fost acolo sau ai viziune-tunel)
			if cell.item != "" and (visited or GameManager.has_perk("tunnel_vision")):
				var ic: Color = _item_color(cell.item)
				draw_rect(Rect2(
					rx + cpx / 4.0,
					ry + cpx / 4.0,
					cpx / 2.0,
					cpx / 2.0
				), ic)

			# Pereții celulei
			if cell.walls[0]: # Nord
				draw_line(Vector2(rx, ry), Vector2(rx + cpx, ry), wall_color, wall_thick)
			if cell.walls[1]: # Est
				draw_line(Vector2(rx + cpx, ry), Vector2(rx + cpx, ry + cpx), wall_color, wall_thick)
			if cell.walls[2]: # Sud
				draw_line(Vector2(rx, ry + cpx), Vector2(rx + cpx, ry + cpx), wall_color, wall_thick)
			if cell.walls[3]: # Vest
				draw_line(Vector2(rx, ry), Vector2(rx, ry + cpx), wall_color, wall_thick)

	# Marcaj pentru ieșire
	if _maze.exit_cell != null:
		var ex: float = float(_maze.exit_cell.x) * cpx + 1.0
		var ey: float = float(_maze.exit_cell.y) * cpx + 1.0
		draw_rect(Rect2(ex + 2.0, ey + 2.0, cpx - 4.0, cpx - 4.0), exit_color)

	# Punctul jucătorului
	var px: float = float(_player_gx) * cpx + 1.0 + cpx / 2.0
	var py: float = float(_player_gy) * cpx + 1.0 + cpx / 2.0
	draw_circle(Vector2(px, py), cpx / 3.0, player_color)

# Culoarea marcajului în funcție de tipul obiectului
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
