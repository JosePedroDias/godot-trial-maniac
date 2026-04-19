extends RigidBody3D

@export_group("Suspension")
@export var suspension_rest_dist: float = 0.3
@export var spring_strength: float = 50000.0
@export var spring_damping: float = 2000.0
@export var wheel_radius: float = 0.3

@export_group("Engine")
@export var engine_power: float = 20000.0
@export var max_speed: float = 100.0
@export var booster_force: float = 50000.0

@export_group("Steering")
@export var steering_angle: float = 30.0
@export var steering_speed: float = 5.0
@export var grip: float = 20.0

@onready var raycasts = [
	$RayCastFL, $RayCastFR, $RayCastRL, $RayCastRR
]
@onready var wheels = [
	$WheelFL, $WheelFR, $WheelRL, $WheelRR
]

var steering_input = 0.0
var engine_input = 0.0

var engine_player: AudioStreamPlayer3D
var skid_player: AudioStreamPlayer3D
var collision_player: AudioStreamPlayer3D

func _ready():
	# Set up physics for collision detection
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	# Set up raycasts
	for ray in raycasts:
		ray.target_position = Vector3(0, -(suspension_rest_dist + wheel_radius), 0)
		ray.add_exception(self)
	
	_setup_audio()
	
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.sfx_toggled.connect(_on_sfx_toggled)
		_update_sfx_mute(gm.sfx_enabled)

func _on_sfx_toggled(enabled):
	_update_sfx_mute(enabled)

func _update_sfx_mute(enabled):
	var players = [engine_player, skid_player, collision_player, get_meta("brake_player")]
	for p in players:
		if p:
			if not enabled:
				p.stop()
			else:
				if p == engine_player or p == skid_player or p == get_meta("brake_player"):
					p.play()

func _setup_audio():
	engine_player = AudioStreamPlayer3D.new()
	skid_player = AudioStreamPlayer3D.new()
	collision_player = AudioStreamPlayer3D.new()
	
	add_child(engine_player)
	add_child(skid_player)
	add_child(collision_player)
	
	# 1. Engine Sound (Sawtooth loop)
	var engine_stream = AudioStreamWAV.new()
	engine_stream.format = AudioStreamWAV.FORMAT_16_BITS
	engine_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	engine_stream.mix_rate = 44100
	var e_data = PackedByteArray()
	var e_len = 441 # ~100Hz base
	e_data.resize(e_len * 2)
	for i in range(e_len):
		var val = int((float(i) / e_len * 2.0 - 1.0) * 10000)
		e_data.encode_s16(i * 2, val)
	engine_stream.data = e_data
	engine_stream.loop_end = e_len
	engine_player.stream = engine_stream
	engine_player.autoplay = true
	engine_player.unit_size = 10.0
	engine_player.play()
	
	# 2. Skid Sound (Noise)
	var skid_stream = AudioStreamWAV.new()
	skid_stream.format = AudioStreamWAV.FORMAT_16_BITS
	skid_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	skid_stream.mix_rate = 44100
	var s_data = PackedByteArray()
	var s_len = 22050 # 0.5s
	s_data.resize(s_len * 2)
	for i in range(s_len):
		var val = int((randf() * 2.0 - 1.0) * 5000)
		s_data.encode_s16(i * 2, val)
	skid_stream.data = s_data
	skid_stream.loop_end = s_len
	skid_player.stream = skid_stream
	skid_player.volume_db = -80 # Start silent
	skid_player.play()
	
	# 3. Braking Sound (High pitch squeal)
	var brake_player = AudioStreamPlayer3D.new()
	add_child(brake_player)
	self.set_meta("brake_player", brake_player)
	var brake_stream = AudioStreamWAV.new()
	brake_stream.format = AudioStreamWAV.FORMAT_16_BITS
	brake_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	brake_stream.mix_rate = 44100
	var b_data = PackedByteArray()
	var b_len = 4410 # 0.1s
	b_data.resize(b_len * 2)
	for i in range(b_len):
		var t = float(i) / b_len
		var val = int(sin(t * 800.0) * 3000) # High frequency sine
		b_data.encode_s16(i * 2, val)
	brake_stream.data = b_data
	brake_stream.loop_end = b_len
	brake_player.stream = brake_stream
	brake_player.volume_db = -80
	brake_player.play()
	
	# 4. Collision Sound (Thump - Made LOUDER and heavier)
	var coll_stream = AudioStreamWAV.new()
	coll_stream.format = AudioStreamWAV.FORMAT_16_BITS
	coll_stream.mix_rate = 44100
	var c_data = PackedByteArray()
	var c_len = 22050 # 0.5s longer decay
	c_data.resize(c_len * 2)
	for i in range(c_len):
		var t = float(i) / c_len
		# Heavier thump: combined low freq and noise burst
		var noise = (randf() * 2.0 - 1.0) * 15000 * exp(-t * 20.0)
		var tone = sin(t * 80.0) * exp(-t * 8.0) * 20000
		var val = int(clamp(tone + noise, -32768, 32767))
		c_data.encode_s16(i * 2, val)
	coll_stream.data = c_data
	collision_player.stream = coll_stream
	collision_player.unit_size = 20.0 # Increase spatial reach

