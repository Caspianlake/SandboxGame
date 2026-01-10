class_name TerrainDataGenerator
extends Node


static func generate_sdf(noise_map: FastNoiseLite, chunk_size: Vector3i, chunk_key: Vector3i):
	
	var t_start = Time.get_ticks_msec()
	
	var sample_size:= chunk_size + Vector3i(2,2,2)
	var sdf_data := PackedFloat32Array()
	sdf_data.resize(sample_size.x*sample_size.y*sample_size.z)
			
	var chunk_offset:= Vector3(chunk_key.x * chunk_size.x, 0, chunk_key.z * chunk_size.z)
	var idx = 0
			
			
	for x in range(sample_size.x):
		for z in range(sample_size.z):
			var column_height:= remap(clampf(noise_map.get_noise_2d(chunk_offset.x+x,chunk_offset.z+z),-1,1),-1,1,0,chunk_size.y)
					
			for y in range(sample_size.y):
				sdf_data[idx] = y - column_height
				idx += 1
	
	SignalBus.SDFGenEnded.emit.call_deferred(sdf_data, chunk_key)
	
	print("SDF Generated in: ",Time.get_ticks_msec()-t_start)
	return
