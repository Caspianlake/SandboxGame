extends Node3D

@export var t_noise:= FastNoiseLite.new()
@export var t_material:= StandardMaterial3D.new()
@export var chunk_size:= Vector3i(16,256,16)


var tasks_remaining: int = 0
var t_start: int

func sdfGenEnded(data):
	tasks_remaining -= 1
	
	if data:
		ThreadPool.add_task(SurfaceNets.generate_mesh.bind(data,chunk_size+Vector3i(2,2,2)))
		tasks_remaining += 1
	else:
		print("buh")

func meshingEnded(data):
	tasks_remaining -= 1
	
	if tasks_remaining == 0:
		print("49 Chunks completed in: ",Time.get_ticks_msec()-t_start)

func _ready() -> void:
	
	SignalBus.SDFGenEnded.connect(sdfGenEnded)
	SignalBus.MeshingEnded.connect(meshingEnded)
	
	t_start = Time.get_ticks_msec()
	
	for cx in range(-3,4):
		for cz in range(-3,4):
			var chunk_key := Vector3i(cx,0,cz)
			ThreadPool.add_task(TerrainDataGenerator.generate_sdf.bind(t_noise,chunk_size,chunk_key))
			tasks_remaining += 1
