extends Node

signal tous_eteints

## Secondes avant le premier feu (à régler à la main).
@export var delai_premier_feu: float = 65.0
## Pause entre l'extinction d'un feu et l'allumage du suivant.
@export var pause_entre_feux: float = 3.0
## Délai entre l'extinction d'un feu et le dialogue suivant.
@export var delai_dialogue_apres_feu: float = 10.0

var feux: Array[Feu] = []
var index: int = 0
var dialogues: Node

func _ready() -> void:
	dialogues = get_node_or_null("../Dialogues")
	await get_tree().process_frame
	for n in get_tree().get_nodes_in_group("feux"):
		if n is Feu:
			feux.append(n)
	feux.sort_custom(func(a: Feu, b: Feu) -> bool: return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
	for f in feux:
		f.eteint.connect(_on_feu_eteint)
	await get_tree().create_timer(delai_premier_feu).timeout
	_allumer_suivant()

func _allumer_suivant() -> void:
	if index >= feux.size():
		print("[Feux] tous éteints")
		tous_eteints.emit()
		return
	print("[Feux] allumé : ", feux[index].name)
	feux[index].allumer()

func _on_feu_eteint(feu: Feu) -> void:
	var i := feux.find(feu)
	# feu 1 éteint -> scénario 2 ; feu 2 éteint -> scénario 3
	if dialogues != null and i >= 0 and i < 2:
		dialogues.lancer(i + 1, delai_dialogue_apres_feu)
	await get_tree().create_timer(pause_entre_feux).timeout
	index += 1
	_allumer_suivant()
