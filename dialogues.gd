extends Node

@export var evenements: PackedStringArray = ["event:/scenario1", "event:/scenario2", "event:/scenario3"]
## Délai avant le scénario 1, en secondes après le début du jeu.
@export var delai_scenario_1: float = 5.0
## Son joué juste après le scénario 1, à la position du Feu_1.
@export var son_apres_scenario_1: String = "event:/ciminel"
## Volume du son après le scénario 1 (1.0 = normal, 2.0 = deux fois plus fort).
@export var volume_cause: float = 3.0
## Vrai : le son est joué sur le joueur (audible partout, sans direction).
## Faux : le son est joué sur Feu_1 (direction, mais s'atténue avec la distance).
@export var son_chez_le_joueur: bool = true

var _en_cours: bool = false

func _ready() -> void:
	await get_tree().process_frame
	lancer(0, delai_scenario_1)

## Lance le dialogue numéro `index` (0 = scénario 1) après `delai` secondes.
## S'il y a déjà un son en cours, attend qu'il soit fini.
func lancer(index: int, delai: float = 0.0) -> void:
	if index < 0 or index >= evenements.size():
		return
	await get_tree().create_timer(delai).timeout
	while _en_cours:
		await get_tree().create_timer(0.2).timeout
	_en_cours = true
	await _jouer(evenements[index])
	if index == 0 and son_apres_scenario_1 != "":
		var lieu: Node = get_node_or_null("../Player") if son_chez_le_joueur else get_node_or_null("../Feu_1")
		await _jouer(son_apres_scenario_1, lieu, volume_cause)
	_en_cours = false

## Joue un événement FMOD une fois. Si `lieu` est donné, le son est posé sur ce nœud.
func _jouer(chemin: String, lieu: Node = null, volume: float = 1.0) -> void:
	if not FmodServer.check_event_path(chemin):
		push_warning("[Dialogues] événement introuvable : " + chemin)
		return
	var duree: float = FmodServer.get_event(chemin).get_length() / 1000.0
	print("[Dialogues] ", chemin, " dure ", snappedf(duree, 0.1), " s")
	var em := FmodEventEmitter3D.new()
	em.event_guid = FmodServer.get_event_guid(chemin)
	em.event_name = chemin
	em.volume = volume
	var parent: Node = lieu if lieu != null else self
	parent.add_child(em)
	em.play()
	await get_tree().create_timer(duree + 0.3).timeout
	em.stop()
	em.queue_free()
