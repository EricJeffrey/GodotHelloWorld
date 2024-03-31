extends CharacterBody3D

const SPEED_WALK = 5.0
const SPEED_RUN = 10.0
const JUMP_VELOCITY = 5
const GRAVITY = 10

@export var my_velocity = Vector3()

@export var player_peer_id = 0:
	set(id):
		player_peer_id = id
		"""
		1. server create object in server_spawn_player, but client won't, client call setter to set this value instead
		2. _enter_tree may work, but for client, peer is set after _enter_tree and _ready, so error may be seen
		3. or just set inside _process and make it only once?
		"""
		$PlayerInputSynchronizer.set_multiplayer_authority(id)

@export var player_dummy_name = "noname_incode":
	set(dummy_name):
		player_dummy_name = dummy_name
		$Pivot/dummy.mesh.text = player_dummy_name

@onready var inputSync = $PlayerInputSynchronizer

func _ready():
	if player_peer_id == multiplayer.get_unique_id():
		$Camera3D.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _update_movement(input_data):
	# check walk or run
	var speed = SPEED_RUN if input_data.accelerating else SPEED_WALK
	# handle move
	var input_direction = input_data.direction
	var direction = (transform.basis * Vector3(input_direction.x, 0, input_direction.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

func _update_rotation(input_data):
	# handle rotation
	var input_rotation = input_data.rotation
	transform.basis = Basis()
	rotate_object_local(Vector3(0, 1, 0), input_rotation.x)
	rotate_object_local(Vector3(1, 0, 0), input_rotation.y)

# both server and clients will perform this
func _physics_process(delta):
	var input_data = inputSync.input_data

	# handle falling
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# handle jumping
	if input_data.jumping:
		velocity.y = JUMP_VELOCITY
	# reset jump
	input_data.jumping = false

	_update_movement(input_data)
	_update_rotation(input_data)

	move_and_slide()

func initialize(start_position, my_peer_id, dummy_name):
	name = str(my_peer_id)
	player_peer_id = my_peer_id
	player_dummy_name = dummy_name
	look_at_from_position(start_position, Vector3.ZERO)

func get_gun_ray_ending():
	var result = [
		get_node("Pivot/gun/RayStart").global_position,
		get_node("Pivot/gun/RayEnd").global_position
	]
	return result
