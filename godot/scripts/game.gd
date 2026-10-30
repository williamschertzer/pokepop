class_name Game
extends RefCounted
## The game simulation: balls moving down the route, Pokémon attacking, waves,
## money and lives. Ported from the web version so it plays the same.

signal toast(msg: String)
signal sfx(freq: float, dur: float, type: String, vol: float)
signal ended(win: bool)
signal info_changed
signal money_bump
signal wave_cleared

const W := Data.W
const H := Data.H
const BALLS := Data.BALLS


class Ball:
	var id: int
	var type: String
	var def: Dictionary
	var d := 0.0
	var hp := 1.0
	var max_hp := 1.0
	var sleep := 0.0
	var sleep_cd := 0.0
	var burn = null
	var seed = null
	var wet := 0.0
	var revealed := false
	var slow := 1.0
	var wob := 0.0
	var x := 0.0
	var y := 0.0
	var dead := false


class Tower:
	var id: int
	var kind: String
	var x: float
	var y: float
	var a := 0
	var b := 0
	var cd := 0.2
	var mode := "first"
	var pops := 0
	var spent := 0
	var face := 1
	var shots := 0
	var timers := {}
	var born := 0.0
	var s: Dictionary
	var conf := 0.0


var map = null
var path: Dictionary
var obs: Array = []
var deco: Array = []
var bg: Array = []
var start_pt := Vector2.ZERO
var end_pt := Vector2.ZERO
var money := 0
var lives := 0
var wave := 0
var running := false
var q: Array = []
var qt := 0.0
var balls: Array = []
var towers: Array = []
var proj: Array = []
var fx: Array = []
var parts: Array = []
var coins: Array = []
var marks: Array = []
var alarm := 0.0
var speed := 1
var paused := false
var auto := false
var over := false
var won := false
var freeplay := false
var t := 0.0
var next_id := 1
var auto_timer := 0.0
var shake := 0.0
var best := {}


# ---------- setup ----------
func setup_map(m: Dictionary) -> void:
	map = m
	path = MapArt.build_path(m.path)
	var o := MapArt.gen_obstacles(m, path)
	obs = o.obs
	deco = o.deco
	bg = MapArt.render_bg(m, path, obs, deco)
	var d: float = path.total
	while d > 0:
		var p := MapArt.pos_at(path, d)
		if p.x > 50 and p.x < W - 50 and p.y > 50 and p.y < H - 50:
			break
		d -= 4
	end_pt = MapArt.pos_at(path, d)
	var d0 := 0.0
	while d0 < path.total:
		var p := MapArt.pos_at(path, d0)
		if p.x > 36 and p.x < W - 36 and p.y > 36 and p.y < H - 40:
			break
		d0 += 4
	start_pt = MapArt.pos_at(path, d0)


func new_game(m: Dictionary) -> void:
	setup_map(m)
	coins = []; marks = []; alarm = 0.0; money = m.cash; lives = m.lives; wave = 0; running = false
	q = []; qt = 0.0; balls = []; towers = []; proj = []; fx = []; parts = []
	over = false; won = false; freeplay = false; paused = false; auto_timer = 0.0
	toast.emit("%s. Place a Pokémon, then start wave 1." % m.name)


# ---------- balls ----------
func spawn_ball(type: String, d: float) -> Ball:
	var def: Dictionary = BALLS[type]
	var hp: float
	if type == "rocket":
		hp = Data.rocket_hp(wave)
	elif type == "master":
		hp = Data.master_hp(wave)
	else:
		hp = def.hp * (2 if wave > 40 and type == "heavy" else 1)
	var b := Ball.new()
	b.id = next_id; next_id += 1
	b.type = type; b.def = def; b.d = maxf(0, d); b.hp = hp; b.max_hp = hp
	b.wob = randf() * TAU
	var p := MapArt.pos_at(path, b.d)
	b.x = p.x; b.y = p.y
	balls.append(b)
	return b


var _last_pop_sound := 0


func damage(b: Ball, amt: float, src: Tower) -> void:
	if b.dead or amt <= 0:
		return
	b.hp -= amt
	if b.hp <= 0:
		pop_ball(b, src, -b.hp)


