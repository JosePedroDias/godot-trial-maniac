extends SceneTree

func _init():
	# Start Line
	var start = Area3D.new()
	start.name = "StartLine"
	start.set_script(load("res://scripts/race_trigger.gd"))
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(4, 2, 0.2)
	col.shape = shape
	start.add_child(col)
	col.owner = start
	start.body_entered.connect(start._on_body_entered)
	
	var packed_start = PackedScene.new()
	packed_start.pack(start)
	ResourceSaver.save(packed_start, "res://scenes/start_line.tscn")
	
	# Finish Line
	var finish = Area3D.new()
	finish.name = "FinishLine"
	finish.set_script(load("res://scripts/race_trigger.gd"))
	var col2 = CollisionShape3D.new()
	col2.shape = shape
	finish.add_child(col2)
	col2.owner = finish
	finish.body_entered.connect(finish._on_body_entered)
	
	var packed_finish = PackedScene.new()
	packed_finish.pack(finish)
	ResourceSaver.save(packed_finish, "res://scenes/finish_line.tscn")
	
	print("Successfully created start/finish line scenes.")
	quit()
