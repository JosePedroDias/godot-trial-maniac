extends RigidBody3D

@export_group("Suspension")
@export var suspension_rest_dist: float = 0.4 
@export var spring_strength: float = 400000.0 
@export var spring_damping: float = 50000.0
@export var wheel_radius: float = 0.33

@export_group("Engine")
@export var engine_power: float = 75000.0 
@export var max_speed: float = 340.0 
@export var aero_downforce: float = 12.0 

@export_group("Steering")
@export var steering_angle: float = 20.0
@export var steering_speed: float = 4.0
@export var grip: float = 4.0 

# Cosmetic/Sound
var current_gear: int = 1
var gear_shift_points = [0, 80, 130, 175, 215, 255, 290, 315, 400]
var current_rpm: float = 3500.0

var steering_input = 0.0
var throttle_input = 0.0
var brake_input = 0.0
var engine_input = 0.0 # Net for display/sound

var input_override: bool = false
var fall_timer: float = 0.0
var settle_timer: float = 2.0 

var engine_player: AudioStreamPlayer3D
var skid_player: AudioStreamPlayer3D
var collision_player: AudioStreamPlayer3D

var _raycasts = []
var _wheels = []
var _wheel_rotation: float = 0.0
var on_ground: bool = false
var ground_timer: float = 0.0
var is_skidding: bool = false
var is_braking: bool = false
var trails = []

func _ready():
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	
	linear_damp = 0.0
	angular_damp = 0.0
	center_of_mass_mode = 1
	center_of_mass = Vector3(0, -0.4, 0)

	_raycasts = [$RayCastFL, $RayCastFR, $RayCastRL, $RayCastRR]
	_wheels = [$WheelFL, $WheelFR, $WheelRL, $WheelRR]
	
	for ray in _raycasts:
		if ray:
			ray.target_position = Vector3(0, -1.2, 0)
			ray.add_exception(self)
	
	_setup_audio()
	mass = 1500.0
	
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.sfx_toggled.connect(_on_sfx_toggled)
		_update_sfx_mute(gm.sfx_enabled)

func _on_sfx_toggled(enabled):
	_update_sfx_mute(enabled)

func _update_sfx_mute(enabled):
	var players = [engine_player, skid_player, collision_player]
	var brake_p = get_meta("brake_player") if has_meta("brake_player") else null
	if brake_p: players.append(brake_p)
	for p in players:
		if p:
			if not enabled: p.stop()
			else: p.play()

func _setup_audio():
	engine_player = AudioStreamPlayer3D.new()
	engine_player.set_script(load("res://scripts/engine_sound.gd"))
	skid_player = AudioStreamPlayer3D.new()
	collision_player = AudioStreamPlayer3D.new()
	if is_inside_tree():
		add_child(engine_player)
		add_child(skid_player)
		add_child(collision_player)
	engine_player.unit_size = 30.0
	engine_player.play()
	
	# Skid Sound
	var skid_stream = AudioStreamWAV.new()
	skid_stream.format = AudioStreamWAV.FORMAT_16_BITS
	skid_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	skid_stream.mix_rate = 44100
	var s_data = PackedByteArray()
	var s_len = 22050
	s_data.resize(s_len * 2)
	for i in range(s_len):
		var val = int((randf() * 2.0 - 1.0) * 5000)
		s_data.encode_s16(i * 2, val)
	skid_stream.data = s_data
	skid_stream.loop_end = s_len
	skid_player.stream = skid_stream
	skid_player.unit_size = 30.0
	skid_player.play()
	
	# Braking Sound
	var brake_player = AudioStreamPlayer3D.new()
	brake_player.unit_size = 30.0
	if is_inside_tree():
		add_child(brake_player)
	self.set_meta("brake_player", brake_player)
	var brake_stream = AudioStreamWAV.new()
	brake_stream.format = AudioStreamWAV.FORMAT_16_BITS
	brake_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	brake_stream.mix_rate = 44100
	var b_data = PackedByteArray()
	var b_len = 4410
	b_data.resize(b_len * 2)
	for i in range(b_len):
		var t = float(i) / b_len
		var val = int(sin(t * 800.0) * 3000)
		b_data.encode_s16(i * 2, val)
	brake_stream.data = b_data
	brake_stream.loop_end = b_len
	brake_player.stream = brake_stream
	brake_player.volume_db = -80
	brake_player.play()
	
	# Collision Sound
	var coll_stream = AudioStreamWAV.new()
	coll_stream.format = AudioStreamWAV.FORMAT_16_BITS
	coll_stream.mix_rate = 44100
	var c_data = PackedByteArray()
	var c_len = 22050
	c_data.resize(c_len * 2)
	for i in range(c_len):
		var t = float(i) / c_len
		var noise = (randf() * 2.0 - 1.0) * 15000 * exp(-t * 20.0)
		var tone = sin(t * 80.0) * exp(-t * 8.0) * 20000
		var val = int(clamp(tone + noise, -32768, 32767))
		c_data.encode_s16(i * 2, val)
	coll_stream.data = c_data
	collision_player.stream = coll_stream
	collision_player.unit_size = 20.0

