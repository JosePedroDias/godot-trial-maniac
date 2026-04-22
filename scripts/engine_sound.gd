extends AudioStreamPlayer3D

var playback: AudioStreamGeneratorPlayback
var sample_rate: float
var phase: float = 0.0

var rpm: float = 0.0 # 0.0 to 1.0
var throttle: float = 0.0

func _ready():
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 44100
	generator.buffer_length = 0.1
	stream = generator
	sample_rate = generator.mix_rate
	play()

func _process(_delta):
	if not playback:
		playback = get_stream_playback()
	
	if playback:
		_fill_buffer()

func _fill_buffer():
	var frames_available = playback.get_frames_available()
	if frames_available == 0:
		return
		
	# Base frequency for idle is around 40Hz
	# Max frequency around 200Hz
	var base_freq = lerp(40.0, 200.0, rpm)
	
	for i in range(frames_available):
		var increment = base_freq / sample_rate
		phase = fmod(phase + increment, 1.0)
		
		# Base + harmonics
		var s = sin(phase * TAU)
		s += 0.5 * sin(fmod(phase * 2.0, 1.0) * TAU)
		s += 0.25 * sin(fmod(phase * 3.0, 1.0) * TAU)
		s += 0.125 * sin(fmod(phase * 4.0, 1.0) * TAU)
		
		# Modulation: add some noise
		var noise = (randf() - 0.5) * 0.1
		s += noise
		
		# Soft clipping (Cubic distortion)
		# Increase amplitude before clipping to get more "bite"
		s = s * (1.2 + throttle * 0.8)
		s = clamp(s, -1.5, 1.5)
		s = s - (s * s * s / 3.0)
		
		# Final volume: significantly higher than before
		# AudioStreamPlayer3D handles spatialization, we just need a strong signal
		var volume = 0.4 + throttle * 0.3
		var sample = Vector2(s, s) * volume
		playback.push_frame(sample)
