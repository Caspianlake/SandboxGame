extends Node3D

@export_category("Terrain")
@export var render_distance: int = 5 ## In chunks
@export var chunk_size: Vector3i = Vector3i(16,256,16)
@export var block_size: int = 1

var chunk_list: Array[Chunk] = []

var player: CharacterBody3D

func _ready() -> void:
	player = get_parent().find_child("Player")

func _process(delta: float) -> void:
	if player:
		terrain_process()

func terrain_process() -> void:
	var player_cvector = TerrainUtil.get_player_chunk(player.position,chunk_size,block_size)

class Chunk:
	var vector: Vector3i
	var active: bool = false