func pop_ball(b: Ball, src: Tower, over_dmg: float) -> void:
	b.dead = true
	money += 1 + (1 if src and src.s.dream else 0) + (3 if src and src.s.thief else 0)
	if src:
		src.pops += 1
	var def := b.def
	var boss: bool = def.get("boss", false)
	for i in (18 if boss else 6):
		var a := randf() * TAU
		var v := 40 + randf() * 90
		parts.append({"x": b.x, "y": b.y, "vx": cos(a) * v, "vy": sin(a) * v, "life": .35, "max": .35, "col": Color.WHITE if i % 2 else Color(def.top), "size": 3.0 if boss else 2.0})
	if boss:
		fx.append({"kind": "ring", "x": b.x, "y": b.y, "r": 10, "to": 70, "life": .5, "max": .5, "col": Color("#e85aa8")})
		shake = 8
	var now := Time.get_ticks_msec()
	if now - _last_pop_sound > 45:
		_last_pop_sound = now
		sfx.emit(520 + def.tier * 90 + randf() * 80, .05, "triangle", .03)
	var kids: Array = def.kids
	for i in kids.size():
		var c := spawn_ball(kids[i], b.d - i * 8)
		if b.burn:
			c.burn = b.burn.duplicate()
		if over_dmg > 0 and i == 0:
			damage(c, over_dmg, src)


func visible(b: Ball, detect: bool) -> bool:
	return not b.dead and (not b.def.get("hidden", false) or detect or b.revealed)


func in_range(x: float, y: float, r: float, detect: bool, filter = null) -> Array:
	var out: Array = []
	for b in balls:
		if not visible(b, detect):
			continue
		if filter and not filter.call(b):
			continue
		var br: float = b.def.r
		if (b.x - x) ** 2 + (b.y - y) ** 2 <= (r + br * .5) ** 2:
			out.append(b)
	return out


func _score(tw: Tower, b: Ball) -> float:
	match tw.mode:
		"last": return -b.d
		"strong": return b.def.tier * 1e5 + b.d
		"close": return -((b.x - tw.x) ** 2 + (b.y - tw.y) ** 2)
	return b.d


func pick_target(tw: Tower, filter = null) -> Ball:
	var c := in_range(tw.x, tw.y, tw.s.range, tw.s.detect, filter)
	if c.is_empty():
		return null
	var best_b: Ball = c[0]
	var score := -INF
	for b in c:
		var s := _score(tw, b)
		if s > score:
			score = s
			best_b = b
	return best_b


func pick_targets(tw: Tower, n: int, filter = null) -> Array:
	var c := in_range(tw.x, tw.y, tw.s.range, tw.s.detect, filter)
	c = Data.stable_sort(c, func(a, b): return _score(tw, a) > _score(tw, b))
	return c.slice(0, n)


func push_back(b: Ball, px: float) -> void:
	b.d = maxf(0, b.d - (px * .2 if b.def.get("boss", false) else px))


func pay_day(tw: Tower, amt: int) -> void:
	var n := mini(14, 4 + int(round(amt / 20.0)))
	for i in n:
		var a := -PI / 2 + (randf() - .5) * 1.6
		var v := 170 + randf() * 130
		coins.append({"x": tw.x, "y": tw.y - 6, "vx": cos(a) * v * .6, "vy": sin(a) * v, "floor": tw.y + 14 + randf() * 8, "life": 1.4 + randf() * .5, "ph": randf() * 6})
	fx.append({"kind": "text", "x": tw.x, "y": tw.y - 36, "text": "Pay Day +₽%d" % amt, "col": Color("#ffd23f"), "life": 1.6, "max": 1.6, "big": true})
	money_bump.emit()
	for i in 3:
		_delayed_sfx([988, 1319, 1568][i], .09, "square", .025, i * .07)


func _delayed_sfx(f: float, d: float, type: String, v: float, delay: float) -> void:
	if delay <= 0:
		sfx.emit(f, d, type, v)
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		tree.create_timer(delay).timeout.connect(func(): sfx.emit(f, d, type, v))


# ---------- towers ----------
func can_place(_kind: String, x: float, y: float) -> bool:
	if x < 16 or x > W - 16 or y < 16 or y > H - 16:
		return false
	if MapArt.dist_to_path(path, x, y) < 36:
		return false
	for o in obs:
		if Vector2(o.x - x, o.y - y).length() < o.r + 12:
			return false
	for tw in towers:
		if Vector2(tw.x - x, tw.y - y).length() < 32:
			return false
	return true


func place_tower(kind: String, x: float, y: float) -> Tower:
	var d: Dictionary = Data.TOWERS[kind]
	if money < d.cost or not can_place(kind, x, y):
		return null
	money -= d.cost
	var tw := Tower.new()
	tw.id = next_id; next_id += 1
	tw.kind = kind; tw.x = x; tw.y = y; tw.spent = d.cost; tw.born = t
	tw.s = Data.compute_stats(kind, 0, 0)
	towers.append(tw)
	for i in 12:
		var a := i / 12.0 * TAU
		parts.append({"x": x, "y": y + 8, "vx": cos(a) * 60, "vy": sin(a) * 30, "life": .4, "max": .4, "col": Color.WHITE, "size": 2.0})
	sfx.emit(660, .08, "square", .03)
	return tw


