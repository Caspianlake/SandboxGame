extends Node

func mesh_chunk(chunk_key: Vector3i, block_data: Dictionary[Vector3i, int]) -> void:
	
	var chunk_size: Vector3i = get_parent().chunk_size
	var block_size: int = get_parent().block_size 
	var new_mesh = BoxMesh.new()
	new_mesh.size = Vector3(15.9,1,15.9)
	
	SignalBus.meshing_ended.emit.call_deferred(chunk_key,new_mesh)
