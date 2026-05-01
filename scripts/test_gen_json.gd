extends SceneTree

func _init():
	var gen_script = load("res://scripts/track_from_json.gd").new()
	
	var tracks = ["usa_miami", "spain"]
	for track in tracks:
		var json_path = "res://assets/tracks/%s_processed.json" % track
		var output = gen_script.generate_from_json(json_path)
		if output:
			print("Successfully generated track: ", output)
		else:
			print("Failed to generate track: ", track)
	
	quit()
