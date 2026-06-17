extends Node

# ============================================================================
#  AudioManager.gd — Singleton de sunet (Autoload)
#  Generează toate sunetele PROCEDURAL, prin cod (AudioStreamGenerator), fără
#  fișiere audio externe. Fiecare sunet e o undă sinusoidală scrisă într-un
#  buffer și redată pe loc. Volumul global vine din bus-ul Master (setări).
# ============================================================================

const SAMPLE_RATE: float = 22050.0   # eșantioane pe secundă

# --- Sunete pozitive ---
func play_collect_perk() -> void: _beep(880.0, 0.12)                       # bip înalt scurt
func play_collect_life()  -> void: _chord([523.0, 659.0, 784.0], 0.22)     # acord vesel (Do-Mi-Sol)

# --- Sunete negative ---
func play_trap()          -> void: _sweep(300.0, 120.0, 0.30, -4.0)        # cădere de ton
func play_life_lost()     -> void: _sweep(440.0, 200.0, 0.35, -4.0)
func play_curse_start()   -> void: _chord([220.0, 233.0], 0.50, -3.0)      # acord disonant (sinistru)

# --- UI ---
func play_interact()      -> void: _beep(660.0, 0.06, -12.0)               # clic scurt

# --- Finaluri (mici melodii din 3 note) ---
func play_victory() -> void:
	_beep(523.0, 0.12)
	_later(func(): _beep(659.0, 0.12), 0.13)
	_later(func(): _beep(784.0, 0.28), 0.26)   # urcă = victorie

func play_game_over() -> void:
	_beep(330.0, 0.16, -4.0)
	_later(func(): _beep(277.0, 0.16, -4.0), 0.18)
	_later(func(): _beep(196.0, 0.35, -4.0), 0.36)   # coboară = înfrângere

# ── Funcții interne ─────────────────────────────────────────────────────────────

# Rulează o funcție după `delay` secunde (pentru note în succesiune)
func _later(fn: Callable, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(fn, CONNECT_ONE_SHOT)

# Un singur ton sinusoidal
func _beep(freq: float, dur: float, vol_db: float = -6.0) -> void:
	_play_buf(_gen_beep(freq, dur), dur, vol_db)

# Mai multe frecvențe simultan (acord)
func _chord(freqs: Array, dur: float, vol_db: float = -6.0) -> void:
	var frames := int(SAMPLE_RATE * dur)
	var buf    := PackedVector2Array()
	buf.resize(frames)
	var n: float = float(freqs.size())
	for i in frames:
		var t: float   = float(i) / SAMPLE_RATE
		var env: float = 1.0 - float(i) / float(frames)   # „envelope": scade volumul spre final
		var s: float   = 0.0
		for f: float in freqs:
			s += sin(TAU * f * t)
		buf[i] = Vector2(s / n * env * 0.4, s / n * env * 0.4)   # stereo (L, R)
	_play_buf(buf, dur, vol_db)

# Ton care alunecă de la o frecvență la alta (efect de „cădere")
func _sweep(f_start: float, f_end: float, dur: float, vol_db: float = -6.0) -> void:
	var frames := int(SAMPLE_RATE * dur)
	var buf    := PackedVector2Array()
	buf.resize(frames)
	for i in frames:
		var t: float   = float(i) / SAMPLE_RATE
		var env: float = 1.0 - float(i) / float(frames)
		var f: float   = lerp(f_start, f_end, float(i) / float(frames))
		var s: float   = sin(TAU * f * t) * env * 0.4
		buf[i] = Vector2(s, s)
	_play_buf(buf, dur, vol_db)

# Generează buffer-ul pentru un ton simplu
func _gen_beep(freq: float, dur: float) -> PackedVector2Array:
	var frames := int(SAMPLE_RATE * dur)
	var buf    := PackedVector2Array()
	buf.resize(frames)
	for i in frames:
		var t: float   = float(i) / SAMPLE_RATE
		var env: float = 1.0 - float(i) / float(frames)
		var s: float   = sin(TAU * freq * t) * env * 0.4
		buf[i] = Vector2(s, s)
	return buf

# Creează un player temporar, redă buffer-ul, apoi se autodistruge
func _play_buf(buf: PackedVector2Array, dur: float, vol_db: float) -> void:
	var player := AudioStreamPlayer.new()
	var gen    := AudioStreamGenerator.new()
	gen.mix_rate     = SAMPLE_RATE
	gen.buffer_length = dur + 0.1
	player.stream    = gen
	player.volume_db = vol_db
	add_child(player)
	player.play()

	var pb := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		player.queue_free()
		return

	pb.push_buffer(buf)
	# Curăță player-ul după ce sunetul s-a terminat
	get_tree().create_timer(dur + 0.15).timeout.connect(
		func(): if is_instance_valid(player): player.queue_free()
	)
