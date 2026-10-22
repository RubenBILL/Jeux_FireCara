class_name Feu
extends Area3D
## Un foyer d'incendie : s'allume, perd de la vie quand la poudre le touche, s'éteint.

signal allume(feu: Feu)
signal eteint(feu: Feu)

@export var titre_popup: String = "Cause du feu"
@export_multiline var texte_popup: String = "Texte à compléter dans l'Inspector (champ Texte Popup)."
## Son lu à l'extinction (ex. event:/ciminel). Laisser vide pour aucun son.
@export var evenement_cause: String = ""
@export var vie_max: float = 100.0
## Pose automatiquement le feu sur le sol au démarrage.
@export var coller_au_sol: bool = true
## Pour tester : le feu s'allume dès le lancement du jeu.
@export var allume_au_demarrage: bool = false

@onready var flammes: GPUParticles3D = $Flammes
@onready var lumiere: OmniLight3D = $Lumiere
@onready var son: FmodEventEmitter3D = $Son

var vie: float = 0.0
var actif: bool = false
## Vrai une fois que le joueur a éteint ce feu.
var est_eteint: bool = false
var _energie_base: float = 3.0

func _ready() -> void:
	add_to_group("feux")
	flammes.emitting = false
	lumiere.visible = false
	_energie_base = lumiere.light_energy
	set_process(false)
	if coller_au_sol:
		_poser_au_sol()
	if allume_au_demarrage:
		allumer()

func _poser_au_sol() -> void:
	# attend que la physique soit prête, puis lance un rayon vers le bas
	await get_tree().physics_frame
	await get_tree().physics_frame
	var espace := get_world_3d().direct_space_state
	var depart := global_position + Vector3.UP * 40.0
	var arrivee := global_position + Vector3.DOWN * 80.0
	var requete := PhysicsRayQueryParameters3D.create(depart, arrivee, 1)
	var touche := espace.intersect_ray(requete)
	if touche.has("position"):
		global_position.y = touche["position"].y + 0.05

func _process(_delta: float) -> void:
	# la lumière vacille comme une vraie flamme
	var ratio := clampf(vie / vie_max, 0.0, 1.0)
	lumiere.light_energy = _energie_base * ratio * randf_range(0.8, 1.2)

func allumer() -> void:
	if actif:
		return
	vie = vie_max
	actif = true
	flammes.amount_ratio = 1.0
	flammes.emitting = true
	lumiere.visible = true
	set_process(true)
	son.play()
	allume.emit(self)

func recevoir_poudre(quantite: float) -> void:
	if not actif:
		return
	vie -= quantite
	flammes.amount_ratio = maxf(clampf(vie / vie_max, 0.0, 1.0), 0.12)
	if vie <= 0.0:
		eteindre()

func eteindre() -> void:
	if not actif:
		return
	actif = false
	est_eteint = true
	flammes.emitting = false
	lumiere.visible = false
	set_process(false)
	son.stop()
	eteint.emit(self)
