extends CanvasLayer
## Écran de fin : défaite quand le chrono arrive à 0, victoire quand les 3 feux sont éteints.

## Délai entre le dernier feu éteint et l'écran de victoire (laisse lire la pop-up).
@export var delai_victoire: float = 6.0

var _fini: bool = false
var _fond: ColorRect
var _titre: Label
var _sous_titre: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30

	_fond = ColorRect.new()
	_fond.color = Color(0, 0, 0, 0.85)
	_fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fond)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fond.add_child(centre)

	var boite := VBoxContainer.new()
	boite.add_theme_constant_override("separation", 28)
	centre.add_child(boite)

	_titre = Label.new()
	_titre.add_theme_font_size_override("font_size", 80)
	_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boite.add_child(_titre)

	_sous_titre = Label.new()
	_sous_titre.add_theme_font_size_override("font_size", 30)
	_sous_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boite.add_child(_sous_titre)

	var bouton := Button.new()
	bouton.text = "Rejouer"
	bouton.custom_minimum_size = Vector2(260, 64)
	bouton.add_theme_font_size_override("font_size", 28)
	bouton.pressed.connect(_rejouer)
	boite.add_child(bouton)

	_fond.visible = false

	await get_tree().process_frame
	var chrono := get_node_or_null("../HUD/Label")
	if chrono != null and chrono.has_signal("temps_ecoule"):
		chrono.temps_ecoule.connect(_defaite)
	var sequence := get_node_or_null("../SequenceFeux")
	if sequence != null:
		sequence.tous_eteints.connect(_victoire)

func _defaite() -> void:
	if _fini:
		return
	_fini = true
	_afficher("PERDU", "Le temps est écoulé… la forêt a brûlé.", Color(1.0, 0.3, 0.2))

func _victoire() -> void:
	if _fini:
		return
	_fini = true
	await get_tree().create_timer(delai_victoire).timeout
	_afficher("VICTOIRE", "Les trois feux sont éteints. Bravo !", Color(0.5, 1.0, 0.5))

func _afficher(titre: String, texte: String, couleur: Color) -> void:
	_titre.text = titre
	_titre.add_theme_color_override("font_color", couleur)
	_sous_titre.text = texte
	_fond.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true

func _rejouer() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