func _physics_process(delta):
	var gm = get_node_or_null("/root/GameManager")
	var sfx_enabled = gm.sfx_enabled if gm else true

	# Update Audio
	var speed = linear_velocity.length()
	if gm:
		gm.speed_updated.emit(speed * 3.6) # Convert m/s to km/h
	
	if engine_player and sfx_enabled:
		engine_player.pitch_scale = 0.5 + (speed / 50.0)
		engine_player.volume_db = -10 + clamp(speed / 10.0, 0, 10)
	
	# Skid and Brake detection
	var is_skidding = false
	var is_braking = false
	if speed > 5.0:
		var lateral_speed = abs(global_basis.x.dot(linear_velocity))
		if lateral_speed > 3.0:
			is_skidding = true
		
		# Brake squeal logic: braking while moving forward or throttle while moving back
		var forward_speed = global_basis.z.dot(linear_velocity)
		if (forward_speed > 2.0 and engine_input < -0.1) or (forward_speed < -2.0 and engine_input > 0.1):
			is_braking = true
	
	if skid_player and sfx_enabled:
		var target_skid_vol = -5 if is_skidding else -80
		skid_player.volume_db = lerp(skid_player.volume_db, float(target_skid_vol), 10.0 * delta)
	
	var brake_plr = get_meta("brake_player") as AudioStreamPlayer3D
	if brake_plr and sfx_enabled:
		var target_brake_vol = -10 if is_braking else -80
		brake_plr.volume_db = lerp(brake_plr.volume_db, float(target_brake_vol), 15.0 * delta)

	# Out of bounds check
	if global_position.y < -20.0:
		if gm:
			gm.reset_race()
		return

	engine_input = Input.get_axis("ui_down", "ui_up")
	steering_input = lerp(steering_input, Input.get_axis("ui_right", "ui_left"), steering_speed * delta)
	
	var on_ground = false
	
	for i in range(raycasts.size()):
		var ray = raycasts[i]
		var wheel = wheels[i]
		
		wheel.position.x = ray.position.x
		wheel.position.z = ray.position.z
		
		if ray.is_colliding():
			on_ground = true
			var collider = ray.get_collider()
			var hit_point = ray.get_collision_point()
			var hit_normal = ray.get_collision_normal()
			var dist = (ray.global_position - hit_point).length()
			
			# Block Detection
			if collider.has_method("get_script") and collider.get_script() and collider.get_script().get_path() == "res://scripts/track_block.gd":
				_check_track_block(collider)
			
			# 1. Suspension
			var compression = (suspension_rest_dist + wheel_radius) - dist
			if compression > 0:
				var wheel_velocity = linear_velocity + angular_velocity.cross(ray.global_position - global_position)
				var upward_vel = hit_normal.dot(wheel_velocity)
				var spring_force = compression * spring_strength
				var damping_force = upward_vel * spring_damping
				var total_force = (spring_force - damping_force) * hit_normal
				apply_force(total_force, ray.global_position - global_position)
				
				# 2. Driving
				var wheel_basis = ray.global_basis
				if i < 2:
					# Gradual speed-sensitive steering:
					# Full steering at low speeds, gradually reducing to 15% at high speeds (100 m/s)
					var speed_cur = linear_velocity.length()
					var steer_speed_factor = lerp(1.0, 0.15, clamp(speed_cur / 100.0, 0.0, 1.0))
					
					var effective_steer = steering_input * deg_to_rad(steering_angle) * steer_speed_factor
					wheel_basis = wheel_basis.rotated(global_basis.y, effective_steer)
				
				var forward_dir = wheel_basis.z
				var right_dir = wheel_basis.x
				
				# Only apply engine forces if the wheel is touching the ground
				if abs(engine_input) > 0.05:
					var accel_force = forward_dir * engine_input * engine_power
					apply_force(accel_force, ray.global_position - global_position)
				
				var lateral_vel = right_dir.dot(wheel_velocity)
				var grip_force = -right_dir * lateral_vel * grip * mass
				apply_force(grip_force, ray.global_position - global_position)
				
				wheel.global_position = hit_point + hit_normal * wheel_radius
				wheel.global_basis = wheel_basis.rotated(wheel_basis.z, PI/2.0)
			else:
				wheel.position.y = -suspension_rest_dist
		else:
			wheel.position.y = -suspension_rest_dist
			var wheel_basis = ray.global_basis
			if i < 2:
				wheel_basis = wheel_basis.rotated(global_basis.y, steering_input * deg_to_rad(steering_angle))
			wheel.global_basis = wheel_basis.rotated(wheel_basis.z, PI/2.0)

	if !on_ground:
		var air_torque = Vector3.ZERO
		# Air control now only handles pitch if the user wants separate keys
		# For now, we remove the throttle-based pitch as it was confusing
		apply_torque(global_basis * air_torque * mass)

func _check_track_block(block):
	var gm = get_node_or_null("/root/GameManager")
	# BlockType.START = 1, FINISH = 2, BOOSTER = 3
	match block.type:
		1: # START
			if gm: gm.start_race()
		2: # FINISH
			if gm: gm.finish_race()
		3: # BOOSTER
			apply_central_force(global_basis.z * booster_force)

func _on_body_entered(_body):
	var gm = get_node_or_null("/root/GameManager")
	# Play collision sound if we hit something at decent speed and SFX is enabled
	if linear_velocity.length() > 2.0 and collision_player and (not gm or gm.sfx_enabled):
		collision_player.play()
