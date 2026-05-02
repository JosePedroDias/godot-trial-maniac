extends SceneTree

func _init():
	var gen_script = load("res://scripts/track_from_json.gd").new()
	var args = OS.get_cmdline_args()
	var force = "--force" in args
	
	var dir = DirAccess.open("res://assets/tracks")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with("_processed.json"):
				var json_path = "res://assets/tracks/" + file_name
				var track_name = file_name.replace("_processed.json", "")
				var tscn_path = "res://scenes/%s_track.tscn" % track_name
				
				var should_generate = true
				if not force and FileAccess.file_exists(tscn_path):
					var json_time = FileAccess.get_modified_time(json_path)
					var tscn_time = FileAccess.get_modified_time(tscn_path)
					if tscn_time >= json_time:
						print("Skipping up-to-date track: ", track_name)
						should_generate = false
				
				if should_generate:
					print("Generating track: ", track_name)
					var output = gen_script.generate_from_json(json_path)
					if output:
						print("Successfully generated track: ", output)
					else:
						print("Failed to generate track: ", track_name)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
	
	quit()
