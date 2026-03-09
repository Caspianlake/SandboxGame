class_name TerrainDataGenerator
extends Node

@export_category("Generation Settings")
@export var main_noise: FastNoiseLite = FastNoiseLite.new()

func generate_chunk(chunk_size: Vector3i, chunk_key: Vector3i, block_size: int) -> void:
	var chunk_data: Dictionary[Vector3i, int] = Dictionary()
	var block_offset: Vector3i = chunk_key * block_size
	
	for bx in range(-1, chunk_size.x + 2):
		for bz in range(-1, chunk_size.z + 2):
			var cell_height: int = floori(remap(main_noise.get_noise_2d(bx+block_offset.x,bz+block_offset.z),-1,1,0,chunk_size.y))
			
			for by in range(0, chunk_size.y + 1):
				if by <= cell_height:
					chunk_data[Vector3i(bx,by,bz)] = 1
				else:
					chunk_data[Vector3i(bx,by,bz)] = 0
	
	
