extends Node3D

var ghost_data = [] # Array of snapshots { "b": body_transform, "w": [wheel_transforms] }
var current_index = 0
var is_playing = false

func _ready():
	_set_transparent(self)

func _set_transparent(node):
	for child in node.get_children():
		if child is MeshInstance3D:
			var mat = child.mesh.material
			if mat is StandardMaterial3D:
				var ghost_mat = mat.duplicate()
				ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				ghost_mat.albedo_color.a = 0.4
				child.material_override = ghost_mat
		_set_transparent(child)

func start_playback(data):
	ghost_data = data
	current_index = 0
	is_playing = true
	visible = true
	if ghost_data.size() > 0:
		var snapshot = ghost_data[0]
		if snapshot is Dictionary:
			global_transform = snapshot.b
		else:
			global_transform = snapshot # Fallback for old data

func stop_playback():
	is_playing = false
	visible = false

func _physics_process(_delta):
	if is_playing and current_index < ghost_data.size():
		var snapshot = ghost_data[current_index]
		
		if snapshot is Dictionary:
			global_transform = snapshot.b
			
			var wheels = get_meta("wheels", [])
			if wheels.size() == 4 and snapshot.w.size() == 4:
				for i in range(4):
					wheels[i].transform = snapshot.w[i]
		else:
			# Handle old data format (just body transform)
			global_transform = snapshot
			
		current_index += 1
	elif current_index >= ghost_data.size():
		is_playing = false
