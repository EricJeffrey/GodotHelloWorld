extends Node3D

@export var player_scene: PackedScene

const IP_ADDR = "127.0.0.1"
const PORT = 6666

func _ready():
	$MultiplayerSpawner.add_spawnable_scene("res://player.tscn")

const RAY_LENGTH = 5000

func test_raycast():
	if multiplayer.get_unique_id() == 1: return
	var player_path = "game/" + str(multiplayer.get_unique_id())
	if has_node(player_path):
		var player = get_node(player_path)
		var space_state = get_world_3d().direct_space_state
		var ending = player.get_gun_ray_ending()
		var from = ending[1]
		var to = (ending[1] - ending[0]).normalized() * RAY_LENGTH
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [player]
		var result = space_state.intersect_ray(query)
		if result:
			$game/HitBox.position = result.position

func _process(_delta):
	if Input.is_action_just_pressed("shoot"):
		test_raycast()
		pass

# ----- UI handler -----

func _on_host_pressed():
	$Control.hide()
	server_start()
	pass # Replace with function body.

func _on_client_pressed():
	$Control.hide()
	client_start()

func update_lable3d_pos_text(new_text, pos):
	if new_text:
		$game/Label3D.text = new_text
	if pos:
		$game/Label3D.position = pos

# ----- client handler ----- 

func server_start():
	multiplayer.peer_connected.connect(server_on_peer_connected)
	multiplayer.peer_disconnected.connect(server_on_peer_disconnected)
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT)
	update_lable3d_pos_text("server " + ("running" if err == 0 else ("failed: {0}".format([err]))), null)
	multiplayer.multiplayer_peer = peer if err == 0 else null
	OS.set_environment("_hack_uniq_id", "server" + str(multiplayer.get_unique_id()))

func server_on_peer_connected(id):
	update_lable3d_pos_text("{0} connected".format([id]), null)
	server_spawn_player(id)

func server_on_peer_disconnected(id):
	update_lable3d_pos_text("{0} disconnected".format([id]), null)
	server_remove_player(id)

func server_spawn_player(client_peer_id):
	var start_pos = Vector3(randi() % 5 + 1, randi() % 5 + 5, randi() % 5 + 1)
	var player = player_scene.instantiate()
	var dummy_name = "player:{0}".format([client_peer_id])
	player.initialize(start_pos, client_peer_id, dummy_name)
	$game.add_child(player, true)
	update_lable3d_pos_text("spawned {0}".format([dummy_name]), null)

func server_remove_player(client_peer_id):
	if $game.has_node(str(client_peer_id)):
		$game.get_node(str(client_peer_id)).queue_free()

# ----- server handler ----- 

func client_start():
	multiplayer.connected_to_server.connect(client_on_connected_to_server)
	multiplayer.server_disconnected.connect(client_on_disconnected_to_server)
	multiplayer.connection_failed.connect(client_on_connection_failed)
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(IP_ADDR, PORT)
	multiplayer.multiplayer_peer = peer if err == 0 else null
	OS.set_environment("_hack_uniq_id", "client" + str(multiplayer.get_unique_id()))

func client_on_connection_failed():
	update_lable3d_pos_text("connect failed", null)

func client_on_connected_to_server():
	update_lable3d_pos_text("connected", Vector3(0, 1, 0))

func client_on_disconnected_to_server():
	update_lable3d_pos_text("disconnected", null)

