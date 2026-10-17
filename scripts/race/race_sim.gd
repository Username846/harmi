class_name RaceSim
extends RefCounted
## Pure pink-slip drag race simulation: the christmas tree, launch, a
## four-speed gearbox, nitrous and the rival driver. No nodes, so it runs
## headless in tests. Distances are metres, times seconds. Race times are
## measured from the green light, so reaction time counts.
## Car 0 (`hero`) is the player, car 1 (`foe`) the rival.

const TRACK := 402.0
const STEP := 1.0 / 120.0
const GEARS := 4
## Road speed (m/s) at the rev limiter in each gear.
const GEAR_TOP := [0.0, 20.0, 32.0, 44.0, 58.0]
## Torque multiplication of each gear.
const GEAR_PULL := [0.0, 1.0, 0.70, 0.52, 0.40]
const ACCEL := 12.5
const DRAG := 0.0005
const BRAKE := 7.0

## Christmas tree: ambers light this far apart, then green after a random wait.
const AMBER_GAP := 0.55
const GREEN_WAIT_MIN := 0.6
const GREEN_WAIT_MAX := 1.6
const FALSE_START_PENALTY := 1.0 ## launch this long after green when you jump it
const FROZE_AFTER := 2.5 ## auto-launch if the player never taps GO
const LIMITER_AUTO_SHIFT := 0.7 ## seconds on the limiter before the box shifts itself
const SHIFT_CUT := 0.09 ## power cut while the clutch is in
const NOS_TIME := 2.0
const NOS_MULT := 1.45

## Tachometer zones (rpm is 0..1 where 1 is the rev limiter).
const EARLY_BELOW := 0.74
const PERFECT_LO := 0.79
const PERFECT_HI := 0.89
const LATE_ABOVE := 0.92
const REDLINE := 0.985

## Engine power per piece type (index = piece type). Pawn weakest, queen strongest.
const POWER := [1.0, 0.97, 0.99, 0.985, 1.0, 1.025, 1.0]
## Shift quality -> [acceleration multiplier, seconds it lasts].
const SHIFT_FX := {
	"perfect": [1.45, 1.0], "good": [1.10, 0.5], "early": [0.72, 0.9],
	"late": [0.78, 0.6], "redline": [0.55, 0.9],
}

## Rival driver by difficulty (easy, normal, hard).
const AI_REACT := [0.40, 0.30, 0.22]
const AI_REACT_JITTER := [0.09, 0.06, 0.035]
const AI_SHIFT_SIGMA := [0.09, 0.07, 0.04]
const AI_FALSE_START := [0.05, 0.03, 0.015]
const AI_POWER := [0.96, 0.995, 1.015]


class Car:
	extends RefCounted
	var type := 1
	var power := 1.0
	var pos := 0.0 ## front bumper, metres past the start line
	var speed := 0.0
	var accel := 0.0
	var gear := 1
	var rpm := 0.0
	var launched := false
	var launch_at := -1.0 ## race time when the car may leave (-1 = not yet)
	var reaction := -1.0
	var false_start := false
	var stalled := false
	var mod := 1.0
	var mod_left := 0.0
	var cut_left := 0.0
	var nos_left := 0.0
	var nos_used := false
	var has_nos := false
	var on_limiter := 0.0
	var finish := -1.0 ## race time at the line (-1 = still racing)
	var shifts: Array[String] = []
	var shift_targets: Array[float] = [] ## rival only: rpm it shifts at, per gear

	func done() -> bool:
		return finish >= 0.0


var hero := Car.new()
var foe := Car.new()
var cars: Array[Car] = []
var rng := RandomNumberGenerator.new()
var difficulty := 1
var gloom := 0.0 ## rival's gloominess 0..1 (from mood)
var clock := 0.0 ## seconds since the first amber
var idle_t := 0.0
var tree_on := false
var green_at := 0.0
var events: Array[Dictionary] = []
var _acc := 0.0
var _foe_fs_clock := -1.0


