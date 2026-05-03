extends SceneTree

func _init():
	print("Starting manual track regeneration...")
	var track_from_json = load("res://scripts/track_from_json.gd").new()
	
	var dir = DirAccess.open("res://assets/tracks")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with("_processed.json"):
				var json_path = "res://assets/tracks/" + file_name
				var track_name = file_name.replace("_processed.json", "")
				
				print("Generating track: ", track_name)
				var output = track_from_json.generate_from_json(json_path)
				if output:
					print("Successfully generated track: ", output)
				else:
					print("Failed to generate track: ", track_name)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the tracks path.")
	
	quit()
