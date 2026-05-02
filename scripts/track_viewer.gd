extends Node3D

@onready var camera = $OrbitCamera
@onready var label = $CanvasLayer/Label

func _ready():
	var args = OS.get_cmdline_args()
	var track_name = ""
	
	# Find track name in args (ignoring flags like --headless)
	for arg in args:
		if not arg.begins_with("-") and arg != "scenes/track_viewer.tscn":
			track_name = arg
			break
			
	if track_name == "":
		label.text = "Error: No track name provided.\nUsage: godot scenes/track_viewer.tscn -- canada"
		return

	var track_path = "res://scenes/%s_track.tscn" % track_name.to_lower()
	if not FileAccess.file_exists(track_path):
		label.text = "Error: Track not found at %s" % track_path
		return

	label.text = "Loading Track: %s..." % track_name
	
	# Load and instantiate track
	var track_scene = load(track_path)
	var track_instance = track_scene.instantiate()
	add_child(track_instance)
	
	# 1. Disable Car physics and scripts to prevent it falling/moving
	var car = track_instance.find_child("Car", true, false)
	if car:
		car.set_physics_process(false)
		car.set_process(false)
		if car is RigidBody3D:
			car.freeze = true
			
	# 2. Hide HUD and Other Cameras
	var old_hud = track_instance.find_child("HUD", true, false)
	if old_hud: old_hud.visible = false
	
	var old_cam = track_instance.find_child("FollowCamera", true, false)
	if old_cam: old_cam.current = false
	
	# 3. Find Mesh and Center Camera
	var road_mesh = track_instance.find_child("RoadMesh", true, false)
	if road_mesh and road_mesh is MeshInstance3D:
		var aabb = road_mesh.get_aabb()
		# Convert local AABB to global if mesh has transform
		var global_aabb = road_mesh.global_transform * aabb
		camera.center_on(global_aabb)
		label.text = "Inspecting: %s\n[LMB] Orbit | [RMB] Pan | [Wheel] Zoom" % track_name
	else:
		label.text = "Inspecting: %s (No RoadMesh found for centering)" % track_name
		camera.orbit_center = Vector3.ZERO
		camera._update_transform()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
