class_name TerrainUtil
extends Node


static func get_player_chunk(player_position: Vector3i, chunk_size: Vector3i, block_size: int) -> Vector3i:
	var x: int = floori(player_position.x / (float(chunk_size.x) * block_size))
	var y: int = floori(player_position.y / (float(chunk_size.y) * block_size))
	var z: int = floori(player_position.z / (float(chunk_size.z) * block_size))
	
	return Vector3i(x,y,z)
