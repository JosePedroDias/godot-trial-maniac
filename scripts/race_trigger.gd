extends Area3D

@export var is_start_line: bool = true

func _on_body_entered(body):
	if body.name == "Car":
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			if is_start_line:
				gm.start_race()
			else:
				gm.finish_race()