func _physics_process(delta):
	if settle_timer > 0:
		settle_timer -= delta
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		return

	var gm = get_node_or_null("/root/GameManager")
	var sfx_enabled = gm.sfx_enabled if gm else true
	
	# 1. Ground Detection
	var currently_touching = false
	var total_comp = 0.0
	for ray in _raycasts:
		if ray and ray.is_colliding():
			var d = (ray.global_position - ray.get_collision_point()).length()
			var c = (suspension_rest_dist + wheel_radius) - d
			if c > 0:
				currently_touching = true
				total_comp += c

	if currently_touching:
		on_ground = true
		ground_timer = 0.2
	else:
		ground_timer -= delta
		on_ground = (ground_timer > 0)

	# 2. Fall Detection
	if !on_ground or global_position.y < -50.0:
		fall_timer += delta
		if fall_timer > 2.0 or global_position.y < -100.0:
			if gm: gm.reset_race()
			fall_timer = 0.0
			return
	else:
		fall_timer = 0.0

	var speed_cur = linear_velocity.length()
	var speed_kmh = speed_cur * 3.6
	var forward_speed = global_basis.z.dot(linear_velocity)
	
	if gm: gm.speed_updated.emit(speed_kmh)
	
	if speed_kmh > max_speed:
		linear_velocity = linear_velocity.normalized() * (max_speed / 3.6)
		speed_kmh = max_speed

	# 3. Stability & Aerodynamics
	angular_damp = lerp(2.0, 12.0, clamp(speed_kmh / 300.0, 0.0, 1.0))
	var drag_coeff = 0.012
	var drag_force = -linear_velocity * speed_cur * drag_coeff * mass
	apply_central_force(drag_force)
	
	var down_force_mag = speed_cur * speed_cur * aero_downforce
	var static_glue = 8000.0 if on_ground else 0.0
	apply_central_force(-global_basis.y * (down_force_mag + static_glue))
	
	var local_av = global_basis.inverse() * angular_velocity
	apply_torque(global_basis.x * (-local_av.x * 60000.0))

	if not input_override: _read_input(gm, delta)
	
	# State Detection (Brake vs Reverse)
	is_braking = false
	var final_engine_torque = throttle_input
	
	if brake_input > 0.1:
		if forward_speed > 0.5:
			is_braking = true
			final_engine_torque = 0.0 # Don't apply throttle if braking hard
		elif forward_speed < 1.0:
			# Reverse logic: if nearly stopped, brake becomes reverse
			final_engine_torque = -brake_input * 0.4 # Slower reverse
	
	engine_input = final_engine_torque # Net value for sound/HUD

	is_skidding = false
	if speed_cur > 5.0:
		var lat_speed = abs(global_basis.x.dot(linear_velocity))
		if lat_speed > 12.0 + speed_cur * 0.1: is_skidding = true

	# Audio Update
	if skid_player and sfx_enabled:
		var target_skid_vol = 5 if (is_skidding and on_ground) else -80
		skid_player.volume_db = lerp(skid_player.volume_db, float(target_skid_vol), 10.0 * delta)
	var brake_plr = get_meta("brake_player") if has_meta("brake_player") else null
	if brake_plr and sfx_enabled:
		var target_brake_vol = 0 if (is_braking and on_ground) else -80
		brake_plr.volume_db = lerp(brake_plr.volume_db, float(target_brake_vol), 15.0 * delta)

	if is_braking:
		# Controlled 5g braking deceleration
		var brake_accel = 50.0 * brake_input
		var brake_f = brake_accel * mass
		apply_central_force(-global_basis.z * sign(forward_speed) * brake_f)

	# 4. Suspension & Traction
	var suspension_limiter = 1.0
	if currently_touching and speed_kmh < 50.0:
		suspension_limiter = lerp(0.2, 1.0, speed_kmh / 50.0)

	for i in range(_raycasts.size()):
		var ray = _raycasts[i]
		var wheel = _wheels[i] if _wheels.size() > i else null
		if not ray or not ray.is_colliding():
			if wheel: wheel.position.y = -suspension_rest_dist
			continue
			
		var hit_pt = ray.get_collision_point()
		var hit_norm = ray.get_collision_normal()
		var dist = (ray.global_position - hit_pt).length()
		var comp = (suspension_rest_dist + wheel_radius) - dist
		
		if comp > 0:
			var v_at_w = linear_velocity + angular_velocity.cross(ray.global_position - global_position)
			var up_v = hit_norm.dot(v_at_w)
			
			var extra_push = 0.0
			if comp > 0.38: extra_push = (comp - 0.38) * 3000000.0

			var s_force = comp * spring_strength * suspension_limiter
			var d_force = up_v * spring_damping
			apply_force(hit_norm * (s_force - d_force + extra_push), ray.global_position - global_position)
			
			var w_basis = ray.global_basis
			if i < 2:
				var s_fac = lerp(1.0, 0.15, clamp(speed_kmh / 200.0, 0.0, 1.0))
				w_basis = w_basis.rotated(global_basis.y, steering_input * deg_to_rad(steering_angle) * s_fac)
			
			if abs(final_engine_torque) > 0.01:
				apply_force(w_basis.z * final_engine_torque * engine_power, ray.global_position - global_position)
			
			var side_v = w_basis.x.dot(v_at_w)
			apply_force(-w_basis.x * side_v * mass * grip * (1.0 + speed_cur * 0.05), ray.global_position - global_position)
			
		if wheel: wheel.global_position = hit_pt + hit_norm * wheel_radius
			
	_update_cosmetic_gears(delta, speed_kmh)
	if engine_player and sfx_enabled:
		engine_player.rpm_raw = current_rpm
		engine_player.throttle = abs(engine_input)

