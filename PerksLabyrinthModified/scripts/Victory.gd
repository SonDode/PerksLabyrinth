extends Control

func _ready() -> void:
	$VBox/LivesLabel.text = "Lives remaining: %d / %d" % [GameManager.lives, GameManager.MAX_LIVES]
	$VBox/PlayAgainButton.pressed.connect(_on_play_again)
	$VBox/MenuButton.pressed.connect(_on_menu)
	
	# Celebration tween
	var tween = create_tween().set_loops()
	tween.tween_property($VBox/Title, "modulate", Color(0.0, 1.0, 0.5), 0.8)
	tween.tween_property($VBox/Title, "modulate", Color(0.5, 1.0, 0.2), 0.8)

func _on_play_again() -> void:
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_menu() -> void:
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
