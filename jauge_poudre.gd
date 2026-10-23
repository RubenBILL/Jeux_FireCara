extends CanvasLayer
## Jauge de poudre en bas à gauche de l'écran.

var _barre: ProgressBar

func _ready() -> void:
	layer = 15
	_barre = ProgressBar.new()
	_barre.show_percentage = false
	_barre.custom_minimum_size = Vector2(320, 28)
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0, 0, 0, 0.6)
	fond.set_corner_radius_all(6)
	var remplissage := StyleBoxFlat.new()
	remplissage.bg_color = Color(1.0, 0.55, 0.15)
	remplissage.set_corner_radius_all(6)
	_barre.add_theme_stylebox_override("background", fond)
	_barre.add_theme_stylebox_override("fill", remplissage)
	add_child(_barre)
	_barre.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 40)

func _process(_delta: float) -> void:
	var joueur := get_tree().get_first_node_in_group("joueur")
	if joueur != null:
		_barre.max_value = joueur.reservoir_max
		_barre.value = joueur.reservoir
