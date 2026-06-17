extends Control

# ============================================================================
#  GameOver.gd — Ecranul de final când rămâi fără vieți
#  Două opțiuni: reia jocul de la nivelul 1 sau întoarce-te la meniu.
# ============================================================================

func _ready() -> void:
	$VBox/RetryButton.pressed.connect(_on_retry)
	$VBox/MenuButton.pressed.connect(_on_menu)

func _on_retry() -> void:
	GameManager.start_new_game()   # reia de la nivelul 1
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_menu() -> void:
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