## Returns whether the upgrade on path "a" or "b" can be bought at all (ignoring money).
func upgrade_state(tw: Tower, p: String) -> String:
	var tier: int = tw.a if p == "a" else tw.b
	var other: int = tw.b if p == "a" else tw.a
	if tier >= 3:
		return "max"
	if tier >= 2 and other >= 3:
		return "locked"
	return "open"


func upgrade(tw: Tower, p: String) -> void:
	var d: Dictionary = Data.TOWERS[tw.kind]
	var list: Array = d.A if p == "a" else d.B
	if upgrade_state(tw, p) != "open":
		return
	var tier: int = tw.a if p == "a" else tw.b
	var u: Dictionary = list[tier]
	if money < u.cost:
		return
	money -= u.cost
	tw.spent += u.cost
	var before: String = Art.SPRITE_INFO[Data.sprite_for(tw.kind, tw.a)].name
	if p == "a":
		tw.a += 1
	else:
		tw.b += 1
	tw.s = Data.compute_stats(tw.kind, tw.a, tw.b)
	fx.append({"kind": "ring", "x": tw.x, "y": tw.y, "r": 6, "to": 40, "life": .5, "max": .5, "col": Color("#ffd23f")})
	for i in 16:
		var a := randf() * TAU
		parts.append({"x": tw.x, "y": tw.y, "vx": cos(a) * 80, "vy": sin(a) * 80 - 40, "life": .6, "max": .6, "col": Color("#ffd23f") if i % 2 else Color.WHITE, "size": 2.4})
	_delayed_sfx(440, .08, "square", .035, 0)
	_delayed_sfx(660, .08, "square", .035, .08)
	_delayed_sfx(880, .12, "square", .035, .16)
	var after: String = Art.SPRITE_INFO[Data.sprite_for(tw.kind, tw.a)].name
	if before != after:
		toast.emit("%s evolved into %s!" % [before, after])
	else:
		toast.emit("%s learned %s!" % [after, u.name.replace("Evolve: ", "")])
	info_changed.emit()


func sell_value(tw: Tower) -> int:
	return int(floor(tw.spent * .7))


func sell(tw: Tower) -> void:
	money += sell_value(tw)
	towers.erase(tw)
	sfx.emit(300, .1, "triangle", .03)
	info_changed.emit()


func zap(tw: Tower, list: Array, col: Color) -> void:
	var pts := [Vector2(tw.x, tw.y - 10)]
	for b in list:
		pts.append(Vector2(b.x, b.y))
	fx.append({"kind": "bolt", "pts": pts, "life": .12, "max": .12, "col": col, "w": 2.2})


func _timer(tw: Tower, key: String, init: float, dt: float) -> bool:
	tw.timers[key] = tw.timers.get(key, init) - dt
	return tw.timers[key] <= 0


