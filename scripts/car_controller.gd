extends RigidBody3D

@export_group("Engine")
@export var engine_power: float = 150000.0 # Doubled power
@export var brake_force: float = 100000.0
@export var max_speed: float = 400.0 # Increased cap
@export var reverse_force: float = 30000.0

@export_group("Steering")
@export var steering_speed: float = 8.0
@export var steering_angle: float = 15.0 # was 30.0
@export var grip: float = 9.0 # was 12.0

@export_group("Suspension")
@export var suspension_rest_dist: float = 0.4
@export var spring_strength: float = 300.0
@export var spring_damping: float = 15.0
@export var wheel_radius: float = 0.33
@export var aero_downforce: float = 5.0

# Internal State
var steering_input: float = 0.0
var throttle_input: float = 0.0
var brake_input: float = 0.0
var is_on_ground: bool = false
var on_ground: bool = false # Alias for ghost system
var ground_normal: Vector3 = Vector3.UP

# Ghost System / Compatibility
var current_rpm: float = 0.0
var engine_input: float = 0.0
var is_skidding: bool = false
var is_braking: bool = false

var _raycasts = []
var _wheels = []
var _wheel_rot: float = 0.0
var fall_timer: float = 0.0

# Audio & Visuals
var engine_player: AudioStreamPlayer3D
var skid_player: AudioStreamPlayer3D
var collision_player: AudioStreamPlayer3D
var current_gear: int = 1
var gear_shift_points = [0, 60, 110, 150, 190, 230, 270, 310, 400]

func _ready():
	_raycasts = [$RayCastFL, $RayCastFR, $RayCastRL, $RayCastRR]
	_wheels = [$WheelFL, $WheelFR, $WheelRL, $WheelRR]
	
	for ray in _raycasts:
		ray.add_exception(self)
		ray.target_position = Vector3(0, -1.5, 0)
	
	# Physics setup
	gravity_scale = 2.0
	linear_damp = 0.5
	angular_damp = 5.0
	center_of_mass_mode = 1
	center_of_mass = Vector3(0, -0.5, 0)
	
	_setup_audio()
	
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)
	
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.sfx_toggled.connect(_on_sfx_toggled)

func _on_sfx_toggled(enabled):
	if engine_player: engine_player.stream_paused = !enabled
	if skid_player: skid_player.stream_paused = !enabled

func _setup_audio():
	engine_player = AudioStreamPlayer3D.new()
	engine_player.set_script(load("res://scripts/engine_sound.gd"))
	add_child(engine_player)
	engine_player.play()
	
	skid_player = AudioStreamPlayer3D.new()
	add_child(skid_player)
	# Create noise for skid
	var skid_stream = AudioStreamWAV.new()
	skid_stream.format = AudioStreamWAV.FORMAT_16_BITS
	skid_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	skid_stream.mix_rate = 44100
	var data = PackedByteArray()
	data.resize(22050 * 2)
	for i in range(22050):
		data.encode_s16(i*2, int((randf()*2-1)*3000))
	skid_stream.data = data
	skid_stream.loop_end = 22050
	skid_player.stream = skid_stream
	skid_player.volume_db = -80
	skid_player.play()
	
	collision_player = AudioStreamPlayer3D.new()
	add_child(collision_player)
	var coll_stream = AudioStreamWAV.new()
	coll_stream.format = AudioStreamWAV.FORMAT_16_BITS
	coll_stream.mix_rate = 44100
	var c_data = PackedByteArray()
	c_data.resize(4410 * 2)
	for i in range(4410):
		c_data.encode_s16(i*2, int((randf()*2-1)*15000 * exp(-float(i)/1000.0)))
	coll_stream.data = c_data
	collision_player.stream = coll_stream

func _on_body_entered(_body):
	if linear_velocity.length() > 5.0 and collision_player:
		collision_player.play()