func _init(hero_type: int = 2, foe_type: int = 4, hero_mood: float = 72.0, foe_mood: float = 72.0,
		diff: int = 1, hero_has_nos: bool = false, seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	difficulty = clampi(diff, 0, 2)
	cars = [hero, foe]
	hero.type = hero_type
	foe.type = foe_type
	hero.has_nos = hero_has_nos
	# A happy driver squeezes out a little more power (+-6 %).
	hero.power = power_of(hero_type) * (1.0 + 0.06 * clampf((hero_mood - 50.0) / 50.0, -1.0, 1.0))
	foe.power = power_of(foe_type) * AI_POWER[difficulty]
	green_at = AMBER_GAP * 2.0 + rng.randf_range(GREEN_WAIT_MIN, GREEN_WAIT_MAX)
	_plan_rival(foe_mood)


static func power_of(t: int) -> float:
	return POWER[clampi(t, 0, POWER.size() - 1)]


## Gloomy rivals react late, jump the light more and shift sloppily.
func _plan_rival(mood: float) -> void:
	var d := difficulty
	gloom = clampf((60.0 - mood) / 50.0, 0.0, 1.0)
	var elation := clampf((mood - 75.0) / 25.0, 0.0, 1.0)
	if rng.randf() < AI_FALSE_START[d] + gloom * 0.07:
		foe.false_start = true
		foe.launch_at = FALSE_START_PENALTY + rng.randf_range(0.0, 0.15)
		_foe_fs_clock = green_at - rng.randf_range(0.08, 0.4)
	else:
		var r: float = AI_REACT[d] + gloom * 0.16 - elation * 0.02 + rng.randfn(0.0, AI_REACT_JITTER[d])
		foe.launch_at = maxf(0.12, r)
		foe.reaction = foe.launch_at
	var mean := 0.84 - gloom * 0.05
	var sigma: float = AI_SHIFT_SIGMA[d] * (1.0 + gloom) * (1.0 - elation * 0.2)
	for i in GEARS - 1:
		foe.shift_targets.append(clampf(rng.randfn(mean, sigma), 0.55, 1.0))


# --- tree --------------------------------------------------------------------

func start_tree() -> void:
	tree_on = true
	clock = 0.0
	events.append({"t": "amber", "n": 1})


func race_time() -> float:
	return clock - green_at


## How many amber lights are lit (0-3); they go dark when green shows.
func ambers() -> int:
	if not tree_on or is_green():
		return 0
	return clampi(int(floor(clock / AMBER_GAP)) + 1, 0, 3)


func is_green() -> bool:
	return tree_on and clock >= green_at


func finished() -> bool:
	return hero.done() and foe.done()


func decided() -> bool:
	return hero.done() or foe.done()


func hero_won() -> bool:
	if hero.done() and foe.done():
		return hero.finish <= foe.finish
	return hero.done()


func pop_events() -> Array[Dictionary]:
	var out := events
	events = []
	return out


# --- player input ------------------------------------------------------------

## Returns "launch", "false_start" or "" (ignored).
func press_go() -> String:
	if not tree_on or hero.launch_at >= 0.0:
		return ""
	var rt := race_time()
	if rt < 0.0:
		hero.false_start = true
		hero.stalled = true
		hero.launch_at = FALSE_START_PENALTY
		events.append({"t": "false_start", "who": 0})
		return "false_start"
	hero.launch_at = rt
	hero.reaction = rt
	return "launch"


## Returns the shift quality ("perfect", "good", "early", "late", "redline") or "".
func press_shift() -> String:
	if not hero.launched or hero.done() or hero.gear >= GEARS:
		return ""
	return _shift(hero, 0, false)


func can_nos() -> bool:
	return hero.has_nos and not hero.nos_used and hero.launched and not hero.done()


func press_nos() -> bool:
	if not can_nos():
		return false
	hero.nos_used = true
	hero.nos_left = NOS_TIME
	events.append({"t": "nos", "who": 0})
	return true


static func shift_quality(r: float) -> String:
	if r < EARLY_BELOW:
		return "early"
	if r < PERFECT_LO:
		return "good"
	if r <= PERFECT_HI:
		return "perfect"
	if r <= LATE_ABOVE:
		return "good"
	if r < REDLINE:
		return "late"
	return "redline"


## Engine torque curve: pulls hardest around 72 % of the limiter.
static func torque(r: float) -> float:
	if r < 0.72:
		return 0.68 + 0.32 * maxf(r, 0.0) / 0.72
	var k := r - 0.72
	return 1.0 - 3.0 * k * k


func _shift(c: Car, who: int, forced: bool) -> String:
	var q := "redline" if forced else shift_quality(c.rpm)
	var fx: Array = SHIFT_FX[q]
	c.gear += 1
	c.mod = fx[0]
	c.mod_left = fx[1]
	c.cut_left = SHIFT_CUT
	c.on_limiter = 0.0
	c.shifts.append(q)
	c.rpm = c.speed / float(GEAR_TOP[c.gear])
	events.append({"t": "shift", "who": who, "q": q, "gear": c.gear})
	return q


# --- simulation --------------------------------------------------------------

func step(dt: float) -> void:
	_acc += minf(dt, 0.25)
	while _acc >= STEP:
		_acc -= STEP
		_tick(STEP)


## Runs to the end with no further input (auto-shifts on the limiter).
func run_to_end(limit: float = 60.0) -> void:
	if not tree_on:
		start_tree()
	while not finished() and race_time() < limit:
		_tick(STEP)


func _tick(dt: float) -> void:
	idle_t += dt
	if not tree_on:
		for c in cars:
			c.rpm = 0.2 + 0.03 * sin(idle_t * 9.0 + c.type)
		return
	var prev := clock
	clock += dt
	for i in range(1, 3):
		var at := AMBER_GAP * i
		if prev < at and clock >= at:
			events.append({"t": "amber", "n": i + 1})
	if prev < green_at and clock >= green_at:
		events.append({"t": "green"})
	if foe.false_start and _foe_fs_clock >= 0.0 and clock >= _foe_fs_clock:
		_foe_fs_clock = -1.0
		foe.stalled = true
		events.append({"t": "false_start", "who": 1})
	var rt := race_time()
	if rt >= FROZE_AFTER and hero.launch_at < 0.0:
		hero.launch_at = rt
		hero.reaction = rt
		events.append({"t": "froze", "who": 0})
	for i in 2:
		_drive(cars[i], i, rt, dt)


func _drive(c: Car, who: int, rt: float, dt: float) -> void:
	if not c.launched:
		if c.launch_at >= 0.0 and rt >= c.launch_at:
			c.launched = true
			c.stalled = false
			events.append({"t": "launch", "who": who})
		else:
			var target := 0.0 if c.stalled else 0.42 + 0.06 * sin(idle_t * 21.0 + who * 2.0)
			c.rpm = move_toward(c.rpm, target, dt * (3.0 if c.stalled else 1.5))
			return
	if c.done():
		c.accel = -BRAKE if c.speed > 0.0 else 0.0
		c.speed = maxf(0.0, c.speed - BRAKE * dt)
		c.pos += c.speed * dt
		c.rpm = move_toward(c.rpm, 0.25, dt * 0.6)
		return
	var top: float = GEAR_TOP[c.gear]
	var a := 0.0
	var boost := 1.0
	if c.nos_left > 0.0:
		boost = NOS_MULT
		c.nos_left -= dt
		if c.nos_left <= 0.0:
			events.append({"t": "nos_end", "who": who})
	if c.cut_left > 0.0:
		c.cut_left -= dt
	else:
		a = ACCEL * c.power * float(GEAR_PULL[c.gear]) * torque(c.speed / top) * boost
		if c.mod_left > 0.0:
			a *= c.mod
			c.mod_left -= dt
	a -= DRAG * c.speed * c.speed
	var v := c.speed + a * dt
	if v >= top:
		v = top
		if c.on_limiter == 0.0:
			events.append({"t": "limiter", "who": who})
		c.on_limiter += dt
	else:
		c.on_limiter = 0.0
	v = maxf(v, 0.0)
	c.accel = (v - c.speed) / dt
	c.speed = v
	var old := c.pos
	c.pos += c.speed * dt
	c.rpm = c.speed / top
	if who == 1 and c.gear < GEARS and c.rpm >= c.shift_targets[c.gear - 1]:
		_shift(c, who, false)
	elif c.gear < GEARS and c.on_limiter >= LIMITER_AUTO_SHIFT:
		_shift(c, who, true)
	if c.pos >= TRACK:
		var frac := (TRACK - old) / maxf(c.pos - old, 0.0001)
		c.finish = rt - dt + frac * dt
		events.append({"t": "finish", "who": who, "time": c.finish})
