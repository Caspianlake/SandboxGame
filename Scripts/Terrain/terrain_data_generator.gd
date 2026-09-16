extends Node

@export_category("Generation Settings")
@export var main_noise: FastNoiseLite = FastNoiseLite.new()

func generate_chunk(chunk_key: Vector3i) -> void:
	
	var chunk_size: Vector3i = get_parent().chunk_size
	var block_size: float = get_parent().block_size 
	
	var chunk_data: Dictionary[Vector3i, float] = {}
	var chunk_offset: Vector3i = Vector3i(chunk_size.x*chunk_key.x,chunk_size.y*chunk_key.y,chunk_size.z*chunk_key.z)
	
	for bx in range(-1, chunk_size.x + 2):
		for bz in range(-1, chunk_size.z + 2):
			for by in range(-1, chunk_size.y + 2):
				#var cell_height: int = floori(remap(main_noise.get_noise_2d(bx+chunk_offset.x,bz+chunk_offset.z),-1,1,0,chunk_size.y-1))
				chunk_data[Vector3i(bx,by,bz)] = main_noise.get_noise_3d(bx+chunk_offset.x,by+chunk_offset.y,bz+chunk_offset.z)
	
	SignalBus.chunk_gen_ended.emit.call_deferred(chunk_key, chunk_data)
