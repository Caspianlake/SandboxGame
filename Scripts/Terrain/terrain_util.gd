class_name TerrainUtil
extends Node


static func get_player_chunk(player_position: Vector3i, chunk_size: Vector3i, block_size: int) -> Vector3i:
	var x: int = floori(player_position.x / chunk_size.x)
	var y: int = floori(player_position.y / chunk_size.y)
	var z: int = floori(player_position.z / chunk_size.z)
	
	return Vector3i(x,y,z)