func update_tower(tw: Tower, dt: float) -> void:
	var s := tw.s
	tw.cd -= dt
	match tw.kind:
		"pikachu":
			if s.gmax and _timer(tw, "g", 3, dt):
				var vic := balls.filter(func(b): return not b.dead and not b.def.get("armored", false))
				if vic.size():
					tw.timers.g = s.gmax
					fx.append({"kind": "flash", "life": .25, "max": .25, "col": Color(1, 246 / 255.0, 170 / 255.0)})
					for b in vic.slice(0, 40):
						fx.append({"kind": "bolt", "pts": [Vector2(b.x + (randf() - .5) * 30, -10), Vector2(b.x, b.y)], "life": .2, "max": .2, "col": Color("#fff6a8"), "w": 2.6})
					for b in vic:
						damage(b, 3, tw)
					sfx.emit(120, .35, "sawtooth", .05)
				else:
					tw.timers.g = .3
			if tw.cd > 0:
				return
			var thunder: bool = s.thunder and tw.shots % 3 == 2
			var tgt := pick_target(tw, null if thunder else func(b): return not b.def.get("armored", false))
			if not tgt:
				return
			tw.cd = s.rate; tw.shots += 1; tw.face = -1 if tgt.x < tw.x else 1
			if thunder:
				fx.append({"kind": "bolt", "pts": [Vector2(tgt.x + 8, -10), Vector2(tgt.x - 6, tgt.y - 80), Vector2(tgt.x + 4, tgt.y - 40), Vector2(tgt.x, tgt.y)], "life": .22, "max": .22, "col": Color("#fff6a8"), "w": 4.5})
				fx.append({"kind": "ring", "x": tgt.x, "y": tgt.y, "r": 8, "to": 55, "life": .3, "max": .3, "col": Color("#fff38a")})
				for b in in_range(tgt.x, tgt.y, 55, true):
					damage(b, 8, tw)
				sfx.emit(90, .25, "sawtooth", .05)
				return
			var hit := [tgt]
			var cur := tgt
			for i in range(1, s.chain):
				var nb: Ball = null
				var nd := 80.0 * 80.0
				for b in balls:
					if not visible(b, s.detect) or hit.has(b) or b.def.get("armored", false):
						continue
					var dd = (b.x - cur.x) ** 2 + (b.y - cur.y) ** 2
					if dd < nd:
						nd = dd
						nb = b
				if not nb:
					break
				hit.append(nb)
				cur = nb
			zap(tw, hit, Color("#fff38a"))
			for b in hit:
				damage(b, s.dmg, tw)
			sfx.emit(1200 + randf() * 200, .03, "square", .012)
		"charmander":
			var blue := tw.a >= 3
			if s.blast and _timer(tw, "bb", 2, dt):
				var v := in_range(tw.x, tw.y, 150, s.detect)
				if v.size():
					tw.timers.bb = s.blast
					fx.append({"kind": "ring", "x": tw.x, "y": tw.y, "r": 20, "to": 150, "life": .45, "max": .45, "col": Color("#5cc8ff") if blue else Color("#ff8a1f"), "w": 10})
					for b in v:
						damage(b, 10, tw)
					shake = 5
					sfx.emit(70, .4, "sawtooth", .06)
				else:
					tw.timers.bb = .25
			if tw.cd > 0:
				return
			var tgt := pick_target(tw)
			if not tgt:
				return
			tw.cd = s.rate; tw.face = -1 if tgt.x < tw.x else 1
			var ang := atan2(tgt.y - tw.y, tgt.x - tw.x)
			var cand := in_range(tw.x, tw.y, s.range, s.detect).filter(func(b):
				var da := atan2(b.y - tw.y, b.x - tw.x) - ang
				da = atan2(sin(da), cos(da))
				return absf(da) <= s.cone or b == tgt)
			cand = Data.stable_sort(cand, func(a, b): return ((a.x - tw.x) ** 2 + (a.y - tw.y) ** 2) < ((b.x - tw.x) ** 2 + (b.y - tw.y) ** 2))
			var hits := cand.slice(0, s.pierce)
			if not hits.has(tgt):
				hits.pop_back()
				hits.append(tgt)
			for b in hits:
				if s.burn:
					b.burn = {"left": s.burn, "every": .75, "timer": .75, "dmg": s.burnMul, "src": tw}
				damage(b, s.dmg, tw)
			for i in 16:
				var a = ang + (randf() - .5) * 2 * s.cone
				var v: float = s.range * (1.6 + randf() * 1.4)
				var col: Color
				if blue:
					col = Color("#5cc8ff") if i % 2 else Color("#d8f3ff")
				else:
					col = Color("#ff8a1f") if i % 3 else Color("#ffd23f")
				parts.append({"x": tw.x + cos(ang) * 12, "y": tw.y - 4 + sin(ang) * 12, "vx": cos(a) * v, "vy": sin(a) * v, "life": .32, "max": .32, "col": col, "size": 3.4, "grow": true})
			sfx.emit(180 + randf() * 60, .08, "sawtooth", .012)
		"gastly":
			if s.nightmare and _timer(tw, "n", .5, dt):
				tw.timers.n = .5
				for b in in_range(tw.x, tw.y, s.range, true, func(b): return b.sleep > 0):
					damage(b, 2, tw)
					parts.append({"x": b.x, "y": b.y - 10, "vx": 0.0, "vy": -30.0, "life": .4, "max": .4, "col": Color("#c79bff"), "size": 2.4})
			if tw.cd > 0:
				return
			var tgt := pick_target(tw)
			if not tgt:
				return
			tw.cd = s.rate; tw.face = -1 if tgt.x < tw.x else 1
			proj.append({"kind": "shadow", "x": tw.x + tw.face * 8, "y": tw.y, "tgt": tgt, "tx": tgt.x, "ty": tgt.y, "src": tw, "spd": s.pspeed, "life": 1.6, "big": tw.a >= 2})
			sfx.emit(240, .1, "sine", .03)
		"squirtle":
			if s.hydro and _timer(tw, "h", 2, dt):
				var v := in_range(tw.x, tw.y, s.range, s.detect)
				if v.size():
					tw.timers.h = s.hydro
					fx.append({"kind": "ring", "x": tw.x, "y": tw.y, "r": 14, "to": s.range, "life": .45, "max": .45, "col": Color("#5ab8ff"), "w": 12, "fill": Color(90 / 255.0, 184 / 255.0, 1)})
					for b in v:
						damage(b, 8, tw)
						push_back(b, 60)
						b.wet = 1.5
					sfx.emit(150, .35, "sawtooth", .04)
				else:
					tw.timers.h = .25
			if tw.cd > 0:
				return
			var tg := pick_targets(tw, s.jets)
			if tg.is_empty():
				return
			tw.cd = s.rate; tw.face = -1 if tg[0].x < tw.x else 1
			for i in tg.size():
				var b: Ball = tg[i]
				proj.append({"kind": "water", "x": tw.x + (i - (tg.size() - 1) / 2.0) * 8, "y": tw.y - 8, "tgt": b, "tx": b.x, "ty": b.y, "src": tw, "spd": 620.0, "life": 1.0})
			sfx.emit(500, .06, "sine", .02)
		"bulbasaur":
			if s.blizzard and _timer(tw, "p", 2, dt):
				var v := in_range(tw.x, tw.y, s.range, s.detect)
				if v.size():
					tw.timers.p = s.blizzard
					for b in v:
						damage(b, 4, tw)
					for i in 40:
						var a := randf() * TAU
						var r = randf() * s.range
						parts.append({"x": tw.x + cos(a) * r, "y": tw.y + sin(a) * r, "vx": cos(a + 1.5) * 80, "vy": sin(a + 1.5) * 80, "life": .6, "max": .6, "col": Color("#f07a92") if i % 2 else Color("#ffd0dc"), "size": 3.0})
				else:
					tw.timers.p = .25
			if s.powder and _timer(tw, "s", 3, dt):
				var v := in_range(tw.x, tw.y, s.range, s.detect, func(b): return not b.def.get("boss", false))
				if v.size():
					tw.timers.s = s.powder
					for b in v:
						if b.sleep_cd <= 0:
							b.sleep = 1.2
							b.sleep_cd = 1.8
					for i in 24:
						var a := randf() * TAU
						parts.append({"x": tw.x, "y": tw.y - 6, "vx": cos(a) * s.range * .9, "vy": sin(a) * s.range * .9, "life": .7, "max": .7, "col": Color("#c7f0a0"), "size": 2.6})
				else:
					tw.timers.s = .25
			if s.solar and _timer(tw, "b", 1, dt):
				_solar_beam(tw)
			if tw.cd > 0:
				return
			var tgt := pick_target(tw)
			if not tgt:
				return
			tw.cd = s.rate; tw.face = -1 if tgt.x < tw.x else 1
			var ang := atan2(tgt.y - tw.y, tgt.x - tw.x)
			for i in s.leaves:
				var a: float = ang + (i - (s.leaves - 1) / 2.0) * .16
				proj.append({"kind": "leaf", "x": tw.x, "y": tw.y - 4, "vx": cos(a) * 460, "vy": sin(a) * 460, "dist": s.range * 1.35, "pierce": s.pierce, "hit": {}, "src": tw, "rot": randf() * TAU})
			sfx.emit(880, .04, "triangle", .015)
		"meowth":
			if s.goldRush and _timer(tw, "g", 3, dt):
				var v := balls.filter(func(b): return not b.dead)
				if v.size():
					tw.timers.g = s.goldRush
					for b in v.slice(0, 30):
						proj.append({"kind": "coin", "x": b.x + (randf() - .5) * 40, "y": -20 - randf() * 60, "tgt": b, "tx": b.x, "ty": b.y, "src": tw, "spd": 520.0, "life": 2.0, "ph": randf() * 6})
					sfx.emit(1568, .12, "square", .02)
				else:
					tw.timers.g = .3
			if tw.cd > 0:
				return
			var tg := pick_targets(tw, s.swipes)
			if tg.is_empty():
				return
			tw.cd = s.rate; tw.face = -1 if tg[0].x < tw.x else 1
			for b in tg:
				fx.append({"kind": "slash", "x": b.x, "y": b.y, "life": .18, "max": .18})
				damage(b, s.dmg, tw)
			sfx.emit(1400, .03, "sawtooth", .012)
		"wobbuffet":
			if s.encore and _timer(tw, "e", 4, dt):
				var v := in_range(tw.x, tw.y, s.range, true)
				if v.size():
					tw.timers.e = s.encore
					for b in v:
						push_back(b, 150)
					fx.append({"kind": "text", "x": tw.x, "y": tw.y - 30, "text": "Encore!", "col": Color("#ffd23f"), "life": 1.0, "max": 1.0})
					fx.append({"kind": "ring", "x": tw.x, "y": tw.y, "r": 10, "to": s.range, "life": .5, "max": .5, "col": Color("#ffd23f"), "w": 4})
				else:
					tw.timers.e = .3
			if _timer(tw, "c", s.confuse, dt):
				tw.timers.c = s.confuse
				tw.conf = .9
				if randf() < (.2 if s.counter else .45):
					fx.append({"kind": "text", "x": tw.x, "y": tw.y - 34, "text": "It hurt itself in its confusion!", "col": Color.WHITE, "life": 1.3, "max": 1.3})
				if s.counter:
					var v := in_range(tw.x, tw.y, s.range, true)
					fx.append({"kind": "ring", "x": tw.x, "y": tw.y, "r": 8, "to": s.range, "life": .4, "max": .4, "col": Color("#f366a6"), "w": 5})
					for b in v:
						damage(b, s.counter * (s.bossMul if b.def.get("boss", false) else 1), tw)
					if v.size():
						sfx.emit(160, .2, "square", .03)
				else:
					sfx.emit(330, .15, "triangle", .02)
		"mewtwo":
			if s.psystrike and _timer(tw, "p", 2, dt):
				var v := in_range(tw.x, tw.y, s.range, true)
				if v.size():
					tw.timers.p = s.psystrike
					fx.append({"kind": "ring", "x": tw.x, "y": tw.y, "r": 16, "to": s.range, "life": .5, "max": .5, "col": Color("#ff7ad9"), "w": 8, "fill": Color(1, 122 / 255.0, 217 / 255.0)})
					for b in v:
						damage(b, 10 * (s.bossMul if b.def.get("boss", false) else 1), tw)
					shake = 4
					sfx.emit(100, .4, "sawtooth", .05)
				else:
					tw.timers.p = .25
			if s.future and _timer(tw, "f", 3, dt):
				var v := balls.filter(func(b): return not b.dead)
				if v.size():
					tw.timers.f = s.future
					var bb: Ball = v[0]
					for b in v:
						if b.def.tier * 1e5 + b.d > bb.def.tier * 1e5 + bb.d:
							bb = b
					marks.append({"b": bb, "life": 2.0, "max": 2.0, "dmg": 150 * (s.bossMul if bb.def.get("boss", false) else 1), "src": tw})
				else:
					tw.timers.f = .3
			if tw.cd > 0:
				return
			var tg := pick_targets(tw, s.targets)
			if tg.is_empty():
				return
			tw.cd = s.rate; tw.face = -1 if tg[0].x < tw.x else 1
			for b in tg:
				fx.append({"kind": "psy", "x1": tw.x, "y1": tw.y - 14, "x2": b.x, "y2": b.y, "life": .18, "max": .18})
				damage(b, s.dmg * (s.bossMul if b.def.get("boss", false) else 1), tw)
			sfx.emit(700, .06, "sine", .02)


