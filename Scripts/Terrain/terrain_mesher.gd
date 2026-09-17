extends Node

func mesh_chunk(chunk_key: Vector3i, chunk_data: Dictionary[Vector3i, float], block_data: Dictionary[Vector3i, int]) -> void:
	
	var t = Time.get_ticks_msec()
	
	var chunk_size: Vector3i = get_parent().chunk_size
	var block_size: float = get_parent().block_size 
	
	var new_mesh: ArrayMesh = MarchingCubes.generate_mesh(chunk_data,chunk_size,block_size,block_data)
	
	print("Chunk meshed in: " + str(Time.get_ticks_msec()-t))
	
	SignalBus.meshing_ended.emit.call_deferred(chunk_key,new_mesh)
