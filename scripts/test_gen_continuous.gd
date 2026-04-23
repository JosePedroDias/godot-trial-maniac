extends SceneTree

func _init():
	var Generator = load("res://scripts/continuous_track_generator.gd")
	var gen = Generator.new()
	
	for s in [111, 222, 333]:
		print("--- Generating Organic Continuous Track for Seed: ", s, " ---")
		gen.generate(s, 80)
		print("\n")
	
	quit()
