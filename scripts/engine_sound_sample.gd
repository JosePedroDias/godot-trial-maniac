extends Node3D

var rpm_raw: float = 0.0
var throttle: float = 0.0

var low_player: AudioStreamPlayer3D
var mid_player: AudioStreamPlayer3D
var high_player: AudioStreamPlayer3D

func _ready():
	low_player = _setup_player("res://assets/sfx/engine_low.wav")
	mid_player = _setup_player("res://assets/sfx/engine_mid.wav")
	high_player = _setup_player("res://assets/sfx/engine_high.wav")

func _setup_player(path: String) -> AudioStreamPlayer3D:
	var p = AudioStreamPlayer3D.new()
	var stream = _load_wav_runtime(path)
	if stream:
		p.stream = stream
		p.unit_size = 30.0
		p.autoplay = true
		add_child(p)
		p.play()
	return p

# Manual WAV loader for runtime files without .import
func _load_wav_runtime(path: String) -> AudioStreamWAV:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("Failed to open audio file: ", path)
		return null
	
	var bytes = file.get_buffer(file.get_length())
	
	# Basic WAV parsing (PCM 16-bit mono 44100Hz)
	# We expect standard ffmpeg output format from our clean step
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	
	# Skip the header (44 bytes for a standard simple WAV)
	# For better robustness we could look for 'data' chunk but usually 44 works for Lavf
	var data_start = 44
	# Find 'data' chunk just in case
	for i in range(0, 100):
		if i + 4 < bytes.size():
			if bytes[i] == 100 and bytes[i+1] == 97 and bytes[i+2] == 116 and bytes[i+3] == 97: # 'data'
				data_start = i + 8
				break
				
	stream.data = bytes.slice(data_start)
	stream.loop_end = stream.data.size() / 2 # samples
	return stream

func set_enabled(enabled: bool):
	for p in [low_player, mid_player, high_player]:
		if p: p.stream_paused = !enabled

func _process(delta):
	# RPM range 3000 - 12000
	var rpm_norm = clamp((rpm_raw - 3000.0) / 9000.0, 0.0, 1.0)
	
	# Pitch calculation
	var pitch = 0.5 + rpm_norm * 1.5
	if low_player: low_player.pitch_scale = pitch
	if mid_player: mid_player.pitch_scale = pitch
	if high_player: high_player.pitch_scale = pitch
	
	# Cross-fading volumes
	var vol_low = clamp(1.0 - rpm_norm * 2.0, 0.0, 1.0)
	var vol_mid = 1.0 - abs(rpm_norm - 0.5) * 2.0
	var vol_high = clamp((rpm_norm - 0.5) * 2.0, 0.0, 1.0)
	
	var throttle_mod = 1.0 + throttle * 0.5
	
	if low_player: low_player.volume_db = linear_to_db(vol_low * throttle_mod)
	if mid_player: mid_player.volume_db = linear_to_db(vol_mid * throttle_mod)
	if high_player: high_player.volume_db = linear_to_db(vol_high * throttle_mod)

func linear_to_db(linear: float) -> float:
	if linear < 0.0001: return -80.0
	return 20.0 * log(linear) / log(10.0)
