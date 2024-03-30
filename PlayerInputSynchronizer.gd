extends MultiplayerSynchronizer

# this file sync rotation and jump

@export var direction = Vector2()
@export var rotation = Vector3()
@export var jumping = false;

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
		var rot_x = rotation.x
		var rot_y = rotation.y
		rot_x -= event.relative.x * LOOKAROUND_SPEED_x
		rot_y -= event.relative.y * LOOKAROUND_SPEED_y
		rotation = Vector3(rot_x, rot_y, 0)

@rpc("call_local")
func jump():
	jumping = true

func _process(_delta):
	if Input.is_action_just_pressed("ui_accept"):
		"""
		bug: server recived jump after client's handler, causing jump reset to false
		"""
		# necessary otherwise server may lost jump
		jump.rpc()
	direction = Input.get_vector("left", "right", "forward", "backward")
