extends Node3D 

@export_category("Terrain")
@export var render_distance: int = 3 
@export var chunk_size: Vector3i = Vector3i(16,256,16)
@export var block_size: float = 0.5

var chunk_list: Dictionary[Vector3i, Chunk] = {}

var player: CharacterBody3D
var player_last_ck: Vector3i

var last_render_dist: int

func _ready() -> void:
	SignalBus.chunk_gen_ended.connect(on_chunk_gen_ended)
	player = get_parent().find_child("Player")
	last_render_dist = render_distance

func chunk_load(chunk_key: Vector3i) -> void:
	var chunk: Chunk = chunk_list[chunk_key]
	chunk.instance = MeshInstance3D.new()
	chunk.instance.material_override = load("res://Resources/UniversalMaterial.tres")
	chunk.instance.mesh = chunk.mesh
	chunk.instance.position = Vector3(chunk_key.x*chunk_size.x*block_size,0,chunk_key.z*chunk_size.x*block_size)
	$Chunks.add_child(chunk.instance)
	chunk.status = "loaded"

func chunk_unload(chunk: Chunk) -> void:
	chunk.instance.queue_free()
	chunk.instance = null
	chunk.status = "unloaded"

func reload() -> void:
	for chunk in chunk_list:
		var current_chunk: Chunk = chunk_list[chunk]
		if current_chunk.active and current_chunk.status == "unloaded":
			chunk_load(chunk)
		elif current_chunk.active != true and current_chunk.status == "loaded":
			chunk_unload(current_chunk)
		
func deactivate() -> void:
	for ck in chunk_list:
		chunk_list[ck].active = false

func activate(chunk_key: Vector3i) -> void:
	if chunk_list.has(chunk_key):
		chunk_list[chunk_key].active = true
	else:
		chunk_list[chunk_key] = Chunk.new()
		chunk_list[chunk_key].active = true
		ThreadPool.add_task($TerrainDataGenerator.generate_chunk.bind(chunk_key))

func _process(_delta: float) -> void:
	if player:
		var player_ck: Vector3i = TerrainUtil.get_player_chunk(player.position,chunk_size,block_size)
		if player_last_ck != player_ck or not player_last_ck:
			terrain_process(player_ck)
		if last_render_dist != render_distance:
			last_render_dist = render_distance
			terrain_process(player_ck)
			
		player_last_ck = player_ck

func terrain_process(player_ck: Vector3i) -> void:
	deactivate()
	for cx in range(-render_distance, render_distance + 1):
		for cz in range (-render_distance, render_distance + 1):
			activate(Vector3i(player_ck.x + cx,0,player_ck.z + cz))
	reload()

func on_chunk_gen_ended(chunk_key: Vector3i, chunk_mesh: Mesh) -> void:
	chunk_list[chunk_key].mesh = chunk_mesh
	chunk_list[chunk_key].status = "unloaded"
	reload()

class Chunk:
	var active: bool = false
	var status: String = "incomplete"
	var mesh: Mesh
	var instance: MeshInstance3D
