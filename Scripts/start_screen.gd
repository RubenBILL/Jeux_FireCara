extends Node

@onready var fade_overlay = %FadeOverlay
@onready var StatusDot = %StatusDot
@onready var StatusLabel = %StatusLabel
@onready var StartButton = %StartButton
@onready var Musique = $Musique

func _ready() -> void:
	ArduinoManager.arduino_connected.connect(_on_arduino_connected)
	ArduinoManager.arduino_disconnected.connect(_on_arduino_disconnected)

	StatusDot.modulate = Color.RED
	StatusLabel.text = "Veuillez tenir la manette face à l'écran avant de lancer"
	StartButton.disabled = false

	Musique.play()
	await get_tree().process_frame
	Musique.set_parameter("etatMusique", "sonChill")

func _on_arduino_connected():
	StatusDot.modulate = Color.GREEN

func _on_arduino_disconnected():
	StatusDot.modulate = Color.RED

func _on_start_button_pressed() -> void:
	Musique.stop()
	fade_overlay.modulate.a = 1
	get_tree().change_scene_to_file("res://Monde2.tscn")
