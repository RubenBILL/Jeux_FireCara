extends CharacterBody3D

@export var speed: float = 5.0
@export var mouse_sensitivity: float = 0.003
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8
@export var sprint_multiplier: float = 2.8

# ── Manette Arduino ──
const ZONE_MORTE_TILT := 12.0    # degrés d'inclinaison gauche/droite ignorés
const VITESSE_TILT := 2.0        # vitesse de rotation gauche/droite (rad/s à ~45°)
const GAIN_PITCH := 1.5          # incliner de 20° fait regarder 30° plus haut ou plus bas
const POT_REPOS := 0.15     # valeur mesurée gâchette relâchée
const POT_APPUYE := 0.05    # valeur mesurée gâchette enfoncée à fond
const GACHETTE_ON := 0.5    # on tire à partir de 50 % d'appui
const GACHETTE_OFF := 0.3   # on arrête en dessous de 30 % (l'écart évite que le jet clignote)
const GAIN_YAW := 2.0            # 2.0 = pivoter la manette de 45° fait tourner la caméra de 90°
const PITCH_SUR_X := false       # true si incliner la manette avant/arrière fait varier le PREMIER nombre de tilt
@export var reservoir_max: float = 100.0
## Poudre consommée par seconde (100 / 2 = 50 s de jet continu).
@export var conso_poudre: float = 5.0

@onready var poudre: GPUParticles3D = $Head/Camera3D/Poudre
@onready var pas: FmodEventEmitter3D = $FmodEventEmitter3D
@onready var son_poudre: FmodEventEmitter3D = $Head/Camera3D/SonPoudre
@onready var jet: Area3D = $Head/Camera3D/ZoneJet

var reservoir: float = 100.0
var _son_jet: bool = false

var _pot_lisse := POT_REPOS
var _gachette := false
var _marche := false
var _spray_avant := false
var _tilt_neutre := Vector2.ZERO
var _tilt_calibre := false
var _temps_connecte := 0.0
var _gyro_biais := 0.0
var _somme_gyro := 0.0
var _nb_gyro := 0


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
		if not ArduinoManager.est_connecte():   # avec la manette, c'est le gyroscope qui gère le haut/bas
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
		direction += right * joy.y      # gauche/droite (joystick monté tourné d'un quart de tour)
		direction += forward * joy.x   # avant/arrière

	# garde la vitesse analogique du joystick (le clavier reste à 1 maximum)
	direction = direction.limit_length(1.0)

	# course : Shift enfoncé, ou joystick poussé à fond
	var courir := Input.is_action_pressed("sprint") or (arduino and joy.length() > 0.95)
	var vitesse := speed * (sprint_multiplier if courir else 1.0)

	# mouvement horizontal
	velocity.x = direction.x * vitesse
	velocity.z = direction.z * vitesse

			# regard au gyroscope, par rapport à la position de repos mémorisée
	if arduino:
		var tilt := ArduinoManager.tilt
		_temps_connecte += delta
		# touche C : relance la calibration (garder la manette immobile 1,5 s après l'avoir relâchée)
		if Input.is_key_pressed(KEY_C):
			_tilt_calibre = false
			_temps_connecte = 0.0
			_somme_gyro = 0.0
			_nb_gyro = 0
		if not _tilt_calibre:
			# entre 0,5 s et 1,5 s : moyenne du gyroscope au repos (son biais)
			if _temps_connecte > 0.5:
				_somme_gyro += ArduinoManager.gyro_z
				_nb_gyro += 1
			if _temps_connecte > 1.5 and _nb_gyro > 0:
				_gyro_biais = _somme_gyro / _nb_gyro
				_tilt_neutre = tilt
				_tilt_calibre = true
				print("[Manette] Calibrée : biais gyroscope = ", snappedf(_gyro_biais, 0.1), " °/s")
		else:
			var t := tilt - _tilt_neutre
			# gauche/droite : on pivote la manette à plat, le gyroscope mesure la vitesse de rotation
			var vitesse_z := ArduinoManager.gyro_z - _gyro_biais
			if absf(vitesse_z) < 3.0:
				# manette immobile : on suit très doucement la dérive du gyroscope
				_gyro_biais = lerpf(_gyro_biais, ArduinoManager.gyro_z, 0.005)
			if absf(vitesse_z) > 4.0:   # zone morte en °/s : ignore les tremblements
				rotate_y(deg_to_rad(vitesse_z) * GAIN_YAW * delta)   # pivot à droite (valeur positive) = tourner à droite
			if Engine.get_physics_frames() % 30 == 0:   # diagnostic temporaire, deux fois par seconde
				print("gyr=", snappedf(ArduinoManager.gyro_z, 0.1), "  biais=", snappedf(_gyro_biais, 0.1), "  vitesse=", snappedf(vitesse_z, 0.1))
			# haut/bas : l'angle de la manette donne directement l'angle du regard
			var angle_pitch := t.x if PITCH_SUR_X else t.y
			var cible := clampf(deg_to_rad(-angle_pitch) * GAIN_PITCH, deg_to_rad(-89), deg_to_rad(89))   # si inversé : enlève le "-" devant angle_pitch
			pitch = lerpf(pitch, cible, 0.3)   # lissage : supprime les à-coups
			head.rotation.x = pitch
	else:
		_tilt_calibre = false
		_temps_connecte = 0.0
		_somme_gyro = 0.0
		_nb_gyro = 0

	# gravité et saut
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_pressed("jump"):
		velocity.y = jump_velocity

	# extincteur : touche spray, ou gâchette (potentiomètre) de la manette
	var intensite := 1.0
	if arduino:
		_pot_lisse = lerpf(_pot_lisse, ArduinoManager.pot_value, 0.3)   # lissage du bruit
		var appui := clampf(inverse_lerp(POT_REPOS, POT_APPUYE, _pot_lisse), 0.0, 1.0)
		if appui > GACHETTE_ON:
			_gachette = true
		elif appui < GACHETTE_OFF:
			_gachette = false
		intensite = clampf(inverse_lerp(GACHETTE_OFF, 1.0, appui), 0.0, 1.0)
	else:
		_gachette = false

	var spray := Input.is_action_pressed("spray") or _gachette
	poudre.emitting = spray
	poudre.amount_ratio = lerpf(0.1, 1.0, intensite) if _gachette else 1.0   # quantité de poudre
	poudre.speed_scale = lerpf(0.6, 1.5, intensite) if _gachette else 1.0    # vitesse du jet
	if spray and not _spray_avant:
		son_poudre.play()
	elif not spray and _spray_avant:
		son_poudre.stop()
	_spray_avant = spray
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
