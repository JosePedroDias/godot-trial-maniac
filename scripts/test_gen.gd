extends SceneTree

func _init():
	var Generator = load("res://scripts/track_generator.gd")
	var gen = Generator.new()
	
	for s in [12345, 54321, 98765]:
		print("--- Generating Track for Seed: ", s, " ---")
		gen.generate(s, 25)
		print("\n")
	
	quit()
