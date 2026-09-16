extends Node

@export_category("Generation Settings")
@export var main_noise: FastNoiseLite = FastNoiseLite.new()
@export var height_curve: Curve = Curve.new()

func generate_chunk(chunk_key: Vector3i) -> void:
	
	var t = Time.get_ticks_msec()
	
	var chunk_size: Vector3i = get_parent().chunk_size
	var block_size: float = get_parent().block_size 
	
	var chunk_data: Dictionary[Vector3i, float] = {}
	var chunk_offset: Vector3i = Vector3i(chunk_size.x*chunk_key.x,chunk_size.y*chunk_key.y,chunk_size.z*chunk_key.z)
	
	
	for bx in range(-1, chunk_size.x + 2,2):
		for bz in range(-1, chunk_size.z + 2,2):
			#var raw_noise = remap(main_noise.get_noise_2d(bx+chunk_offset.x,bz+chunk_offset.z),-1,1,0,1)
			#raw_noise = pow(raw_noise,raw_noise)
			#
			#var cell_height = remap(raw_noise,0,1,0,chunk_size.y-1)
			for by in range(-1, chunk_size.y + 2,2):
				
				var raw_noise = main_noise.get_noise_3d(bx+chunk_offset.x,by+chunk_offset.y,bz+chunk_offset.z)
				
				raw_noise = clampf(raw_noise - height_curve.sample(remap(by,-1,chunk_size.y+2,0.0,1.0)),-1.0,1.0)
				
				var fsdf: float = raw_noise
				
				
				chunk_data[Vector3i(bx+1,by,bz)] = fsdf
				chunk_data[Vector3i(bx,by+1,bz)] = fsdf
				chunk_data[Vector3i(bx,by,bz+1)] = fsdf
				chunk_data[Vector3i(bx+1,by+1,bz)] = fsdf
				chunk_data[Vector3i(bx,by+1,bz+1)] = fsdf
				chunk_data[Vector3i(bx+1,by,bz+1)] = fsdf
				chunk_data[Vector3i(bx,by,bz)] = fsdf
				chunk_data[Vector3i(bx+1,by+1,bz+1)] = fsdf
	
	print("Chunk data generated in: " + str(Time.get_ticks_msec()-t))
	
	SignalBus.chunk_gen_ended.emit.call_deferred(chunk_key, chunk_data)
