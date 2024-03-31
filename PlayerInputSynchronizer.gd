extends MultiplayerSynchronizer

# this file sync rotation and jump

@export var input_data = {
	"direction": Vector2(),
	"rotation": Vector3(),
	"jumping": false,
	"shooting": false,
	"accelerating": false
}

const LOOKAROUND_SPEED_x = 0.003
const LOOKAROUND_SPEED_y = 0.003

func _ready():
	# only allow local to update those value
	var is_local = get_multiplayer_authority() == multiplayer.get_unique_id()
	set_process(is_local)
	set_process_input(is_local)
	set_process_unhandled_input(is_local)

func _unhandled_input(event):
	if event is InputEventMouseMotion: # and event.button_mask & MOUSE_BUTTON_LEFT
		var rot_x = input_data.rotation.x
		var rot_y = input_data.rotation.y
		rot_x -= event.relative.x * LOOKAROUND_SPEED_x
		rot_y -= event.relative.y * LOOKAROUND_SPEED_y
		input_data.rotation = Vector3(rot_x, rot_y, 0)

@rpc("call_local")
func jump():
	input_data.jumping = true

@rpc("call_local")
func shoot():
	""" this event should be handled in parent """
	input_data.shooting = true

func _process(_delta):
	if Input.is_action_just_pressed("ui_accept"):
		"""
		bug: server recived jump after client's handler, causing jump reset to false
		fix: let jump not "call local", but will have latency
		"""
		# necessary otherwise server may lost jump
		jump.rpc()
	if Input.is_action_just_pressed("shoot"):
		shoot()
	if Input.is_action_just_pressed("accelerate"):
		input_data.accelerating = true
	if Input.is_action_just_released("accelerate"):
		input_data.accelerating = false
	input_data.direction = Input.get_vector("left", "right", "forward", "backward")
