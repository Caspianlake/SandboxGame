extends Node3D 

@export_category("Terrain")
@export var render_distance: int = 5 
@export var chunk_size: Vector3i = Vector3i(16,256,16)
@export var block_size: int = 1

var chunk_list: Dictionary[Vector3i, Chunk] = Dictionary()

var player: CharacterBody3D
var player_last_ck: Vector3i

func _ready() -> void:
	player = get_parent().find_child("Player")


func _process(_delta: float) -> void:
	if player:
		var player_ck: Vector3i = TerrainUtil.get_player_chunk(player.position,chunk_size,block_size)
		if player_last_ck != player_ck:
			terrain_process(player_ck)
		player_last_ck = player_ck

func terrain_process(player_ck: Vector3i) -> void:
	
	deactivate()
	for cx in range(-render_distance, render_distance + 1):
		for cz in range (-render_distance, render_distance + 1):
			activate(Vector3i(player_ck.x + cx,0,player_ck.z + cz))

func deactivate() -> void:
	for ck in chunk_list:
		chunk_list[ck].active = false

func activate(chunk_key: Vector3i) -> void:
	if chunk_list[chunk_key]:
		chunk_list[chunk_key].active = true
	else:
		chunk_list[chunk_key] = Chunk.new()

class Chunk:
	var active: bool = false
	var status: String = "incomplete"
