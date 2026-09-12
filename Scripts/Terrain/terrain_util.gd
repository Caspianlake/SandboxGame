class_name TerrainUtil
extends Node

static func get_player_chunk(player_position: Vector3, chunk_size: Vector3i, block_size: float) -> Vector3i:
	var chunk_world_size: Vector3 = Vector3(chunk_size) * block_size
	var player_offset_position: Vector3 = player_position + Vector3(chunk_world_size.x / 2.0, 0.0, chunk_world_size.z / 2.0)
	
	var x: int = int(floor(player_offset_position.x / chunk_world_size.x))
	var y: int = int(floor(player_offset_position.y / chunk_world_size.y))
	var z: int = int(floor(player_offset_position.z / chunk_world_size.z))
	
	return Vector3i(x, y, z)
