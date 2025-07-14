extends CharacterBody3D

@export var base_speed: float = 1.25
@export var crouch_speed: float = 0.75
@export var prone_speed: float = 0.5
@export var jump_velocity: float = 4.5
@export var sensitivity: float = 0.002
@export var standing_height: float = 1.8
@export var crouching_height: float = 1.0
@export var prone_height: float = 0.5
@export var stance_change_speed: float = 10.0
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 20.0
@export var stamina_regen_rate: float = 15.0
@export var sprint_multiplier: float = 4.0
@export var max_health: float = 100.0
@export var flashlight_intensity: float = 1.0
@export var flashlight_range: float = 10.0

@onready var camera: Camera3D = $Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var flashlight: SpotLight3D = $Camera3D/FlashLight
@onready var item_holder: Node3D = $Camera3D/ItemHolder
@onready var stamina_bar: ProgressBar = $UI/StaminaContainer/StaminaBar
@onready var health_bar: ProgressBar = $UI/HealthContainer/HealthBar
@onready var stance_indicator: Label = $UI/StanceIndicator

var current_stamina: float
var current_health: float
var current_stance: String = "standing"
var target_height: float
var is_sprinting: bool = false
var flashlight_on: bool = false

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	current_stamina = max_stamina
	current_health = max_health
	target_height = standing_height

	flashlight.light_energy = flashlight_intensity
	flashlight.spot_range = flashlight_range
	flashlight.visible = false
	
	stamina_bar.max_value = max_stamina
	stamina_bar.value = current_stamina
	
	health_bar.max_value = max_health
	health_bar.value = current_health
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * sensitivity)
		camera.rotate_x(-event.relative.y * sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	if event.is_action_pressed("flashlight"):
		toggle_flashlight()
	
	if event.is_action_pressed("crouch"):
		if current_stance == "standing":
			change_stance("crouching")
		elif current_stance == "crouching":
			change_stance("standing")
	
	if event.is_action_pressed("prone"):
		if current_stance != "prone":
			change_stance("prone")
		else:
			change_stance("crouching")
	
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and current_stance == "standing":
		velocity.y = jump_velocity
	
	is_sprinting = Input.is_action_pressed("sprint") and current_stance == "standing" and current_stamina > 0
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var current_speed = get_current_speed()
	
	handle_stamina(delta)
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	
	handle_stance_transition(delta)
	
	move_and_slide()

func _physics_process(delta):
	# Keep physics-related updates here if needed
	pass

func get_current_speed() -> float:
	var speed = base_speed
	
	match current_stance:
		"crouching":
			speed = crouch_speed
		"prone":
			speed = prone_speed
	
	if is_sprinting and current_stance == "standing":
		speed *= sprint_multiplier
	
	return speed

func handle_stamina(delta):
	var movement_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var is_moving = movement_input.length() > 0
	
	if is_sprinting and is_moving:
		current_stamina = max(0, current_stamina - stamina_drain_rate * delta)
		if current_stamina <= 0:
			is_sprinting = false
	else:
		current_stamina = min(max_stamina, current_stamina + stamina_regen_rate * delta)
	
	stamina_bar.value = current_stamina

func take_damage(damage: float):
	current_health = max(0, current_health - damage)
	health_bar.value = current_health
	
	if current_health <= 0:
		die()

func heal(amount: float):
	current_health = min(max_health, current_health + amount)
	health_bar.value = current_health

func die():
	#player died
	print("Player died!")

func change_stance(new_stance: String):
	if new_stance == current_stance:
		return
	
	current_stance = new_stance
	
	match new_stance:
		"standing":
			target_height = standing_height
			camera.position.y = standing_height * 0.9
			stance_indicator.text = "Standing"
		"crouching":
			target_height = crouching_height
			camera.position.y = crouching_height * 0.9
			stance_indicator.text = "Crouching"
		"prone":
			target_height = prone_height
			camera.position.y = prone_height * 0.8
			stance_indicator.text = "Prone"

func handle_stance_transition(delta):
	if collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		var current_height = capsule.height
		
		if abs(current_height - target_height) > 0.01:
			capsule.height = lerp(current_height, target_height, stance_change_speed * delta)
			
			var height_diff = target_height - current_height
			collision_shape.position.y = target_height / 2

func toggle_flashlight():
	flashlight_on = !flashlight_on
	flashlight.visible = flashlight_on

#spawn multiplayer
func _on_multiplayer_spawned():
	set_multiplayer_authority(str(name).to_int())
	
	#only local player input is allowed
	if not is_multiplayer_authority():
		set_physics_process(false)
		set_process_input(false)

#network synchronization for multiplayer
@rpc("unreliable")
func sync_player_position(pos: Vector3, rot: Vector3, camera_rot: Vector3):
	if not is_multiplayer_authority():
		position = pos
		rotation = rot
		camera.rotation = camera_rot

func _on_physics_process_end():
	#send position updates to other players
	if is_multiplayer_authority():
		sync_player_position.rpc(position, rotation, camera.rotation) 
