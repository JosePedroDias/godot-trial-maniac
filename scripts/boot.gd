extends Node

func _ready():
	# Wait one frame to ensure GameManager is fully initialized
	await get_tree().process_frame
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.tracks.size() > 0:
		print("Booting into first track: ", gm.tracks[0])
		get_tree().change_scene_to_file(gm.tracks[0])
	else:
		print("Error: GameManager or tracks not found")
