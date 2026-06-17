extends Control

# ============================================================================
#  Victory.gd — Ecranul de câștig (ai terminat ultimul nivel)
#  Arată viețile rămase și oferă: joacă din nou (de la nivelul 1) sau meniu.
# ============================================================================

func _ready() -> void:
	$VBox/LivesLabel.text = "Vieți rămase: %d" % GameManager.lives
	$VBox/PlayAgainButton.pressed.connect(_on_play_again)
	$VBox/MenuButton.pressed.connect(_on_menu)

	# Titlul pulsează în verde (sărbătoare)
	var tween = create_tween().set_loops()
	tween.tween_property($VBox/Title, "modulate", Color(0.0, 1.0, 0.5), 0.8)
	tween.tween_property($VBox/Title, "modulate", Color(0.5, 1.0, 0.2), 0.8)

func _on_play_again() -> void:
	GameManager.start_new_game()   # reia de la nivelul 1
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_menu() -> void:
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
