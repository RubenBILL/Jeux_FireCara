extends Label

signal temps_ecoule

@export var duree: float = 300.0 # 5 minutes

var restant: float

func _ready() -> void:
	restant = duree
	custom_minimum_size = Vector2(300, 0)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	add_theme_font_size_override("font_size", 48)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 8)
	_afficher()

func _process(delta: float) -> void:
	if restant <= 0.0:
		return
	restant -= delta
	if restant <= 0.0:
		restant = 0.0
		temps_ecoule.emit()
	_afficher()

func _afficher() -> void:
	var s := int(ceil(restant))
	text = "%02d:%02d" % [floori(s / 60.0), s % 60]
	var couleur := Color.RED if restant <= 60.0 else Color.WHITE
	add_theme_color_override("font_color", couleur)
