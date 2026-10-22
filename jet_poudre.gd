extends Area3D
## Zone devant l'extincteur : tout feu qui s'y trouve reçoit de la poudre.

## Puissance du jet : 0 (fermé) à 1 (plein débit). Écrit par player.gd.
var debit: float = 0.0
## Vie retirée au feu par seconde à plein débit (le feu a 100 de vie).
@export var degats_par_seconde: float = 40.0

func _physics_process(delta: float) -> void:
	if debit <= 0.02:
		return
	for zone in get_overlapping_areas():
		if zone.has_method("recevoir_poudre"):
			zone.recevoir_poudre(debit * degats_par_seconde * delta)
