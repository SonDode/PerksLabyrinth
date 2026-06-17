extends CanvasLayer

# ============================================================================
#  PauseMenu.gd — Meniul de pauză (deschis cu ESC)
#  Oprește jocul (get_tree().paused) și oferă: Continuă, Restart nivel curent,
#  Meniu principal. process_mode = ALWAYS (setat în scenă) ca butoanele și ESC
#  să funcționeze cât timp restul jocului e înghețat.
# ============================================================================

@onready var resume_button:  Button = $Panel/VBox/ResumeButton
@onready var restart_button: Button = $Panel/VBox/RestartButton
@onready var menu_button:    Button = $Panel/VBox/MenuButton

var _paused: bool = false

func _ready() -> void:
	visible = false
	resume_button.pressed.connect(_on_resume)
	restart_button.pressed.connect(_on_restart)
	menu_button.pressed.connect(_on_menu)
	restart_button.text = "↻  Restart Nivel %d" % GameManager.current_level

# ESC comută între pauză și joc
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle()
		get_viewport().set_input_as_handled()   # nu lăsa ESC să ajungă la altceva

func _toggle() -> void:
	if _paused:
		_on_resume()
	else:
		_pause()

# Pune jocul pe pauză și eliberează mouse-ul ca să poți apăsa butoanele
func _pause() -> void:
	_paused = true
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# Reia jocul și recapturează mouse-ul
func _on_resume() -> void:
	_paused = false
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Repornește nivelul curent (același număr de nivel, labirint nou)
func _on_restart() -> void:
	get_tree().paused = false
	GameManager.restart_level()          # vieți pline, perks resetate, ACELAȘI nivel
	get_tree().reload_current_scene()    # regenerează labirintul nivelului curent

func _on_menu() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