## Solar Beam: fires across the whole map, aimed through as many balls as possible.
func _solar_beam(tw: Tower) -> void:
	var vis := balls.filter(func(b): return visible(b, true) and b.x > -10 and b.x < W + 10 and b.y > -10 and b.y < H + 10)
	if vis.is_empty():
		tw.timers.b = .25
		return
	tw.timers.b = tw.s.solar
	var origin := Vector2(tw.x, tw.y)
	var best_end := origin
	var best_n := -1
	for b in vis.slice(0, 60):
		var end := origin + Vector2.from_angle(atan2(b.y - tw.y, b.x - tw.x)) * 1200
		var n := 0
		for o in vis:
			if MapArt.seg_dist(Vector2(o.x, o.y), origin, end) < 18 + o.def.r:
				n += 1
		if n > best_n:
			best_n = n
			best_end = end
	for o in vis:
		if MapArt.seg_dist(Vector2(o.x, o.y), origin, best_end) < 18 + o.def.r:
			damage(o, 12, tw)
	fx.append({"kind": "beam", "x1": tw.x, "y1": tw.y - 6, "x2": best_end.x, "y2": best_end.y, "life": .6, "max": .6})
	fx.append({"kind": "text", "x": tw.x, "y": tw.y - 34, "text": "Solar Beam!", "col": Color("#fff4a0"), "life": 1.0, "max": 1.0, "big": true})
	tw.face = -1 if best_end.x < tw.x else 1
	shake = maxf(shake, 4)
	sfx.emit(220, .5, "triangle", .06)


