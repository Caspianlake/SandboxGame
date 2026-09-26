extends Node

@export_category("Generation Settings")
@export var main_noise: FastNoiseLite = FastNoiseLite.new()
@export var height_curve: Curve = Curve.new()

@export var lod_step: int = 1

func generate_chunk(chunk_key: Vector3i) -> void:
	var t = Time.get_ticks_msec()
	
	var chunk_size: Vector3i = get_parent().chunk_size
	var block_size: float = get_parent().block_size
	
	var chunk_data: Dictionary[Vector3i, float] = {}
	var block_data: Dictionary[Vector3i, int] = {}
	var chunk_offset: Vector3i = Vector3i(chunk_size.x * chunk_key.x, chunk_size.y * chunk_key.y, chunk_size.z * chunk_key.z)
	
	var step_f: float = float(lod_step)
	
	for bx in range(-1, chunk_size.x + 2):
		var world_x: float = float(bx + chunk_offset.x)
		var fx: float = snappedf(world_x - (step_f - 1.0) / 2.0, step_f) 
		for bz in range(-1, chunk_size.z + 2):
			var world_z: float = float(bz + chunk_offset.z)
			var fz: float = snappedf(world_z - (step_f - 1.0) / 2.0, step_f)
			var raw_noise: float = (main_noise.get_noise_2d(fx, fz) + 1) / 2
			var final_noise = remap(raw_noise,0.0,1.0,0.0,chunk_size.y)
			for by in range(-1, chunk_size.y + 2):
				var fy: float = snappedf(float(by), step_f)
				var fsdf: float = 1.0 if fy < final_noise else -1.0
				
				chunk_data[Vector3i(bx, by, bz)] = fsdf
				var block: int = 0
				var fby: float = float(by) / float(chunk_size.y)
				
				if fby < 83.0 / 256.0 :
					block = 2
				elif fby < 91 / 256.0:
					block = 3
				elif fby < 220.0 / 256.0:
					block = 1
				elif fby < 244.0 / 256.0:
					block = 2
				else: 
					block = 4
				
				block_data[Vector3i(bx,by,bz)] = block
				
	print("Chunk generated in: " + str(Time.get_ticks_msec() - t))
	
	t = Time.get_ticks_msec()
	var new_mesh: ArrayMesh = MarchingCubes.generate_mesh(chunk_data,chunk_size,block_size,block_data)
	print("Chunk meshed in: " + str(Time.get_ticks_msec() - t))
	
	SignalBus.chunk_gen_ended.emit.call_deferred(chunk_key, new_mesh)
