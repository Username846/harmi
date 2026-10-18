extends Node
## Background music, Beyblade style. Registered as the "Music" autoload.
## The bassline (a battle top launched down an oak staircase) only plays while
## the Beyblade volume control is spinning. Pulling the rip cord harder makes it
## louder and keeps it spinning longer before it wobbles and dies down. Pull too
## hard and the whole thing snaps off and crashes into the chessboard.

signal changed
signal snapped(from_global: Vector2)

const BREAK_AT := 0.92
const LOOP_STREAM := preload("res://assets/audio/beyblade_stairs.wav")
const RIP_STREAM := preload("res://assets/audio/ripcord.wav")
const CRASH_STREAM := preload("res://assets/audio/crash.wav")

var player: AudioStreamPlayer
var sfx: AudioStreamPlayer
var power := 0.0
var duration := 0.0
var elapsed := 0.0
var spinning := false
var broken := false
var pending_crash := false # a snapped Beyblade waiting to land on the board
var crash_from := Vector2.ZERO
var angle := 0.0 # shared spin angle so every widget turns in step
var _apply_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.stream = LOOP_STREAM
	add_child(player)
	sfx = AudioStreamPlayer.new()
	sfx.volume_db = -3.0
	add_child(sfx)


## How much spin is left, 0..1: drives the volume and how fast widgets turn.
func energy() -> float:
	if not spinning:
		return 0.0
	return (0.3 + 0.7 * power) * _envelope()


## 0 while spinning true, rising to 1 as the top wobbles to a stop.
func wobble() -> float:
	if not spinning:
		return 0.0
	return clampf(1.0 - _left() / 0.3, 0.0, 1.0)


func seconds_left() -> float:
	return maxf(0.0, duration - elapsed) if spinning else 0.0


static func duration_for(p: float) -> float:
	return 20.0 + 160.0 * clampf(p, 0.0, 1.0)


func _left() -> float:
	return 1.0 - elapsed / maxf(duration, 0.01)


func _envelope() -> float:
	var l := _left()
	return 1.0 if l > 0.3 else maxf(l, 0.0) / 0.3


## Pull the rip cord with strength p (0..1).
func launch(p: float, from_global: Vector2) -> void:
	if broken:
		return
	_sfx(RIP_STREAM)
	if p >= BREAK_AT:
		broken = true
		spinning = false
		player.stop()
		crash_from = from_global
		pending_crash = true
		changed.emit()
		snapped.emit(from_global)
		return
	power = clampf(p, 0.05, 1.0)
	duration = duration_for(power)
	elapsed = 0.0
	spinning = true
	_apply()
	if not player.playing:
		player.play()
	changed.emit()


## Stop the top with your hand.
func catch_top() -> void:
	spinning = false
	player.stop()
	changed.emit()


func repair() -> void:
	broken = false
	pending_crash = false
	changed.emit()


func play_crash() -> void:
	_sfx(CRASH_STREAM)


func play_sfx(stream: AudioStream) -> void:
	_sfx(stream)


func _sfx(stream: AudioStream) -> void:
	sfx.stream = stream
	sfx.play()


func _process(delta: float) -> void:
	angle = fmod(angle + delta * (1.5 + 30.0 * energy()), TAU * 1000.0)
	if not spinning:
		return
	elapsed += delta
	if elapsed >= duration:
		spinning = false
		player.stop()
		changed.emit()
		return
	_apply_timer -= delta
	if _apply_timer <= 0.0:
		_apply()


func _apply() -> void:
	_apply_timer = 0.1
	player.volume_db = linear_to_db(maxf(energy(), 0.002)) - 2.0
	# a dying top slows down, and so does the music
	player.pitch_scale = lerpf(1.0, 0.8, wobble())