func explode(p: Dictionary) -> void:
	var src: Tower = p.src
	var s := src.s
	fx.append({"kind": "ring", "x": p.x, "y": p.y, "r": 6, "to": s.radius, "life": .3, "max": .3, "col": Color("#b07aff"), "fill": Color(60 / 255.0, 20 / 255.0, 90 / 255.0)})
	for b in in_range(p.x, p.y, s.radius, true):
		var sleeping: bool = b.sleep > 0
		if s.sleep and not b.def.get("boss", false) and b.sleep_cd <= 0:
			b.sleep = s.sleep
			b.sleep_cd = s.sleep + .6
		damage(b, s.dmg + (s.dream if sleeping else 0), src)


# ---------- loop ----------
func step(dt: float) -> void:
	t += dt
	if running:
		qt += dt
		while q.size() and q[0].t <= qt:
			spawn_ball(q.pop_front().type, 0)
	# auras
	for b in balls:
		b.slow = .6 if b.wet > 0 else 1.0
		b.revealed = false
	for tw in towers:
		if tw.s.tag:
			for b in in_range(tw.x, tw.y, tw.s.range, true):
				b.slow = minf(b.slow, .75 if b.def.get("boss", false) else .5)
		if tw.s.shadowTag:
			var f: float = tw.s.shadowTag
			for b in in_range(tw.x, tw.y, tw.s.range, true):
				b.slow = minf(b.slow, 1 - (1 - f) / 2 if b.def.get("boss", false) else f)
				if tw.s.reveal:
					b.revealed = true
	# balls
	for b in balls:
		if b.dead:
			continue
		var def = b.def
		b.sleep_cd -= dt
		if b.sleep > 0:
			b.sleep -= dt
		else:
			b.d += 60 * def.spd * b.slow * dt
		b.wob += dt * (4 + def.spd * 2)
		var p := MapArt.pos_at(path, b.d)
		b.x = p.x; b.y = p.y
		if b.burn:
			b.burn.timer -= dt
			if b.burn.timer <= 0:
				b.burn.timer = b.burn.every
				b.burn.left -= 1
				var burn: Dictionary = b.burn
				damage(b, burn.dmg, burn.src)
				if burn.left <= 0:
					b.burn = null
		if b.wet > 0:
			b.wet -= dt
		if b.seed and not b.dead:
			b.seed.timer -= dt
			if b.seed.timer <= 0:
				var sd: Dictionary = b.seed
				sd.timer = 1
				sd.left -= 1
				if sd.left <= 0:
					b.seed = null
				money += 1
				damage(b, 1, sd.src)
		if not b.dead and b.d >= path.total:
			b.dead = true
			lives -= Data.rbe(b.type)
			alarm = .8
			shake = maxf(shake, 4)
			fx.append({"kind": "leak", "life": .4, "max": .4})
			sfx.emit(110, .2, "square", .04)
	for tw in towers:
		update_tower(tw, dt)
	# projectiles
	for p in proj:
		var src: Tower = p.src
		if p.kind == "leaf":
			var stp: float = Vector2(p.vx, p.vy).length() * dt
			p.x += p.vx * dt; p.y += p.vy * dt; p.dist -= stp; p.rot += dt * 14
			for b in balls:
				if p.pierce <= 0:
					break
				if not visible(b, src.s.detect) or p.hit.has(b.id):
					continue
				var r: float = b.def.r + 5
				if (b.x - p.x) ** 2 + (b.y - p.y) ** 2 < r * r:
					p.hit[b.id] = true
					p.pierce -= 1
					if src.s.seed:
						b.seed = {"left": 4, "timer": 1.0, "src": src}
					damage(b, src.s.dmg, src)
			if p.pierce <= 0 or p.dist <= 0 or p.x < -20 or p.x > W + 20 or p.y < -20 or p.y > H + 20:
				p.done = true
			continue
		var tgt: Ball = p.tgt
		if not tgt.dead:
			p.tx = tgt.x; p.ty = tgt.y
		var dx: float = p.tx - p.x
		var dy: float = p.ty - p.y
		var dist := sqrt(dx * dx + dy * dy)
		var stp: float = p.spd * dt
		p.life -= dt
		if p.has("ph"):
			p.ph += dt * 10
		if dist <= stp + 6 or p.life <= 0:
			p.x = p.tx; p.y = p.ty; p.done = true
			if p.kind == "water":
				var s := src.s
				if not tgt.dead:
					damage(tgt, s.dmg, src)
					push_back(tgt, s.push)
					if s.bubble:
						tgt.wet = 1.5
				for i in 6:
					var a := randf() * TAU
					parts.append({"x": p.x, "y": p.y, "vx": cos(a) * 70, "vy": sin(a) * 70, "life": .25, "max": .25, "col": Color("#bfe6ff") if i % 2 else Color("#4aa3f0"), "size": 2.4})
			elif p.kind == "coin":
				if not tgt.dead:
					damage(tgt, 4, src)
					money += 1
				for i in 4:
					var a := randf() * TAU
					parts.append({"x": p.x, "y": p.y, "vx": cos(a) * 60, "vy": sin(a) * 60, "life": .3, "max": .3, "col": Color("#ffd23f"), "size": 2.4})
			else:
				explode(p)
		else:
			p.x += dx / dist * stp
			p.y += dy / dist * stp
	proj = proj.filter(func(p): return not p.get("done", false))
	balls = balls.filter(func(b): return not b.dead)
	for f in fx:
		f.life -= dt
	fx = fx.filter(func(f): return f.life > 0)
	for p in parts:
		p.life -= dt; p.x += p.vx * dt; p.y += p.vy * dt; p.vx *= .9; p.vy *= .9
	parts = parts.filter(func(p): return p.life > 0)
	if parts.size() > 900:
		parts = parts.slice(parts.size() - 900)
	for k in coins:
		k.life -= dt; k.vy += 520 * dt; k.x += k.vx * dt; k.y += k.vy * dt; k.ph += dt * 12
		if k.y > k.floor and k.vy > 0:
			k.y = k.floor; k.vy *= -.45; k.vx *= .6
	coins = coins.filter(func(k): return k.life > 0)
	for m in marks:
		m.life -= dt
		var mb: Ball = m.b
		if m.life <= 0 and not mb.dead:
			var x := mb.x
			var y := mb.y
			damage(mb, m.dmg, m.src)
			fx.append({"kind": "ring", "x": x, "y": y, "r": 10, "to": 80, "life": .5, "max": .5, "col": Color("#ff7ad9"), "w": 6})
			fx.append({"kind": "flash", "life": .15, "max": .15, "col": Color(1, 170 / 255.0, 230 / 255.0)})
			sfx.emit(80, .4, "sawtooth", .05)
	marks = marks.filter(func(m): return m.life > 0)
	alarm = maxf(0, alarm - dt)
	for tw in towers:
		if tw.conf > 0:
			tw.conf -= dt
	if lives <= 0 and not over:
		lives = 0
		game_over()
	if running and q.is_empty() and balls.is_empty() and not over:
		wave_done()
	if not running and auto and not over and wave > 0 and not (wave == 40 and not freeplay):
		auto_timer -= dt
		if auto_timer <= 0:
			start_wave()


