extends Node

func _ready():
	var args = OS.get_cmdline_args()
	
	if "--generate" in args:
		_run_generation(args)
		return

	# Wait one frame to ensure GameManager is fully initialized
	await get_tree().process_frame
	if not (GameManager and GameManager.tracks.size() > 0):
		print("Error: GameManager or tracks not found")
		return

	var target_track = GameManager.tracks[0]
	
	for i in range(args.size()):
		if args[i] == "--track" or args[i] == "--circuit":
			if i + 1 < args.size():
				var val = args[i+1]
				if val.is_valid_int():
					var idx = val.to_int()
					if idx >= 0 and idx < GameManager.tracks.size():
						target_track = GameManager.tracks[idx]
						print("Booting into track index ", idx, ": ", target_track)
				else:
					# Search by name
					for t in GameManager.tracks:
						if t.to_lower().contains(val.to_lower()):
							target_track = t
							print("Booting into track matching '", val, "': ", target_track)
							break
	
	if target_track == GameManager.tracks[0] and args.size() == 0:
		print("Booting into first track: ", target_track)
	
	get_tree().change_scene_to_file(target_track)

func _run_generation(args):
	print("Starting track regeneration with full context...")
	var force = "--force" in args
	var track_from_json = load("res://scripts/track_from_json.gd").new()
	
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
					var output = track_from_json.generate_from_json(json_path)
					if output:
						print("Successfully generated track: ", output)
					else:
						print("Failed to generate track: ", track_name)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the tracks path.")
	
	get_tree().quit()
