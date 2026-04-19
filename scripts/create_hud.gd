extends SceneTree

func _init():
	var hud = Control.new()
	hud.name = "HUD"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.set_script(load("res://scripts/hud.gd"))
	
	var timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "00:00.000"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	timer_label.position.y = 20
	hud.add_child(timer_label)
	timer_label.owner = hud
	
	var finish_label = Label.new()
	finish_label.name = "FinishLabel"
	finish_label.text = "Finished!"
	finish_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	finish_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hud.add_child(finish_label)
	finish_label.owner = hud
	
	var packed_hud = PackedScene.new()
	packed_hud.pack(hud)
	ResourceSaver.save(packed_hud, "res://scenes/hud.tscn")
	
	print("Successfully created hud scene.")
	quit()