func can_start() -> bool:
	return map != null and not running and not over and not (wave == 40 and not freeplay)


func start_wave() -> void:
	if not can_start():
		return
	wave += 1
	q = Data.make_wave(wave)
	qt = 0.0
	running = true
	var parts_txt: Array = []
	for g in Data.wave_groups(wave):
		parts_txt.append("%d %s%s" % [g[1], BALLS[g[0]].name, "s" if g[1] > 1 else ""])
	toast.emit("Wave %d: %s" % [wave, ", ".join(parts_txt)])
	if wave == 25:
		toast.emit("Prepare for trouble! A Master Ball is coming.")
	if wave == 40:
		toast.emit("Make it double! The Meowth balloon is here.")


func wave_done() -> void:
	running = false
	var bonus := 150 + wave * 10
	money += bonus
	auto_timer = 1.0
	var pay := 0
	for tw in towers:
		if tw.s.pay:
			pay += int(tw.s.pay)
			pay_day(tw, int(tw.s.pay))
	money += pay
	if best.get(map.id, 0) < wave:
		best[map.id] = wave
	if wave == 40 and not freeplay:
		won = true
		ended.emit(true)
	else:
		toast.emit("Wave %d cleared. +₽%d%s" % [wave, bonus, (" and ₽%d from Pay Day" % pay) if pay else ""])
	wave_cleared.emit()


