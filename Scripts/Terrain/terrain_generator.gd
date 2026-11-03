extends Node

@export_category("Generation Settings")
@export var main_noise: FastNoiseLite = FastNoiseLite.new()
@export var height_curve: Curve = Curve.new()
@export var lod_step: int = 1

var base_block
var scenario

func _ready() -> void:
	scenario = owner.find_child("World").get_world_3d().scenario
	base_block = BoxMesh.new()
	base_block.size = Vector3(0.5,0.5,0.5)

func generate_chunk(chunk_key: Vector3i) -> void:
	var t = Time.get_ticks_msec()
	var final_data:= {
		"Position": PackedInt64Array(),
		"BlockID": PackedInt64Array(),
	}
	
	var chunk_size: Vector3i = get_parent().chunk_size
	var chunk_offset: Vector3i = Vector3i(chunk_size.x * chunk_key.x, chunk_size.y * chunk_key.y, chunk_size.z * chunk_key.z)
	
	var step_f: float = float(lod_step)
	
	for bx in range(-1, chunk_size.x + 1):
		var world_x: float = float(bx + chunk_offset.x)
		var fx: float = snappedf(world_x - (step_f - 1.0) / 2.0, step_f) 
		for bz in range(-1, chunk_size.z + 1):
			var world_z: float = float(bz + chunk_offset.z)
			var fz: float = snappedf(world_z - (step_f - 1.0) / 2.0, step_f)
			var raw_noise: float = (main_noise.get_noise_2d(fx, fz) + 1) / 2
			
			raw_noise = pow(raw_noise,2.0)
			
			var final_noise = remap(raw_noise,0.0,1.0,0.0,chunk_size.y)
			for by in range(-1, chunk_size.y + 1):
				var fy: float = snappedf(float(by), step_f)
				var block: int = -1
				var fby: float = float(by) / float(chunk_size.y)
				
				if fy <= final_noise:
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
				else:
					block = -1
				if block != -1:
					final_data["BlockID"].append(block)
					final_data["Position"].append(bx)
					final_data["Position"].append(by)
					final_data["Position"].append(bz)
					
	
	print("Chunk generated in: " + str(Time.get_ticks_msec() - t))
	
	SignalBus.chunk_gen_ended.emit.call_deferred(chunk_key, final_data)
