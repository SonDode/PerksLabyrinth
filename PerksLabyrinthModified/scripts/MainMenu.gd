extends Control

@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var brightness_slider: HSlider = $SettingsPanel/VBoxSettings/BrightnessSlider
@onready var brightness_value: Label = $SettingsPanel/VBoxSettings/BrightnessValue

func _ready() -> void:
	$VBox/PlayButton.pressed.connect(_on_play)
	$VBox/SettingsButton.pressed.connect(_on_settings)
	$VBox/QuitButton.pressed.connect(_on_quit)
	$SettingsPanel/VBoxSettings/CloseButton.pressed.connect(_on_close_settings)
	brightness_slider.value_changed.connect(_on_brightness_changed)

	# Load saved brightness
	var saved: float = ProjectSettings.get_setting("display/brightness", 1.0) as float
	brightness_slider.value = saved
	_apply_brightness(saved)

	# Animate title
	var tween = create_tween().set_loops()
	tween.tween_property($VBox/Title, "modulate", Color(0.5, 0.8, 1.0), 1.5)
	tween.tween_property($VBox/Title, "modulate", Color(0.8, 0.3, 1.0), 1.5)

func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_settings() -> void:
	settings_panel.visible = true

func _on_close_settings() -> void:
	settings_panel.visible = false

func _on_brightness_changed(value: float) -> void:
	_apply_brightness(value)
	brightness_value.text = "%d%%" % int(value * 100)

func _apply_brightness(value: float) -> void:
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 1))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.adjustment_enabled = true
	env.adjustment_brightness = value
	# Store for game scene to pick up
	ProjectSettings.set_setting("display/brightness", value)

func _on_quit() -> void:
	get_tree().quit()
