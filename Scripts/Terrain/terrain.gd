## Manages terrain generation and rendering using chunks.
extends Node3D

@export_category("Terrain")
@export var render_distance: int = 5 ## In chunks
@export var chunk_size: Vector3i = Vector3i(16,256,16)

var ChunkList: Array[Chunk] = []

var Player: CharacterBody3D


## Initializes the terrain generation.
func _ready() -> void:
	Player = get_parent().find_child("Player")
	print(Player.name)

class Chunk:
	var vector: Vector3i
	var active: bool = false
