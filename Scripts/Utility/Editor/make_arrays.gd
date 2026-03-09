@tool
extends EditorScript

func _run():
	# Define your paths - update these to match your folder structure
	var folders = {
		"albedo": "res://Assets/Materials/albedo/",
		"normal": "res://Assets/Materials/normal/",
		"orm":    "res://Assets/Materials/orm/"
	}
	var output_dir = "res://Assets/Materials/baked_arrays/"
	
	if !DirAccess.dir_exists_absolute(output_dir):
		DirAccess.make_dir_absolute(output_dir)

	# 1. Get the master file list from Albedo folder 
	# (Assumes Normal and ORM have matching file names)
	var files = Array(DirAccess.get_files_at(folders.albedo))
	files = files.filter(func(f): return (f.ends_with(".png") or f.ends_with(".jpg")) and !f.contains(".import"))
	files.sort()

	if files.size() == 0:
		print("No valid textures found in albedo folder!")
		return

	print("Found %d materials. Starting pre-compressed bake..." % files.size())

	# 2. Bake each type
	_bake_precompressed_array(folders.albedo, files, output_dir + "albedo_array.res")
	_bake_precompressed_array(folders.normal, files, output_dir + "normal_array.res")
	_bake_precompressed_array(folders.orm,    files, output_dir + "orm_array.res")

func _bake_precompressed_array(folder_path: String, file_list: Array, save_path: String):
	var images: Array[Image] = []
	
	for file_name in file_list:
		var full_path = folder_path + file_name
		var tex = load(full_path)
		
		if tex is Texture2D:
			var img = tex.get_image()
			
			# Check for compression - if these aren't compressed, 
			# the script still works but the file remains large.
			if not img.is_compressed():
				print("Warning: %s is NOT compressed. Consider setting to VRAM Compressed in Import tab." % file_name)
			
			images.append(img)
		else:
			print("Error: Could not load texture at ", full_path)

	if images.size() > 0:
		var tex_array = Texture2DArray.new()
		var err = tex_array.create_from_images(images)
		
		if err == OK:
			ResourceSaver.save(tex_array, save_path)
			print("Baked successfully: ", save_path)
		else:
			print("Bake FAILED for %s. Error code: %d" % [save_path, err])
			_explain_error(err)

func _explain_error(code: int):
	match code:
		31: print("   -> Reason: Format mismatch. All textures in this folder MUST have identical Compression settings and Dimensions.")
		_: print("   -> Reason: Check Godot's internal error logs for code ", code)
