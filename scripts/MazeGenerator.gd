extends Node
class_name MazeGenerator

# ============================================================================
#  MazeGenerator.gd — Generarea procedurală a labirintului
#  Folosește algoritmul „Recursive Backtracking" (DFS): pornește dintr-o celulă,
#  sapă pereți spre vecini nevizitați aleși la întâmplare, până acoperă tot.
#  Tot aici se plasează start/ieșire și obiectele, și se face pathfinding-ul
#  (BFS) folosit de Gardian.
# ============================================================================

# Indici pentru cei 4 pereți ai unei celule
const NORTH: int = 0
const EAST:  int = 1
const SOUTH: int = 2
const WEST:  int = 3

# O celulă a labirintului
class MazeCell:
	var walls: Array[bool] = [true, true, true, true]  # pereți: N E S W (true = există)
	var visited: bool = false   # folosit la generare
	var item: String = ""       # ce obiect e pe celulă ("" = nimic)
	var is_start: bool = false
	var is_exit: bool = false
	var x: int = 0
	var y: int = 0

var width: int  = 12
var height: int = 12
var grid: Array = []          # matrice de MazeCell [y][x]
var start_cell: MazeCell
var exit_cell: MazeCell

# Vectori de deplasare pentru fiecare direcție (aceeași ordine ca pereții)
const DIR_VECTORS: Array = [
	Vector2i(0, -1),   # NORTH
	Vector2i(1,  0),   # EAST
	Vector2i(0,  1),   # SOUTH
	Vector2i(-1, 0),   # WEST
]
# Peretele opus: dacă dărâm N la mine, dărâm S la vecin etc.
const OPPOSITE: Array[int] = [2, 3, 0, 1]  # SOUTH, WEST, NORTH, EAST

# Punctul de intrare: generează un labirint w×h și plasează obiectele
func generate(w: int = 12, h: int = 12, extra_life_count: int = 2, curse_count: int = 2, trap_count: int = 3) -> Array:
	width  = w
	height = h
	_init_grid()
	_carve_from(0, 0)          # sapă labirintul
	_place_start_exit()
	_place_items(extra_life_count, curse_count, trap_count)
	return grid

# Umple grila cu celule complet închise (toți pereții prezenți)
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

# Întoarce celula de la (x,y) sau null dacă e în afara grilei
func get_cell(x: int, y: int) -> MazeCell:
	if x < 0 or y < 0 or x >= width or y >= height:
		return null
	return grid[y][x]

# BFS prin labirint (respectând pereții) — întoarce PRIMA celulă spre țintă.
# Folosit de Gardian pentru urmărirea jucătorului. Dacă nu există drum, întoarce start.
func next_step_toward(sx: int, sy: int, tx: int, ty: int) -> Vector2i:
	var start := Vector2i(sx, sy)
	var goal  := Vector2i(tx, ty)
	if start == goal:
		return start

	var came_from: Dictionary = {}            # de unde am ajuns în fiecare celulă
	var visited: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var found: bool = false

	# Explorare în lățime (BFS) până găsim ținta
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == goal:
			found = true
			break
		var cell: MazeCell = get_cell(cur.x, cur.y)
		if cell == null:
			continue
		for d: int in 4:
			if cell.walls[d]:        # nu putem trece prin perete
				continue
			var dv: Vector2i = DIR_VECTORS[d]
			var nb := Vector2i(cur.x + dv.x, cur.y + dv.y)
			if get_cell(nb.x, nb.y) == null or visited.has(nb):
				continue
			visited[nb] = true
			came_from[nb] = cur
			queue.append(nb)

	if not found:
		return start

	# Mergem înapoi de la țintă până la celula vecină cu start = primul pas
	var node: Vector2i = goal
	while came_from.has(node) and came_from[node] != start:
		node = came_from[node]
	if came_from.has(node):
		return node
	return start

# Săpare recursivă (DFS): din celula curentă, mergem la vecini nevizitați aleatori
func _carve_from(cx: int, cy: int) -> void:
	var cell: MazeCell = get_cell(cx, cy)
	cell.visited = true

	var directions: Array[int] = [NORTH, EAST, SOUTH, WEST]
	directions.shuffle()   # ordine aleatorie → labirint diferit de fiecare dată

	for dir: int in directions:
		var nx: int = cx + (DIR_VECTORS[dir] as Vector2i).x
		var ny: int = cy + (DIR_VECTORS[dir] as Vector2i).y
		var neighbor: MazeCell = get_cell(nx, ny)
		if neighbor != null and not neighbor.visited:
			# Dărâmă peretele dintre cele două celule (în ambele sensuri)
			cell.walls[dir] = false
			neighbor.walls[OPPOSITE[dir]] = false
			_carve_from(nx, ny)

# Start în colțul (0,0), ieșire în colțul opus (width-1, height-1)
func _place_start_exit() -> void:
	start_cell = get_cell(0, 0)
	start_cell.is_start = true
	exit_cell = get_cell(width - 1, height - 1)
	exit_cell.is_exit = true
	exit_cell.item = "exit"

# Numără câți pereți are o celulă (3 pereți = fundătură)
func _wall_count(cell: MazeCell) -> int:
	var n: int = 0
	for w: bool in cell.walls:
		if w:
			n += 1
	return n

# Plasează obiectele în labirint
func _place_items(extra_life_count: int, curse_count: int, trap_count: int) -> void:
	# Separăm fundăturile (3 pereți) de restul celulelor
	var dead_ends: Array = []
	var others:    Array = []
	for y: int in height:
		for x: int in width:
			var cell: MazeCell = get_cell(x, y)
			if cell.is_start or cell.is_exit:
				continue
			if _wall_count(cell) == 3:
				dead_ends.append(cell)
			else:
				others.append(cell)
	dead_ends.shuffle()
	others.shuffle()

	# Fundăturile au prioritate pentru perks/recompense (te încurajează să explorezi)
	var candidates: Array = dead_ends + others

	# Pool prioritar: perks (mereu prezente) + vieți + blesteme
	var pool: Array[String] = ["minimap_perk", "tunnel_perk", "compass_perk"]
	for _i: int in extra_life_count:
		pool.append("extra_life")
	for _i: int in curse_count:
		pool.append("curse")

	# Așază pe rând obiectele din pool în celulele candidate
	var ci: int = 0
	for item: String in pool:
		if ci >= candidates.size():
			break
		(candidates[ci] as MazeCell).item = item
		ci += 1

	# Capcanele umplu celulele rămase (până la trap_count)
	var placed_traps: int = 0
	while ci < candidates.size() and placed_traps < trap_count:
		var c: MazeCell = candidates[ci] as MazeCell
		if c.item == "":
			c.item = "trap"
			placed_traps += 1
		ci += 1
