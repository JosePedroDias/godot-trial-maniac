extends SceneTree

func _init():
	var BlockyGen = load("res://scripts/track_generator.gd")
	var ContinuousGen = load("res://scripts/continuous_track_generator.gd")
	
	var b_gen = BlockyGen.new()
	var c_gen = ContinuousGen.new()
	
	print("--- Generating Additional Blocky Tracks ---")
	b_gen.generate(13579, 25)
	b_gen.generate(24680, 25)
	
	print("\n--- Generating Additional Continuous Tracks ---")
	c_gen.generate(444, 80)
	c_gen.generate(555, 80)
	
	print("\nGeneration complete.")
	quit()
