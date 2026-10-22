extends Node

signal dialogues_finis

@export var evenements: PackedStringArray = ["event:/scenario1", "event:/scenario2", "event:/scenario3"]
@export var pause_entre: float = 0.5
@export var demarrage_auto: bool = true

func _ready() -> void:
	await get_tree().process_frame
	if demarrage_auto:
		demarrer()

func demarrer() -> void:
	for chemin in evenements:
		await _jouer(chemin)
		await get_tree().create_timer(pause_entre).timeout
	dialogues_finis.emit()

func _jouer(chemin: String) -> void:
	if not FmodServer.check_event_path(chemin):
		push_warning("[Dialogues] événement introuvable : " + chemin)
		return
	var duree: float = FmodServer.get_event(chemin).get_length() / 1000.0
	print("[Dialogues] ", chemin, " dure ", snappedf(duree, 0.1), " s")
	var em := FmodEventEmitter3D.new()
	em.event_guid = FmodServer.get_event_guid(chemin)
	em.event_name = chemin
	add_child(em)
	em.play()
	await get_tree().create_timer(duree + 0.3).timeout
	em.stop()
	em.queue_free()