func _physics_process(delta):
	_read_input(delta)
	
	# Ground Detection
	var ray_hits = 0
	var avg_normal = Vector3.ZERO
	var avg_dist = 0.0
	
	for ray in _raycasts:
		if ray.is_colliding():
			ray_hits += 1
			avg_normal += ray.get_collision_normal()
			avg_dist += (ray.global_position - ray.get_collision_point()).length()
	
	is_on_ground = ray_hits > 0
	on_ground = is_on_ground
	
	# Fall Detection
	var gm = get_node_or_null("/root/GameManager")
	if !is_on_ground or global_position.y < -50.0:
		fall_timer += delta
		if fall_timer > 2.5 or global_position.y < -100.0:
			if gm: gm.reset_race()
			fall_timer = 0.0
			return
	else:
		fall_timer = 0.0

	# Reset skidding/braking
	is_skidding = false
	is_braking = false
	engine_input = throttle_input - brake_input

	if is_on_ground:
		ground_normal = (avg_normal / ray_hits).normalized()
		var target_dist = avg_dist / ray_hits
		
		var speed_cur = linear_velocity.length()
		var speed_kmh = speed_cur * 3.6
		var forward_v = global_basis.z.dot(linear_velocity)
		
		if brake_input > 0.1 and forward_v > 1.0:
			is_braking = true
		
		# 1. Suspension (Keep car afloat)
		var error = suspension_rest_dist - target_dist
		var spring_f = error * spring_strength
		var upward_v = linear_velocity.dot(global_basis.y)
		var damping_f = upward_v * spring_damping
		apply_central_force(global_basis.y * (spring_f - damping_f) * mass)
		
		# 2. Aero Downforce (Keeps car glued at high speed)
		apply_central_force(-global_basis.y * speed_cur * speed_cur * aero_downforce)
		
		# 3. Alignment (Keep car upright relative to track)
		var curr_up = global_basis.y
		var tilt_axis = curr_up.cross(ground_normal)
		var tilt_angle = curr_up.angle_to(ground_normal)
		if tilt_angle > 0.01:
			apply_torque(tilt_axis * tilt_angle * 1000.0)
		
		# 4. Acceleration / Braking
		if throttle_input > 0 and speed_kmh < max_speed:
			apply_central_force(global_basis.z * throttle_input * engine_power)
		
		if brake_input > 0:
			if forward_v > 1.0:
				apply_central_force(-global_basis.z * brake_input * brake_force)
			else:
				apply_central_force(-global_basis.z * brake_input * reverse_force)
		
		# 5. Steering & Grip (Per-wheel for realistic turning)
		var steer_rad = deg_to_rad(steering_angle) * steering_input
		
		for i in range(4):
			var ray = _raycasts[i]
			if not ray.is_colliding(): continue
			
			var w_basis = global_basis
			if i < 2: # Front wheels
				w_basis = w_basis.rotated(global_basis.y, steer_rad)
			
			var wheel_pos = ray.global_position - global_position
			var v_at_w = linear_velocity + angular_velocity.cross(wheel_pos)
			
			# Lateral force (Grip)
			var lat_v = w_basis.x.dot(v_at_w)
			apply_force(-w_basis.x * lat_v * mass * grip * 0.25, wheel_pos)
			
			if i < 2 and abs(lat_v) > 5.0:
				is_skidding = true

		# Update HUD
		if gm: gm.speed_updated.emit(speed_kmh)
		_update_audio(delta, speed_kmh)
		current_rpm = engine_player.rpm_raw if engine_player else 0.0
	
	_update_wheels(delta)

func _read_input(delta):
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		var get_val = func(slot):
			if slot.get("is_kb", false): return 1.0 if Input.is_key_pressed(slot.key) else 0.0
			return clamp((Input.get_joy_axis(slot.dev, slot.axis) - slot.get("snap", 0.0)) * slot.sign, 0.0, 1.0)
		
		var target_steer = get_val.call(gm.steer_left) - get_val.call(gm.steer_right)
		steering_input = lerp(steering_input, target_steer, steering_speed * delta)
		throttle_input = get_val.call(gm.throttle)
		brake_input = get_val.call(gm.brake)
	else:
		var target_steer = Input.get_axis("ui_right", "ui_left")
		steering_input = lerp(steering_input, target_steer, steering_speed * delta)
		throttle_input = Input.get_action_strength("ui_up")
		brake_input = Input.get_action_strength("ui_down")

func _update_wheels(delta):
	var forward_v = global_basis.z.dot(linear_velocity)
	_wheel_rot += forward_v * delta * 5.0
	
	for i in range(_wheels.size()):
		var wheel = _wheels[i]
		var ray = _raycasts[i]
		
		# Visual Steering for front wheels
		if i < 2:
			wheel.rotation.y = steering_input * deg_to_rad(steering_angle)
		
		if ray.is_colliding():
			var hit_pt = ray.get_collision_point()
			wheel.global_position = hit_pt + ground_normal * wheel_radius
		else:
			wheel.position.y = lerp(wheel.position.y, -suspension_rest_dist, delta * 5.0)
		
		# Rolling
		var mesh = wheel.get_child(0) if wheel.get_child_count() > 0 else null
		if mesh:
			mesh.rotation.x = _wheel_rot

func _update_audio(delta, speed_kmh):
	if engine_player:
		# Simple gear logic
		var old_gear = current_gear
		for g in range(1, 9):
			if speed_kmh < gear_shift_points[g]:
				current_gear = g; break
		
		if current_gear != old_gear:
			var gm = get_node_or_null("/root/GameManager")
			if gm: gm.gear_updated.emit(current_gear)
		
		var gear_min = gear_shift_points[current_gear-1]
		var gear_max = gear_shift_points[current_gear]
		var rpm_pct = clamp((speed_kmh - gear_min) / max(1.0, gear_max - gear_min), 0.0, 1.0)
		engine_player.rpm_raw = lerp(3000.0, 12000.0, rpm_pct)
		engine_player.throttle = throttle_input
	
	if skid_player:
		var lat_v = abs(global_basis.x.dot(linear_velocity))
		var target_vol = -80
		if is_on_ground and lat_v > 5.0:
			target_vol = -10 + clamp(lat_v, 0, 10)
		skid_player.volume_db = lerp(skid_player.volume_db, float(target_vol), delta * 10.0)