## Everything needed to pick a run back up between waves: the map, the wave,
## money, Pikachu's HP and every Pokémon with its upgrades.
func snapshot() -> Dictionary:
	var ts: Array = []
	for tw in towers:
		ts.append({"kind": tw.kind, "x": tw.x, "y": tw.y, "a": tw.a, "b": tw.b, "mode": tw.mode, "pops": tw.pops, "spent": tw.spent})
	return {"map": map.id, "wave": wave, "money": money, "lives": lives, "freeplay": freeplay or won, "towers": ts}


func restore(d: Dictionary) -> bool:
	var m = null
	for mm in Data.MAPS:
		if mm.id == d.get("map", ""):
			m = mm
	if m == null:
		return false
	new_game(m)
	wave = int(d.wave); money = int(d.money); lives = int(d.lives); freeplay = bool(d.freeplay)
	for e in d.towers:
		if not Data.TOWERS.has(e.kind):
			continue
		var tw := Tower.new()
		tw.id = next_id; next_id += 1
		tw.kind = e.kind; tw.x = float(e.x); tw.y = float(e.y); tw.a = int(e.a); tw.b = int(e.b)
		tw.mode = e.mode; tw.pops = int(e.pops); tw.spent = int(e.spent); tw.born = t - 1
		tw.s = Data.compute_stats(tw.kind, tw.a, tw.b)
		towers.append(tw)
	return true


func game_over() -> void:
	over = true
	running = false
	var reached := wave - 1
	if best.get(map.id, 0) < reached:
		best[map.id] = reached
	ended.emit(false)


## Advances the simulation by one real frame, in small fixed steps like the web version.
func frame(dt: float) -> void:
	dt = minf(.05, dt)
	if map and not paused and not over:
		var sim := dt * speed
		var steps := int(ceil(sim / (1.0 / 60.0)))
		for i in steps:
			step(sim / steps)
	shake = maxf(0, shake - dt * 20)
