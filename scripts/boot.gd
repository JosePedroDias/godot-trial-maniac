extends Node

func _ready():
	# Wait one frame to ensure GameManager is fully initialized
	await get_tree().process_frame
	var gm = get_node_or_null("/root/GameManager")
	if not (gm and gm.tracks.size() > 0):
		print("Error: GameManager or tracks not found")
		return

	var target_track = gm.tracks[0]
	var args = OS.get_cmdline_args()
	
	for i in range(args.size()):
		if args[i] == "--track" or args[i] == "--circuit":
			if i + 1 < args.size():
				var val = args[i+1]
				if val.is_valid_int():
					var idx = val.to_int()
					if idx >= 0 and idx < gm.tracks.size():
						target_track = gm.tracks[idx]
						print("Booting into track index ", idx, ": ", target_track)
				else:
					# Search by name
					for t in gm.tracks:
						if t.to_lower().contains(val.to_lower()):
							target_track = t
							print("Booting into track matching '", val, "': ", target_track)
							break
	
	if target_track == gm.tracks[0] and args.size() == 0:
		print("Booting into first track: ", target_track)
	
	get_tree().change_scene_to_file(target_track)
