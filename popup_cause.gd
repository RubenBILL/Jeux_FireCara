extends CanvasLayer
## Affiche un encadré quand un feu est éteint (titre et texte pris sur le feu).

@export var duree_affichage: float = 8.0

var _panneau: PanelContainer
var _titre: Label
var _texte: Label
var _compteur: int = 0

func _ready() -> void:
	layer = 20
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_panneau = PanelContainer.new()
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0, 0, 0, 0.82)
	fond.set_corner_radius_all(14)
	_panneau.add_theme_stylebox_override("panel", fond)
	centre.add_child(_panneau)

	var marge := MarginContainer.new()
	for cote in ["left", "right", "top", "bottom"]:
		marge.add_theme_constant_override("margin_" + cote, 28)
	_panneau.add_child(marge)

	var boite := VBoxContainer.new()
	boite.add_theme_constant_override("separation", 14)
	marge.add_child(boite)

	_titre = Label.new()
	_titre.add_theme_font_size_override("font_size", 34)
	_titre.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	boite.add_child(_titre)

	_texte = Label.new()
	_texte.add_theme_font_size_override("font_size", 26)
	_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texte.custom_minimum_size = Vector2(700, 0)
	boite.add_child(_texte)

	_panneau.visible = false

	await get_tree().process_frame
	for n in get_tree().get_nodes_in_group("feux"):
		if n is Feu:
			n.eteint.connect(_afficher)

func _afficher(feu: Feu) -> void:
	_titre.text = feu.titre_popup
	_texte.text = feu.texte_popup
	_panneau.visible = true
	_compteur += 1
	var mon_numero := _compteur
	await get_tree().create_timer(duree_affichage).timeout
	if mon_numero == _compteur:
		_panneau.visible = false
