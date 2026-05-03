extends Node3D

var ghost_data = [] # Array of snapshots { "b": body_transform, "w": [wheel_transforms] }
var current_index = 0
var is_playing = false

var engine_player: Node3D
var skid_player: AudioStreamPlayer3D
var brake_player: AudioStreamPlayer3D

var _prev_pos: Vector3 = Vector3.ZERO

func _ready():
	_set_transparent(self)
	_setup_audio()
	
	if GameManager:
		GameManager.sfx_toggled.connect(_on_sfx_toggled)

func _on_sfx_toggled(enabled):
	if not is_inside_tree(): return
	if engine_player and engine_player.has_method("set_enabled"):
		engine_player.set_enabled(enabled)
	var players = [skid_player, brake_player]
	for p in players:
		if p:
			if enabled:
				if is_playing: p.play()
			else:
				p.stop()

func _setup_audio():
	engine_player = Node3D.new()
	engine_player.set_script(load("res://scripts/engine_sound.gd"))
	add_child(engine_player)
	
	skid_player = AudioStreamPlayer3D.new()
	add_child(skid_player)
	skid_player.unit_size = 20.0
	
	brake_player = AudioStreamPlayer3D.new()
	add_child(brake_player)
	brake_player.unit_size = 20.0
	
	_init_skid_and_brake_streams()
	
	if GameManager and GameManager.sfx_enabled:
		if engine_player and engine_player.has_method("set_enabled"):
			engine_player.set_enabled(true)
		skid_player.play()
		brake_player.play()

func _init_skid_and_brake_streams():
	# Skid Sound (Noise)
	var skid_stream = AudioStreamWAV.new()
	skid_stream.format = AudioStreamWAV.FORMAT_16_BITS
	skid_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	skid_stream.mix_rate = 44100
	var s_data = PackedByteArray()
	var s_len = 22050 # 0.5s
	s_data.resize(s_len * 2)
	for i in range(s_len):
		var val = int((randf() * 2.0 - 1.0) * 4000) # Slightly quieter noise
		s_data.encode_s16(i * 2, val)
	skid_stream.data = s_data
	skid_stream.loop_end = s_len
	skid_player.stream = skid_stream
	skid_player.volume_db = -80
	
	# Brake Sound (High pitch squeal)
	var brake_stream = AudioStreamWAV.new()
	brake_stream.format = AudioStreamWAV.FORMAT_16_BITS
	brake_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	brake_stream.mix_rate = 44100
	var b_data = PackedByteArray()
	var b_len = 4410 # 0.1s
	b_data.resize(b_len * 2)
	for i in range(b_len):
		var t = float(i) / b_len
		var val = int(sin(t * 800.0) * 2000) # Quieter sine
		b_data.encode_s16(i * 2, val)
	brake_stream.data = b_data
	brake_stream.loop_end = b_len
	brake_player.stream = brake_stream
	brake_player.volume_db = -80

func _set_transparent(node):
	for child in node.get_children():
		if child is MeshInstance3D:
			var mat = child.get_active_material(0)
			if mat is StandardMaterial3D:
				var ghost_mat = mat.duplicate()
				ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				ghost_mat.albedo_color.a = 0.4
				child.material_override = ghost_mat
		_set_transparent(child)

func start_playback(data):
	if data == null or data.size() == 0:
		is_playing = false
		visible = false
		return
		
	ghost_data = data
	current_index = 0
	is_playing = true
	visible = GameManager.ghost_enabled if GameManager else true
	
	if GameManager and GameManager.sfx_enabled:
		if engine_player and engine_player.has_method("set_enabled"):
			engine_player.set_enabled(true)
		if skid_player: skid_player.play()
		if brake_player: brake_player.play()
		
	if ghost_data.size() > 0:
		var snapshot = ghost_data[0]
		if snapshot is Dictionary:
			global_transform = snapshot.b
			_prev_pos = global_transform.origin
		else:
			global_transform = snapshot # Fallback for old data
			_prev_pos = global_transform.origin

func stop_playback():
	is_playing = false
	visible = false
	if engine_player and engine_player.has_method("set_enabled"):
		engine_player.set_enabled(false)
	if skid_player: skid_player.stop()
	if brake_player: brake_player.stop()

func _physics_process(delta):
	if is_playing and current_index < ghost_data.size():
		var snapshot = ghost_data[current_index]
		
		if snapshot is Dictionary:
			global_transform = snapshot.b
			
			var wheels = get_meta("wheels", [])
			if wheels.size() == 4 and snapshot.w.size() == 4:
				for i in range(4):
					wheels[i].transform = snapshot.w[i]
			
			# Audio Playback from captured state
			if snapshot.has("a") and snapshot.a.size() == 4:
				var a = snapshot.a
				if engine_player:
					engine_player.rpm_raw = a[0]
					engine_player.throttle = a[1]
				
				if skid_player:
					var target_skid_vol = 5 if a[2] else -80
					skid_player.volume_db = lerp(skid_player.volume_db, float(target_skid_vol), 10.0 * delta)
				
				if brake_player:
					var target_brake_vol = 0 if a[3] else -80
					brake_player.volume_db = lerp(brake_player.volume_db, float(target_brake_vol), 15.0 * delta)
			else:
				# Fallback to velocity-based audio for old data
				_update_audio_fallback(delta)
		else:
			# Handle old data format (just body transform)
			global_transform = snapshot
			_update_audio_fallback(delta)
			
		_prev_pos = global_transform.origin
		current_index += 1
	elif current_index >= ghost_data.size():
		is_playing = false
		if engine_player and engine_player.has_method("set_enabled"):
			engine_player.set_enabled(false)
		if skid_player: skid_player.stop()
		if brake_player: brake_player.stop()

func _update_audio_fallback(delta):
	if engine_player:
		var velocity = (global_transform.origin - _prev_pos) / delta
		var speed_cur = velocity.length()
		var speed_kmh = speed_cur * 3.6
		
		var target_rpm = lerp(3500.0, 12500.0, clamp(speed_kmh / 300.0, 0.0, 1.0))
		engine_player.rpm_raw = lerp(engine_player.rpm_raw, target_rpm, 10.0 * delta)
		engine_player.volume_db = -10
