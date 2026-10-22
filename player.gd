extends CharacterBody3D

@export var speed: float = 5.0
@export var mouse_sensitivity: float = 0.003
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8
@export var sprint_multiplier: float = 2.8

@export var reservoir_max: float = 100.0
## Poudre consommée par seconde (100 / 2 = 50 s de jet continu).
@export var conso_poudre: float = 5.0

@onready var poudre: GPUParticles3D = $Head/Camera3D/Poudre
@onready var pas: FmodEventEmitter3D = $FmodEventEmitter3D
@onready var son_poudre: FmodEventEmitter3D = $Head/Camera3D/SonPoudre
@onready var jet: Area3D = $Head/Camera3D/ZoneJet

var reservoir: float = 100.0
var _son_jet: bool = false

var _marche := false

var _label := ""
var head: Node3D
var pitch: float = 0.0

func _ready() -> void:
	head = $Head
	add_to_group("joueur")
	reservoir = reservoir_max
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

func _physics_process(delta: float) -> void:
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

	direction = direction.normalized()

	# course : Shift enfoncé
	var courir := Input.is_action_pressed("sprint")
	var vitesse := speed * (sprint_multiplier if courir else 1.0)

	# mouvement horizontal
	velocity.x = direction.x * vitesse
	velocity.z = direction.z * vitesse

	# gravité et saut
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_pressed("jump"):
		velocity.y = jump_velocity

	# extincteur : tant qu'il reste de la poudre
	var arrose := Input.is_action_pressed("spray") and reservoir > 0.0
	if arrose:
		reservoir = maxf(reservoir - conso_poudre * delta, 0.0)
	poudre.emitting = arrose
	jet.debit = 1.0 if arrose else 0.0
	if arrose and not _son_jet:
		son_poudre.play()
		_son_jet = true
	elif not arrose and _son_jet:
		son_poudre.stop()
		_son_jet = false

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
