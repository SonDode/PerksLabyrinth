extends Control

func _ready() -> void:
	$VBox/RetryButton.pressed.connect(_on_retry)
	$VBox/MenuButton.pressed.connect(_on_menu)

func _on_retry() -> void:
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_menu() -> void:
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
