extends Node3D
class_name Guardian

# ============================================================================
#  Guardian.gd — NPC-ul (inamic) cu inteligență artificială
#  Te urmărește prin labirint folosind pathfinding BFS (MazeGenerator.
#  next_step_toward), mergând din celulă în celulă pe cel mai scurt drum spre
#  tine. Când te prinde, pierzi o viață și el se retrage la punctul de start.
# ============================================================================

@export var move_speed: float = 3.5
@export var cell_size:  float = 4.0
@export var catch_dist: float = 1.1   # distanță XZ la care te prinde

var _maze:   MazeGenerator = null
var _player: Player        = null

var grid_x: int = 0    # celula curentă a gardianului
var grid_y: int = 0
var _spawn_gx: int = 0 # celula de apariție (unde se retrage după ce te prinde)
var _spawn_gy: int = 0

var _target_pos: Vector3 = Vector3.ZERO   # poziția spre care se deplasează acum
var _has_target: bool    = false
var _catch_cooldown: float = 0.0          # timp de „imunitate" după ce te-a prins
var _active: bool = true                  # devine false la final de joc/nivel

var _mesh:  MeshInstance3D = null
var _light: OmniLight3D    = null
var _bob:   float = 0.0                    # faza animației de plutire

func _ready() -> void:
	_build_visuals()

# Construiește aspectul prin cod: capsulă cu textură de lavă + ochi + lumină mov
func _build_visuals() -> void:
	_mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.4
	_mesh.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color     = Color(0.18, 0.1, 0.25)   # corp întunecat
	mat.emission_enabled = true
	mat.emission         = Color(0.7, 0.3, 1.0)
	mat.emission_energy_multiplier = 2.5
	# Textură CC0 (lavă) — crăpături luminoase, tentă mov, ca o piatră vie
	var skin: Texture2D = load("res://assets/textures/npc_color.jpg") as Texture2D
	if skin != null:
		mat.albedo_texture   = skin
		mat.emission_texture = skin   # crăpăturile lucesc mov
	_mesh.material_override = mat
	add_child(_mesh)

	# Doi „ochi" mici galbeni ca să pară o creatură
	for sx: float in [-0.12, 0.12]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.06
		es.height = 0.12
		eye.mesh = es
		var em := StandardMaterial3D.new()
		em.emission_enabled = true
		em.emission = Color(1.0, 1.0, 0.3)
		em.albedo_color = Color(1.0, 1.0, 0.3)
		eye.material_override = em
		eye.position = Vector3(sx, 0.35, -0.32)
		_mesh.add_child(eye)

	# Lumină proprie ca să fie vizibil în întuneric
	_light = OmniLight3D.new()
	_light.light_color  = Color(0.6, 0.35, 1.0)
	_light.light_energy = 2.0
	_light.omni_range   = 6.0
	_light.position     = Vector3(0.0, 0.5, 0.0)
	add_child(_light)

# Inițializare (apelat din Game.gd): unde apare, pe cine urmărește, cât de rapid
func setup(maze: MazeGenerator, player: Player, start_gx: int, start_gy: int, speed: float) -> void:
	_maze       = maze
	_player     = player
	move_speed  = speed
	grid_x      = start_gx
	grid_y      = start_gy
	_spawn_gx   = start_gx
	_spawn_gy   = start_gy
	position    = Vector3(float(start_gx) * cell_size, 0.9, float(start_gy) * cell_size)
	_target_pos = position
	_has_target = false

# Oprește gardianul (la game over / nivel complet)
func stop() -> void:
	_active = false

func _process(delta: float) -> void:
	if not _active or _maze == null or _player == null:
		return

	_catch_cooldown = maxf(0.0, _catch_cooldown - delta)

	# Animație: plutire (sus-jos) + rotație lentă
	_bob += delta * 3.0
	if _mesh != null:
		_mesh.position.y = sin(_bob) * 0.12
		_mesh.rotation.y += delta * 1.5

	# Dacă are o celulă-țintă, se deplasează spre ea; altfel calculează următorul pas
	if _has_target:
		position = position.move_toward(_target_pos, move_speed * delta)
		if position.distance_to(_target_pos) < 0.05:
			position = _target_pos
			grid_x = int(round(position.x / cell_size))
			grid_y = int(round(position.z / cell_size))
			_has_target = false
	else:
		_pick_next_step()

	_check_catch()

# Cere de la labirint următoarea celulă pe cel mai scurt drum spre jucător (BFS)
func _pick_next_step() -> void:
	var nxt: Vector2i = _maze.next_step_toward(grid_x, grid_y, _player.grid_x, _player.grid_y)
	if nxt.x == grid_x and nxt.y == grid_y:
		return   # deja pe celula jucătorului sau fără drum
	_target_pos = Vector3(float(nxt.x) * cell_size, 0.9, float(nxt.y) * cell_size)
	_has_target = true

# Verifică dacă a ajuns suficient de aproape ca să te „prindă"
func _check_catch() -> void:
	if _catch_cooldown > 0.0:
		return
	var dx: float = position.x - _player.global_position.x
	var dz: float = position.z - _player.global_position.z
	if Vector2(dx, dz).length() < catch_dist:
		_catch_cooldown = 2.0
		GameManager.lose_life("guardian")
		_notify_caught()
		# Se retrage la spawn ca să nu golească toate viețile dintr-o dată
		grid_x = _spawn_gx
		grid_y = _spawn_gy
		position = Vector3(float(_spawn_gx) * cell_size, 0.9, float(_spawn_gy) * cell_size)
		_target_pos = position
		_has_target = false

# Afișează un mesaj pe HUD când te-a prins
func _notify_caught() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var huds := tree.get_nodes_in_group("hud")
	if huds.size() > 0:
		(huds[0] as HUD).show_notification("👹 Gardianul te-a prins! -1 viață", Color(1.0, 0.3, 0.3))
