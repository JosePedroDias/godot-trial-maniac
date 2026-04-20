extends Node3D

var ghost_data = [] # Array of Transforms
var current_index = 0
var is_playing = false

func _ready():
	# Make it transparent
	_set_transparent(self)

func _set_transparent(node):
	for child in node.get_children():
		if child is MeshInstance3D:
			# Create a unique material for the ghost
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
		global_transform = ghost_data[0]

func stop_playback():
	is_playing = false
	visible = false

func _physics_process(_delta):
	if is_playing and current_index < ghost_data.size():
		global_transform = ghost_data[current_index]
		current_index += 1
	elif current_index >= ghost_data.size():
		is_playing = false
