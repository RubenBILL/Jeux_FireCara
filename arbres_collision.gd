extends MultiMeshInstance3D
## Crée automatiquement une collision (un cylindre sur le tronc) pour chaque arbre
## de ce MultiMesh, à chaque lancement du jeu.
##
## À attacher au MultiMeshInstance3D des arbres (Inspecteur > Script > Charger).
## Si tu regénères les arbres avec Populate, rien à refaire : les collisions suivent.
## Ne l'attache PAS au nœud de l'herbe (des dizaines de milliers de collisions).
##
## Les valeurs sont données pour un arbre à l'échelle 1 : le script les multiplie
## tout seul par la taille de chaque arbre.

## Rayon du tronc (CommonTree : environ 0,6 ; Pine : environ 0,3 à 0,5 ; TwistedTree : environ 1,3).
@export var rayon_tronc: float = 0.6
## Hauteur de la collision, depuis le pied de l'arbre.
@export var hauteur_collision: float = 6.0
## Couche de collision (1 = la même que le sol et le joueur).
@export_flags_3d_physics var couche_collision: int = 1

var _corps: StaticBody3D


func _ready() -> void:
	generer_collisions()


func generer_collisions() -> void:
	if _corps != null:
		_corps.queue_free()
		_corps = null
	if multimesh == null:
		return

	_corps = StaticBody3D.new()
	_corps.name = "CollisionsArbres"
	_corps.collision_layer = couche_collision
	_corps.collision_mask = 0
	add_child(_corps)

	var nombre := multimesh.instance_count
	if multimesh.visible_instance_count >= 0:
		nombre = mini(nombre, multimesh.visible_instance_count)

	for i in nombre:
		var t: Transform3D = multimesh.get_instance_transform(i)
		var echelle: Vector3 = t.basis.get_scale()
		var base := t.basis.orthonormalized()
		var rayon := rayon_tronc * (echelle.x + echelle.z) * 0.5
		var hauteur := hauteur_collision * echelle.y

		var forme := CylinderShape3D.new()
		forme.radius = rayon
		forme.height = hauteur

		var cs := CollisionShape3D.new()
		cs.shape = forme
		cs.transform = Transform3D(base, t.origin + base.y * (hauteur * 0.5))
		_corps.add_child(cs)
