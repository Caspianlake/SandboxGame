# Character controller for 3D movement, jumping, and mouse look
extends CharacterBody3D

# Movement speed
@export var SPEED = 5.0
# Jump velocity
@export var JUMP_VELOCITY = 4.5
# Mouse sensitivity for camera rotation
@export var mouse_sensitivity := 0.002
# Maximum pitch angle in degrees
@export var max_pitch := 90.0

# Reference to the head node for pitch rotation
@onready var head := $Head

# Current pitch angle
var pitch := 0.0

# Set up input mode on ready
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Handle mouse motion for camera rotation
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(-max_pitch), deg_to_rad(max_pitch))
		head.rotation.x = pitch

# Handle camera lock toggle
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("CameraLock"):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


# Handle physics updates
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("Left", "Right", "Forward", "Backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
