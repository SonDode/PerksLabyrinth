extends CharacterBody3D
class_name Player

# ============================================================================
#  Player.gd — Jucătorul (vedere first-person)
#  Mișcare continuă și fluidă: W/S = înainte/înapoi, A/D = strafe lateral,
#  mouse = rotire privire, Space = săritură. Are gravitație reală și coliziune
#  cu pereții (CharacterBody3D + move_and_slide). Ține minte pe ce celulă din
#  labirint se află și anunță prin semnal când trece în altă celulă.
# ============================================================================

signal cell_entered(cell_x: int, cell_y: int)   # emis când jucătorul intră într-o celulă nouă

@export var move_speed:    float = 5.0    # viteza de mers (unități/secundă)
@export var accel:         float = 40.0   # cât de repede atinge viteza maximă
@export var cell_size:     float = 4.0    # latura unei celule de labirint (în unități)
@export var gravity:       float = 24.0   # gravitație reală
@export var jump_velocity: float = 7.0    # impulsul săriturii (Space)

@onready var camera: Camera3D    = $Camera3D     # camera (copil → se rotește cu jucătorul)
@onready var _light: OmniLight3D = $OmniLight3D  # felinarul jucătorului

# Poziția pe grila labirintului (nu în lume)
var grid_x: int = 0
var grid_y: int = 0

var _yaw:         float         = 0.0   # rotația continuă pe Y (radiani)
var _maze_ref:   MazeGenerator = null  # referință la labirint (pt. limite)
var _nearby_item: ItemPickup   = null  # obiectul de lângă care poți apăsa E

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)   # ascunde+blochează cursorul pentru mouse-look

# Poziționează jucătorul la începutul nivelului (apelat din Game.gd)
func setup(maze: MazeGenerator, start_gx: int, start_gy: int) -> void:
	_maze_ref       = maze
	grid_x          = start_gx
	grid_y          = start_gy
	global_position = Vector3(float(start_gx) * cell_size, 0.9, float(start_gy) * cell_size)
	velocity        = Vector3.ZERO
	_yaw            = deg_to_rad(-90.0)   # privire spre est
	rotation.y      = _yaw

# Setat de ItemPickup când intri/ieși din raza unui obiect „bun"
func set_nearby_item(item: ItemPickup) -> void:
	_nearby_item = item

# Reglează felinarul jucătorului (raza scade pe nivelul 2 = mai întuneric)
func set_light(rng: float, energy: float) -> void:
	if _light != null:
		_light.omni_range   = rng
		_light.light_energy = energy

# Folosit de busolă ca să știe direcția în care privești
func get_facing_yaw() -> float:
	return _yaw

# ── Mouse look: rotire continuă, sensibilitatea vine din setări ─────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * GameManager.mouse_sensitivity
		rotation.y = _yaw

# ── Fizică: mișcare continuă cu coliziune și alunecare pe pereți ────────────────
func _physics_process(delta: float) -> void:
	# Interacțiune cu E (doar obiectele bune setează _nearby_item)
	if Input.is_action_just_pressed("interact") and _nearby_item != null:
		_nearby_item.interact()

	# Direcțiile înainte/dreapta, relative la privire, proiectate pe orizontală
	var forward: Vector3 = -global_transform.basis.z
	var right:   Vector3 =  global_transform.basis.x
	forward.y = 0.0
	right.y   = 0.0
	forward = forward.normalized()
	right   = right.normalized()

	# Adună direcția dorită din tastele apăsate
	var wish: Vector3 = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		wish += forward
	if Input.is_action_pressed("move_backward"):
		wish -= forward
	if Input.is_action_pressed("move_right"):    # D = strafe dreapta
		wish += right
	if Input.is_action_pressed("move_left"):     # A = strafe stânga
		wish -= right
	wish = wish.normalized()

	# Accelerare/decelerare lină spre viteza dorită (doar pe orizontală)
	var target: Vector3 = wish * move_speed
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)

	# Gravitație reală + săritură
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
		else:
			velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	move_and_slide()        # mută corpul respectând coliziunile
	_update_grid_cell()     # actualizează celula curentă

# Calculează pe ce celulă ești și, dacă s-a schimbat, anunță prin semnal
func _update_grid_cell() -> void:
	if _maze_ref == null:
		return
	var ngx: int = clampi(int(round(global_position.x / cell_size)), 0, _maze_ref.width  - 1)
	var ngy: int = clampi(int(round(global_position.z / cell_size)), 0, _maze_ref.height - 1)
	if ngx != grid_x or ngy != grid_y:
		grid_x = ngx
		grid_y = ngy
		emit_signal("cell_entered", grid_x, grid_y)
