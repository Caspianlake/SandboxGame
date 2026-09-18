extends Node

@export_category("Generation Settings")
@export var main_noise: FastNoiseLite = FastNoiseLite.new()
@export var height_curve: Curve = Curve.new()

@export var lod_step: int = 1

func generate_chunk(chunk_key: Vector3i) -> void:
	var t = Time.get_ticks_msec()
	
	var chunk_size: Vector3i = get_parent().chunk_size
	
	var chunk_data: Dictionary[Vector3i, float] = {}
	var block_data: Dictionary[Vector3i, int] = {}
	var chunk_offset: Vector3i = Vector3i(chunk_size.x * chunk_key.x, chunk_size.y * chunk_key.y, chunk_size.z * chunk_key.z)
	
	var step_f: float = float(lod_step)
	
	for bx in range(-1, chunk_size.x + 2):
		var world_x: float = float(bx + chunk_offset.x)
		var fx: float = snappedf(world_x - (step_f - 1.0) / 2.0, step_f) # Snaps to grid steps
		for bz in range(-1, chunk_size.z + 2):
			var world_z: float = float(bz + chunk_offset.z)
			var fz: float = snappedf(world_z - (step_f - 1.0) / 2.0, step_f)
			for by in range(-1, chunk_size.y + 2):
				var fy: float = snappedf(float(by), step_f)
				var raw_noise = main_noise.get_noise_3d(fx, fy, fz)
				raw_noise = clamp(raw_noise - height_curve.sample(remap(by,0.0,(chunk_size.y+2.0),0.0,1.0)),-1.0,1.0)
				var fsdf: float = 1.0 if raw_noise > 0.0  else -1.0
				chunk_data[Vector3i(bx, by, bz)] = fsdf
				if fy < 41:
					block_data[Vector3i(bx,by,bz)] = 2
				elif fy < 47:
					block_data[Vector3i(bx,by,bz)] = 3
				elif fy < 100:
					block_data[Vector3i(bx,by,bz)] = 1
				elif fy < 112:
					block_data[Vector3i(bx,by,bz)] = 2
				else: 
					block_data[Vector3i(bx,by,bz)] = 4

	print("Chunk data generated in: " + str(Time.get_ticks_msec() - t))
	SignalBus.chunk_gen_ended.emit.call_deferred(chunk_key, chunk_data, block_data)