func _read_input(gm, delta):
	if gm:
		var get_val = func(slot):
			if slot.get("is_kb", false): return 1.0 if Input.is_key_pressed(slot.key) else 0.0
			var val = Input.get_joy_axis(slot.dev, slot.axis)
			return clamp((val - slot.get("snap", 0.0)) * slot.sign, 0.0, 1.0)
		steering_input = lerp(steering_input, get_val.call(gm.steer_left) - get_val.call(gm.steer_right), steering_speed * delta)
		throttle_input = get_val.call(gm.throttle)
		brake_input = get_val.call(gm.brake)
	else:
		steering_input = lerp(steering_input, Input.get_axis("ui_right", "ui_left"), steering_speed * delta)
		throttle_input = Input.get_action_strength("ui_up")
		brake_input = Input.get_action_strength("ui_down")

func _update_cosmetic_gears(delta, speed_kmh):
	var old_gear = current_gear
	for g in range(1, 9):
		if speed_kmh < gear_shift_points[g]:
			current_gear = g; break
	if current_gear != old_gear:
		var gm = get_node_or_null("/root/GameManager")
		if gm: gm.gear_updated.emit(current_gear)
	var g_min = gear_shift_points[current_gear-1]
	var g_max = gear_shift_points[current_gear]
	var pct = (speed_kmh - g_min) / max(1.0, g_max - g_min)
	current_rpm = lerp(current_rpm, lerp(3500.0, 12500.0, pct), 20.0 * delta)

func _on_body_entered(_body):
	if linear_velocity.length() > 5.0 and collision_player: collision_player.play()
