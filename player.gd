extends CharacterBody3D

@export var speed: float = 5.0
@export var mouse_sensitivity: float = 0.003
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8
@export var sprint_multiplier: float = 2.8

# ── Manette Arduino ──
const ZONE_MORTE_TILT := 8.0     # degrés d'inclinaison ignorés (manette posée à plat)
const VITESSE_TILT := 2.0        # rad/s quand la manette est inclinée à ~45°

@onready var poudre: GPUParticles3D = $Head/Camera3D/Poudre
@onready var pas: FmodEventEmitter3D = $FmodEventEmitter3D
@onready var son_poudre: FmodEventEmitter3D = $Head/Camera3D/SonPoudre

var _marche := false
var _spray_avant := false

var _label := ""
var head: Node3D
var pitch: float = 0.0

func _ready() -> void:
	head = $Head
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event) -> void:
	if event is InputEventMouseMotion:
		# rotation horizontale du corps
		rotate_y(-event.relative.x * mouse_sensitivity)
		# rotation verticale de la tête
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-89), deg_to_rad(89))
		head.rotation.x = pitch
	elif event is InputEventKey and event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _zone_morte(v: float, seuil: float) -> float:
	if absf(v) < seuil:
		return 0.0
	return clampf((v - signf(v) * seuil) / (45.0 - seuil), -1.0, 1.0)

func _physics_process(delta: float) -> void:
	var arduino := ArduinoManager.est_connecte()
	var direction = Vector3.ZERO

	var forward = -transform.basis.z
	var right = transform.basis.x

	if Input.is_action_pressed("move_forward"):
		direction += forward
	if Input.is_action_pressed("move_back"):
		direction -= forward
	if Input.is_action_pressed("move_left"):
		direction -= right
	if Input.is_action_pressed("move_right"):
		direction += right

	# joystick Arduino (déjà borné à ~1 avec une zone morte)
	var joy := Vector2.ZERO
	if arduino:
		joy = ArduinoManager.joystick
		direction += right * joy.x
		direction += forward * -joy.y   # si avancer/reculer est inversé : enlève le "-"

	# garde la vitesse analogique du joystick (le clavier reste à 1 maximum)
	direction = direction.limit_length(1.0)

	# course : Shift enfoncé, ou joystick poussé à fond
	var courir := Input.is_action_pressed("sprint") or (arduino and joy.length() > 0.95)
	var vitesse := speed * (sprint_multiplier if courir else 1.0)

	# mouvement horizontal
	velocity.x = direction.x * vitesse
	velocity.z = direction.z * vitesse

	# regard au gyroscope (comme un joystick : plus on incline, plus ça tourne vite)
	if arduino:
		var tilt := ArduinoManager.tilt
		var tourne := _zone_morte(tilt.x, ZONE_MORTE_TILT)
		var regarde := _zone_morte(tilt.y, ZONE_MORTE_TILT)
		rotate_y(-tourne * VITESSE_TILT * delta)      # si ça tourne à l'envers : enlève le "-"
		pitch = clamp(pitch - regarde * VITESSE_TILT * delta, deg_to_rad(-89), deg_to_rad(89))
		head.rotation.x = pitch                       # si haut/bas inversé : "+" au lieu de "-"

	# gravité et saut
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_pressed("jump"):
		velocity.y = jump_velocity

	# extincteur : touche spray ou bouton du joystick
	var spray := Input.is_action_pressed("spray") or (arduino and ArduinoManager.button_pressed)
	poudre.emitting = spray
	if arduino:
		poudre.amount_ratio = lerpf(0.2, 1.0, ArduinoManager.pot_value)  # intensité au potentiomètre
	else:
		poudre.amount_ratio = 1.0
	if spray and not _spray_avant:
		son_poudre.play()
	elif not spray and _spray_avant:
		son_poudre.stop()
	_spray_avant = spray

	move_and_slide()

	# bruit de pas : marche ou course
	var marche_maintenant := is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.1
	var label := "herbeCours" if courir else "herbeMarche"
	if marche_maintenant and not _marche:
		pas.play()
		pas.set_parameter("pas", label)
		_label = label
	elif marche_maintenant and label != _label:
		pas.set_parameter("pas", label)
		_label = label
	elif not marche_maintenant and _marche:
		pas.stop()
	_marche = marche_maintenant
	
