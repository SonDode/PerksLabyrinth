extends Node3D
class_name MazeBuilder

# ============================================================================
#  MazeBuilder.gd — Construiește geometria 3D a labirintului
#  Pe baza datelor din MazeGenerator, creează pereții (cuburi cu coliziune),
#  podeaua și tavanul, aplicând materialele texturate CC0. Fiecare perete e un
#  StaticBody3D, deci jucătorul se ciocnește de ele.
# ============================================================================

const CELL_SIZE: float = 4.0   # latura unei celule
const WALL_H:    float = 3.0   # înălțimea pereților
const WALL_T:    float = 0.3   # grosimea pereților

# Materialele pot fi setate în editor; dacă nu, se generează din texturi în cod
@export var wall_material:  StandardMaterial3D
@export var floor_material: StandardMaterial3D
@export var ceil_material:  StandardMaterial3D

var _maze: MazeGenerator

# Construiește tot labirintul: pentru fiecare celulă ridicăm pereții existenți
func build(maze: MazeGenerator) -> void:
	_maze = maze
	_ensure_materials()
	_clear()
	for y: int in maze.height:
		for x: int in maze.width:
			var cell: MazeGenerator.MazeCell = maze.get_cell(x, y)
			_build_cell(cell)
	_add_floor_ceiling(maze)

# Texturi CC0 (ambientCG) — generează materialele dacă nu sunt setate în editor
func _ensure_materials() -> void:
	if wall_material == null:
		wall_material = _make_mat(
			"res://assets/textures/wall_color.jpg",
			"res://assets/textures/wall_normal.jpg",
			Color.WHITE, Vector3(1.0, 1.0, 1.0))
	if floor_material == null:
		# uv1_scale = mărimea labirintului → textura se repetă o dată pe celulă
		floor_material = _make_mat(
			"res://assets/textures/floor_color.jpg",
			"res://assets/textures/floor_normal.jpg",
			Color.WHITE, Vector3(float(_maze.width), float(_maze.height), 1.0))
	if ceil_material == null:
		# Tavanul refolosește textura de zid, întunecată
		ceil_material = _make_mat(
			"res://assets/textures/wall_color.jpg", "",
			Color(0.4, 0.4, 0.48),
			Vector3(float(_maze.width) * 0.5, float(_maze.height) * 0.5, 1.0))

# Creează un material standard cu textură albedo (+ normal map opțional)
func _make_mat(color_path: String, normal_path: String, tint: Color, uv_scale: Vector3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var tex: Texture2D = load(color_path) as Texture2D
	if tex != null:
		m.albedo_texture = tex
	m.albedo_color = tint
	if normal_path != "":
		var nrm: Texture2D = load(normal_path) as Texture2D
		if nrm != null:
			m.normal_enabled = true        # relief 3D la lumină
			m.normal_texture = nrm
	m.uv1_scale = uv_scale
	m.roughness = 0.9
	return m

# Șterge geometria veche (la regenerarea unui nivel)
func _clear() -> void:
	for child: Node in get_children():
		child.queue_free()

# Ridică pereții existenți ai unei celule (N/E/S/V), poziționați pe muchii
func _build_cell(cell: MazeGenerator.MazeCell) -> void:
	var cx: float = float(cell.x) * CELL_SIZE
	var cz: float = float(cell.y) * CELL_SIZE

	if cell.walls[0]: # Nord
		_add_wall(Vector3(cx, 0.0, cz - CELL_SIZE * 0.5), Vector3(CELL_SIZE, WALL_H, WALL_T))
	if cell.walls[1]: # Est
		_add_wall(Vector3(cx + CELL_SIZE * 0.5, 0.0, cz), Vector3(WALL_T, WALL_H, CELL_SIZE))
	if cell.walls[2]: # Sud
		_add_wall(Vector3(cx, 0.0, cz + CELL_SIZE * 0.5), Vector3(CELL_SIZE, WALL_H, WALL_T))
	if cell.walls[3]: # Vest
		_add_wall(Vector3(cx - CELL_SIZE * 0.5, 0.0, cz), Vector3(WALL_T, WALL_H, CELL_SIZE))

# Creează un perete: corp static + mesh (cub) + formă de coliziune
func _add_wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var mesh_inst := MeshInstance3D.new()
	var col := CollisionShape3D.new()

	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	if wall_material != null:
		mesh_inst.material_override = wall_material

	var box_shape := BoxShape3D.new()
	box_shape.size = size
	col.shape = box_shape

	body.add_child(mesh_inst)
	body.add_child(col)
	body.position = pos + Vector3(0.0, WALL_H * 0.5, 0.0)   # ridicăm la jumătatea înălțimii
	add_child(body)

# Adaugă o podea și un tavan, fiecare un singur cub mare peste tot labirintul
func _add_floor_ceiling(maze: MazeGenerator) -> void:
	var total_w: float = float(maze.width)  * CELL_SIZE
	var total_h: float = float(maze.height) * CELL_SIZE
	var cx: float = float(maze.width  - 1) * CELL_SIZE * 0.5   # centrul labirintului
	var cz: float = float(maze.height - 1) * CELL_SIZE * 0.5

	# Podea
	var floor_body := StaticBody3D.new()
	var floor_mesh := MeshInstance3D.new()
	var floor_col  := CollisionShape3D.new()
	var floor_box  := BoxMesh.new()
	floor_box.size = Vector3(total_w, 0.2, total_h)
	floor_mesh.mesh = floor_box
	if floor_material != null:
		floor_mesh.material_override = floor_material
	var fs := BoxShape3D.new()
	fs.size = Vector3(total_w, 0.2, total_h)
	floor_col.shape = fs
	floor_body.add_child(floor_mesh)
	floor_body.add_child(floor_col)
	floor_body.position = Vector3(cx, -0.1, cz)   # ușor sub 0 → suprafața la y=0
	add_child(floor_body)

	# Tavan
	var ceil_body := StaticBody3D.new()
	var ceil_mesh := MeshInstance3D.new()
	var ceil_col  := CollisionShape3D.new()
	var ceil_box  := BoxMesh.new()
	ceil_box.size = Vector3(total_w, 0.2, total_h)
	ceil_mesh.mesh = ceil_box
	if ceil_material != null:
		ceil_mesh.material_override = ceil_material
	var cs := BoxShape3D.new()
	cs.size = Vector3(total_w, 0.2, total_h)
	ceil_col.shape = cs
	ceil_body.add_child(ceil_mesh)
	ceil_body.add_child(ceil_col)
	ceil_body.position = Vector3(cx, WALL_H + 0.1, cz)   # deasupra pereților
	add_child(ceil_body)

# Conversie grid → poziție în lume (utilitar)
func get_world_pos(gx: int, gy: int) -> Vector3:
	return Vector3(float(gx) * CELL_SIZE, 0.0, float(gy) * CELL_SIZE)
