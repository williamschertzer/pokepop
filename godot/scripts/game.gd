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
signal obstacles_changed

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
	var freeze := 0.0
	var freeze_cd := 0.0
	var brittle := false
	var broken := false  # Heavy Ball armour knocked off
	var trick := 0.0
	var age := 0.0
	var hit_t := 0.0


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
	var type := ""
	var hold := 0.0  # Snorlax: how much more pushing it can take
	var down := 0.0  # Snorlax: seconds until it's back after being pushed aside
	var pd := 0.0  # Snorlax: where on the path it sits
	var rush := 0.0  # G-Max Chi Strike: attacks twice as fast
	var outr := 0.0  # Outrage: attacks three times as fast
	var danced := 0  # Dragon Dance: waves survived
	var spots: Array = []  # Geodude: path distances it can drop rocks on
	var buffed := false
	var lucky := false  # in range of a Lucky Egg Chansey: pops pay ₽1 extra
	var copy := ""  # Ditto: the kind it has transformed into


var map = null
var path: Dictionary
var obs: Array = []
var deco: Array = []
var bg: Array = []  # ground, path and obstacles that stay
var obs_bg: Array = []  # obstacles a Pokémon can clear
var top_bg: Array = []  # signs and shading over everything
var cleared: Array = []  # ids of obstacles cleared this run
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
var traps: Array = []
var diff := "normal"
var spd_mul := 1.0
var start_lives := 0
var repel := 0.0
var candy := false
var item_uses := {}


# ---------- setup ----------
func setup_map(m: Dictionary) -> void:
	map = m
	path = MapArt.build_path(m.path)
	var o := MapArt.gen_obstacles(m, path)
	obs = o.obs
	deco = o.deco
	var layers := MapArt.render_layers(m, path, obs, deco)
	bg = layers.base
	obs_bg = layers.obs
	top_bg = layers.top
	cleared = []
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


func new_game(m: Dictionary, difficulty := "normal") -> void:
	setup_map(m)
	diff = difficulty if Data.DIFFS.has(difficulty) else "normal"
	var dd: Dictionary = Data.DIFFS[diff]
	spd_mul = dd.speed
	traps = []; repel = 0.0; candy = false; item_uses = {}
	coins = []; marks = []; alarm = 0.0; money = int(round(m.cash * dd.cash)); lives = int(round(m.lives * dd.lives)); wave = 0; running = false
	start_lives = lives
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
	if src:
		amt *= Data.type_mul(src.type, b.type)
		if src.s.armorBreak and b.def.get("armored", false):
			b.broken = true
	if b.freeze > 0 and b.brittle:
		amt += 2
	b.hit_t = 0.0
	b.hp -= amt
	if b.hp <= 0:
		pop_ball(b, src, -b.hp)


func pop_ball(b: Ball, src: Tower, over_dmg: float) -> void:
	b.dead = true
	money += 1 + (1 if src and src.s.dream else 0) + (3 if src and src.s.thief else 0) + (1 if src and src.lucky else 0)
	if src:
		src.pops += 1
	var def := b.def
	var boss: bool = def.get("boss", false)
	for i in (18 if boss else 6):
		var a := randf() * TAU
		var v := 40 + randf() * 90
		parts.append({"x": b.x, "y": b.y, "vx": cos(a) * v, "vy": sin(a) * v, "life": .35, "max": .35, "col": Color.WHITE if i % 2 else Color(def.top), "size": 3.0 if boss else 2.0, "shard": i < 4})
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


## Heavy Balls ignore Electric attacks until something knocks their armour off.
func armored(b: Ball) -> bool:
	return b.def.get("armored", false) and not b.broken


## Pops a ball and every layer inside it at once (Sheer Cold).
func shatter(b: Ball, src: Tower) -> void:
	var n := Data.rbe(b.type)
	b.dead = true
	money += n
	src.pops += n
	fx.append({"kind": "ring", "x": b.x, "y": b.y, "r": 6, "to": 46, "life": .4, "max": .4, "col": Color("#c8f4ff"), "w": 5})
	for i in 14:
		var a := randf() * TAU
		parts.append({"x": b.x, "y": b.y, "vx": cos(a) * 110, "vy": sin(a) * 110, "life": .5, "max": .5, "col": Color("#e6fbff") if i % 2 else Color("#8fd8ec"), "size": 3.0, "shard": true})
	sfx.emit(1800, .2, "triangle", .04)


func freeze_ball(b: Ball, dur: float, brittle: bool) -> void:
	if b.dead or b.freeze_cd > 0:
		return
	var d := dur * (.3 if b.def.get("boss", false) else 1.0)
	b.freeze = d
	b.freeze_cd = d + .5
	b.brittle = brittle


func strongest(list: Array) -> Ball:
	var best_b: Ball = null
	for b in list:
		if best_b == null or b.def.tier * 1e5 + b.d > best_b.def.tier * 1e5 + best_b.d:
			best_b = b
	return best_b


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
## Where along the path the nearest point to (x, y) is.
func path_d(x: float, y: float) -> float:
	var pt := Vector2(x, y)
	var best_d := 0.0
	var best_dist := INF
	for sg in path.segs:
		var ab: Vector2 = sg.b - sg.a
		var k := clampf((pt - sg.a).dot(ab) / ab.length_squared(), 0, 1)
		var dist := pt.distance_to(sg.a + ab * k)
		if dist < best_dist:
			best_dist = dist
			best_d = sg.start + k * sg.len
	return best_d


func can_place(kind: String, x: float, y: float) -> bool:
	if x < 16 or x > W - 16 or y < 16 or y > H - 16:
		return false
	if Data.TOWERS.has(kind) and Data.TOWERS[kind].get("onPath", false):
		if MapArt.dist_to_path(path, x, y) > 16:
			return false
		var d := path_d(x, y)
		if d < 80 or d > path.total - 80:
			return false
		for tw in towers:
			if tw.kind == "snorlax" and absf(tw.pd - d) < 70:
				return false
			if Vector2(tw.x - x, tw.y - y).length() < 28:
				return false
		return true
	if MapArt.dist_to_path(path, x, y) < 36:
		return false
	if MapArt.in_water(map, x, y) and not Data.SWIMMERS.has(kind):
		return false
	for o in obs:
		if Vector2(o.x - x, o.y - y).length() < o.r + 12:
			return false
	for tw in towers:
		if Vector2(tw.x - x, tw.y - y).length() < 32:
			return false
	return true


## Why a Pokémon can't go here, in words, or "" if it can.
func place_hint(kind: String, x: float, y: float) -> String:
	if can_place(kind, x, y):
		return ""
	if not Data.TOWERS[kind].get("onPath", false):
		if MapArt.in_water(map, x, y) and not Data.SWIMMERS.has(kind) and MapArt.dist_to_path(path, x, y) >= 36:
			return "Only Squirtle, Magikarp and Lapras can swim. Put %s on dry land." % Data.TOWERS[kind].name
		var o = obstacle_at(x, y, 12)
		if o != null and Data.OBSTACLES.has(o.kind):
			return "A %s is in the way. Tap it to see who can clear it." % Data.OBSTACLES[o.kind].name.to_lower()
	return "Can't place there. Keep off the path and obstacles."


# ---------- obstacles ----------
func obstacle_at(x: float, y: float, pad := 0.0):
	var best = null
	var best_d := 1e9
	for o in obs:
		var d := Vector2(o.x - x, o.y - y).length()
		if d < o.r + pad and d < best_d:
			best = o
			best_d = d
	return best


## Pokémon on the field that can clear this obstacle.
func clearers(o: Dictionary) -> Array:
	var out: Array = []
	var by: Dictionary = Data.OBSTACLES[o.kind].by
	for tw in towers:
		if by.has(tw.kind):
			out.append(tw)
	return out


## Clears an obstacle with the nearest Pokémon able to. Returns "" on success,
## otherwise the reason it can't.
func clear_obstacle(o: Dictionary) -> String:
	if not Data.OBSTACLES.has(o.kind) or not obs.has(o):
		return "That can't be moved."
	var od: Dictionary = Data.OBSTACLES[o.kind]
	var who := clearers(o)
	if who.is_empty():
		var names: Array = od.by.keys().map(func(k): return Data.TOWERS[k].name)
		return "You need %s on the field to clear this." % " or ".join(names)
	if money < od.cost:
		return "Need ₽%d more to clear this." % (od.cost - money)
	who.sort_custom(func(a, b): return Vector2(a.x - o.x, a.y - o.y).length() < Vector2(b.x - o.x, b.y - o.y).length())
	var tw = who[0]
	money -= od.cost
	_remove_obstacle(o)
	tw.face = 1 if o.x >= tw.x else -1
	var mon: String = Art.SPRITE_INFO[Data.sprite_for(tw.kind, tw.a)].name
	fx.append({"kind": "text", "x": o.x, "y": o.y - o.r - 14, "text": "%s used %s!" % [mon, od.by[tw.kind]], "col": Color.WHITE, "life": 1.4, "max": 1.4})
	fx.append({"kind": "ring", "x": o.x, "y": o.y, "r": 6, "to": o.r + 26, "life": .4, "max": .4, "col": Color.WHITE, "w": 4})
	var cols := {"tree": "#2f8a3c", "pine": "#1d5a2c", "deadtree": "#3b2f45", "rock": "#8a7b6b", "boulder": "#7d6f62", "ice": "#bfeaff", "sleeper": "#2f6f7a"}
	for i in 16:
		var a := randf() * TAU
		var v := 50 + randf() * 110
		parts.append({"x": o.x, "y": o.y, "vx": cos(a) * v, "vy": sin(a) * v - 40, "life": .5, "max": .5, "col": Color(cols.get(o.kind, "#ffffff")), "size": 3.0, "shard": i < 8})
	shake = maxf(shake, 4)
	sfx.emit(140, .18, "square", .05)
	var find: int = od.get("find", 0)
	if find and o.v >= 1.0 - od.get("chance", 1.0):
		money += find
		fx.append({"kind": "text", "x": o.x, "y": o.y - o.r - 34, "text": "Found ₽%d!" % find, "col": Color("#ffd23f"), "life": 1.8, "max": 1.8, "big": true})
		sfx.emit(1046, .12, "triangle", .05)
	money_bump.emit()
	return ""


func _remove_obstacle(o: Dictionary) -> void:
	obs.erase(o)
	cleared.append(o.id)
	obs_bg = MapArt.render_obstacles(obs)
	obstacles_changed.emit()


func place_tower(kind: String, x: float, y: float) -> Tower:
	var d: Dictionary = Data.TOWERS[kind]
	if money < d.cost or not can_place(kind, x, y):
		return null
	money -= d.cost
	var tw := Tower.new()
	tw.id = next_id; next_id += 1
	tw.kind = kind; tw.x = x; tw.y = y; tw.spent = d.cost; tw.born = t
	_init_tower(tw)
	towers.append(tw)
	refresh_buffs()
	for i in 12:
		var a := i / 12.0 * TAU
		parts.append({"x": x, "y": y + 8, "vx": cos(a) * 60, "vy": sin(a) * 30, "life": .4, "max": .4, "col": Color.WHITE, "size": 2.0})
	sfx.emit(660, .08, "square", .03)
	return tw


func _init_tower(tw: Tower) -> void:
	tw.type = Data.TOWERS[tw.kind].type
	tw.s = Data.compute_stats(tw.kind, tw.a, tw.b)
	if Data.TOWERS[tw.kind].get("onPath", false):
		tw.pd = path_d(tw.x, tw.y)
		var p := MapArt.pos_at(path, tw.pd)
		tw.x = p.x; tw.y = p.y
		tw.hold = tw.s.hold
	if tw.kind == "geodude":
		_find_spots(tw)


func _find_spots(tw: Tower) -> void:
	tw.spots = []
	var d := 0.0
	while d < path.total:
		var p := MapArt.pos_at(path, d)
		if p.distance_to(Vector2(tw.x, tw.y)) <= tw.s.range and p.x > 0 and p.x < W and p.y > 0 and p.y < H:
			tw.spots.append(d)
		d += 10


## Pokémon Ditto can't turn into: legendaries, ones that sit on the path, and
## ones whose power is helping others.
const NO_COPY := ["ditto", "mewtwo", "snorlax", "abra", "chansey"]


## Ditto's stats: those of the closest Pokémon in range, with as many of its
## upgrades as Ditto has learned to copy. Plain Ditto stats if nobody is near.
func ditto_stats(tw: Tower, a: int, b: int) -> Dictionary:
	var own := Data.compute_stats("ditto", a, b)
	var best_o: Tower = null
	var best_d := INF
	for o in towers:
		if o == tw or NO_COPY.has(o.kind):
			continue
		var dd := Vector2(o.x - tw.x, o.y - tw.y).length()
		if dd <= own.range and dd < best_d:
			best_d = dd
			best_o = o
	if best_o == null:
		own.copy = ""
		return own
	var ca := mini(best_o.a, int(own.copyA))
	var cb := mini(best_o.b, int(own.copyB))
	var k: String = best_o.kind if ca > 0 else Data.base_kind(best_o.kind)
	var s := Data.compute_stats(k, ca, cb)
	s.copy = k
	s.copyTier = ca
	s.copyA = own.copyA
	s.copyB = own.copyB
	return s


## Stats a Pokémon would have with these upgrades, before auras.
func stats_for(tw: Tower, a: int, b: int, kind := "") -> Dictionary:
	if tw.kind == "ditto":
		return ditto_stats(tw, a, b)
	return Data.compute_stats(kind if kind != "" else tw.kind, a, b)


## Recomputes every Pokémon's stats, adding Abra-line auras and Dragon Dance.
func refresh_buffs() -> void:
	var luckies := towers.filter(func(o): return o.kind == "chansey" and Data.compute_stats("chansey", o.a, o.b).lucky)
	for tw in towers:
		tw.type = Data.TOWERS[tw.kind].type
		if tw.kind == "ditto":
			var cp: String = ditto_stats(tw, tw.a, tw.b).copy
			if cp != tw.copy:
				tw.copy = cp
				tw.timers = {}
				tw.spots = []
			if tw.copy != "":
				tw.type = Data.TOWERS[tw.copy].type
		tw.lucky = false
		for ch in luckies:
			if ch != tw and Vector2(ch.x - tw.x, ch.y - tw.y).length() <= Data.compute_stats("chansey", ch.a, ch.b).range:
				tw.lucky = true
	for tw in towers:
		tw.s = stats_with_buffs(tw, tw.a, tw.b)
		tw.buffed = tw.s.get("_buffed", false)
		if tw.kind == "ditto" and tw.copy == "geodude" and tw.spots.is_empty():
			_find_spots(tw)


## A Pokémon's stats at upgrade tiers a/b, with nearby auras and Dragon Dance
## included, so upgrade previews compare like with like. Pass kind to preview
## one of Eevee's evolutions.
func stats_with_buffs(tw: Tower, a: int, b: int, kind := "") -> Dictionary:
	var s := stats_for(tw, a, b, kind)
	if tw.kind != "abra":
		var rate_k := 1.0
		var dmg_k := 0
		var range_k := 1.0
		var det := false
		for ab in towers:
			if ab.kind != "abra":
				continue
			var as_: Dictionary = Data.compute_stats("abra", ab.a, ab.b)
			if Vector2(ab.x - tw.x, ab.y - tw.y).length() > as_.range:
				continue
			rate_k = maxf(rate_k, as_.auraRate)
			dmg_k = maxi(dmg_k, int(as_.auraDmg))
			range_k = maxf(range_k, as_.auraRange)
			det = det or as_.auraDetect
		if rate_k > 1 or dmg_k > 0 or range_k > 1 or det:
			s["_buffed"] = true
			if s.rate:
				s.rate /= rate_k
			if s.dmg > 0:
				s.dmg += dmg_k
			if s.counter > 0:
				s.counter += dmg_k
			s.range *= range_k
			s.detect = s.detect or det
	if s.dance:
		s.rate /= 1 + minf(.6, .1 * tw.danced)
	return s


## Returns whether the upgrade on path "a" or "b" can be bought at all (ignoring money).
func upgrade_state(tw: Tower, p: String) -> String:
	var tier: int = tw.a if p == "a" else tw.b
	var other: int = tw.b if p == "a" else tw.a
	if tier >= 3:
		return "max"
	if tier >= 2 and other >= 3:
		return "locked"
	return "open"


## Buys the next upgrade on path "a" or "b". Eevee's first evolution needs a
## branch: the kind it evolves into.
func upgrade(tw: Tower, p: String, branch := "") -> void:
	var d: Dictionary = Data.TOWERS[tw.kind]
	if upgrade_state(tw, p) != "open":
		return
	var tier: int = tw.a if p == "a" else tw.b
	if p == "a" and d.has("branches"):
		if not d.branches.has(branch):
			return
		d = Data.TOWERS[branch]
	var list: Array = d.A if p == "a" else d.B
	var u: Dictionary = list[tier]
	var cost := upgrade_cost(u.cost)
	if money < cost:
		return
	money -= cost
	candy = false
	tw.spent += cost
	var before: String = Art.SPRITE_INFO[Data.sprite_for(tw.kind, tw.a)].name
	if branch != "" and p == "a":
		tw.kind = branch
	if p == "a":
		tw.a += 1
	else:
		tw.b += 1
	refresh_buffs()
	if tw.kind == "snorlax" and tw.down <= 0:
		tw.hold = tw.s.hold
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


## What an upgrade costs right now (Rare Candy takes 30% off).
func upgrade_cost(base: int) -> int:
	return int(round(base * .7)) if candy else base


func item_cost(id: String) -> int:
	var it: Dictionary = Data.ITEMS[id]
	return it.cost + it.step * item_uses.get(id, 0)


## Uses a trainer item. Returns "" on success, otherwise why it couldn't be used.
func use_item(id: String) -> String:
	if map == null or over:
		return "Start a map first."
	var cost := item_cost(id)
	if money < cost:
		return "Need ₽%d more for %s." % [cost - money, Data.ITEMS[id].name]
	match id:
		"potion":
			if lives >= start_lives:
				return "Pikachu's HP is already full."
			lives = mini(start_lives, lives + 25)
			fx.append({"kind": "text", "x": end_pt.x, "y": end_pt.y - 40, "text": "+25 HP", "col": Color("#7be3a2"), "life": 1.4, "max": 1.4, "big": true})
		"repel":
			if not running:
				return "Use Max Repel during a wave."
			repel = 5.0
			fx.append({"kind": "flash", "life": .3, "max": .3, "col": Color(.7, .5, 1)})
		"candy":
			if candy:
				return "A Rare Candy is already waiting for your next upgrade."
			candy = true
	money -= cost
	item_uses[id] = item_uses.get(id, 0) + 1
	sfx.emit(990, .1, "square", .03)
	info_changed.emit()
	return ""


func sell_value(tw: Tower) -> int:
	return int(floor(tw.spent * .7))


func sell(tw: Tower) -> void:
	money += sell_value(tw)
	towers.erase(tw)
	traps = traps.filter(func(r): return r.src != tw)
	refresh_buffs()
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
	if tw.rush > 0:
		tw.rush -= dt
		dt *= 2
	if tw.outr > 0:
		tw.outr -= dt
		dt *= 3
	tw.cd -= dt
	match tw.copy if tw.kind == "ditto" and tw.copy != "" else tw.kind:
		"pikachu":
			if s.gmax and _timer(tw, "g", 3, dt):
				var vic := balls.filter(func(b): return not b.dead and not armored(b))
				if vic.size():
					tw.timers.g = s.gmax
					fx.append({"kind": "flash", "life": .25, "max": .25, "col": Color(1, 246 / 255.0, 170 / 255.0)})
					for b in vic.slice(0, 40):
						fx.append({"kind": "bolt", "pts": [Vector2(b.x + (randf() - .5) * 30, -10), Vector2(b.x, b.y)], "life": .2, "max": .2, "col": Color("#fff6a8"), "w": 2.6})
					for b in vic:
						damage(b, 3, tw)
					shake = maxf(shake, 5)
					sfx.emit(120, .35, "sawtooth", .05)
				else:
					tw.timers.g = .3
			if tw.cd > 0:
				return
			var thunder: bool = s.thunder and tw.shots % 3 == 2
			var tgt := pick_target(tw, null if thunder else func(b): return not armored(b))
			if not tgt:
				return
			tw.cd = s.rate; tw.shots += 1; tw.face = -1 if tgt.x < tw.x else 1
			if thunder:
				fx.append({"kind": "bolt", "pts": [Vector2(tgt.x + 8, -10), Vector2(tgt.x - 6, tgt.y - 80), Vector2(tgt.x + 4, tgt.y - 40), Vector2(tgt.x, tgt.y)], "life": .22, "max": .22, "col": Color("#fff6a8"), "w": 4.5})
				fx.append({"kind": "ring", "x": tgt.x, "y": tgt.y, "r": 8, "to": 55, "life": .3, "max": .3, "col": Color("#fff38a")})
				for b in in_range(tgt.x, tgt.y, 55, true):
					damage(b, 8, tw)
				shake = maxf(shake, 3)
				sfx.emit(90, .25, "sawtooth", .05)
				return
			var hit := [tgt]
			var cur := tgt
			for i in range(1, s.chain):
				var nb: Ball = null
				var nd := 80.0 * 80.0
				for b in balls:
					if not visible(b, s.detect) or hit.has(b) or armored(b):
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
				for k in 2:
					var a := randf() * TAU
					parts.append({"x": b.x, "y": b.y, "vx": cos(a) * 90, "vy": sin(a) * 90, "life": .18, "max": .18, "col": Color("#fff6a8"), "size": 2.0})
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
					shake = maxf(shake, 4)
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
		"magikarp":
			if s.bounce and _timer(tw, "bo", 2, dt):
				var best_b := strongest(in_range(tw.x, tw.y, s.range, s.detect))
				if best_b:
					tw.timers.bo = s.bounce
					var bx := best_b.x
					var by := best_b.y
					damage(best_b, 20, tw)
					for o in in_range(bx, by, 40, s.detect):
						damage(o, 6, tw)
					fx.append({"kind": "ring", "x": bx, "y": by, "r": 6, "to": 44, "life": .35, "max": .35, "col": Color("#ff9a4a"), "w": 6})
					fx.append({"kind": "text", "x": tw.x, "y": tw.y - 34, "text": "Bounce!", "col": Color("#ffd23f"), "life": .9, "max": .9})
					shake = maxf(shake, 3)
					sfx.emit(140, .25, "square", .04)
				else:
					tw.timers.bo = .3
			if tw.cd > 0:
				return
			var tgt := pick_target(tw)
			if not tgt:
				return
			tw.cd = s.rate; tw.face = -1 if tgt.x < tw.x else 1
			if s.splash:
				tw.conf = .4
				if randf() < .2:
					fx.append({"kind": "text", "x": tw.x, "y": tw.y - 30, "text": "But nothing happened!", "col": Color.WHITE, "life": 1.1, "max": 1.1})
				sfx.emit(600, .05, "sine", .015)
				return
			var dmg: float = s.dmg
			if s.flail:
				dmg += clampi(int(4 * (1.0 - float(lives) / maxf(1, start_lives))) + 0, 0, 4)
			var hit: Array = [tgt]
			if s.area:
				hit = in_range(tgt.x, tgt.y, s.area, s.detect)
				if not hit.has(tgt):
					hit.append(tgt)
				fx.append({"kind": "ring", "x": tgt.x, "y": tgt.y, "r": 6, "to": s.area, "life": .3, "max": .3, "col": Color("#5ab8ff"), "w": 5, "fill": Color(90 / 255.0, 184 / 255.0, 1)})
			fx.append({"kind": "jet", "x1": tw.x, "y1": tw.y - 10, "x2": tgt.x, "y2": tgt.y, "life": .16, "max": .16, "col": Color("#5ab8ff")})
			for b in hit:
				damage(b, dmg, tw)
			sfx.emit(300, .08, "sawtooth", .02)
		"pidgey":
			if s.hurricane and _timer(tw, "h", 3, dt):
				var v := in_range(tw.x, tw.y, s.range, s.detect)
				if v.size():
					tw.timers.h = s.hurricane
					fx.append({"kind": "ring", "x": tw.x, "y": tw.y, "r": 20, "to": s.range, "life": .55, "max": .55, "col": Color("#e6e0ff"), "w": 10})
					fx.append({"kind": "text", "x": tw.x, "y": tw.y - 34, "text": "Hurricane!", "col": Color("#e6e0ff"), "life": 1.0, "max": 1.0, "big": true})
					for b in v:
						damage(b, 6, tw)
						push_back(b, 50)
					shake = maxf(shake, 4)
					sfx.emit(200, .45, "sawtooth", .05)
				else:
					tw.timers.h = .3
			if tw.cd > 0:
				return
			var tgt := pick_target(tw)
			if not tgt:
				return
			tw.cd = s.rate; tw.shots += 1; tw.face = -1 if tgt.x < tw.x else 1
			var origin := Vector2(tw.x, tw.y - 8)
			if s.brave and tw.shots % 3 == 0:
				fx.append({"kind": "gust", "x1": origin.x, "y1": origin.y, "x2": tgt.x, "y2": tgt.y, "life": .25, "max": .25, "w": 7.0, "col": Color("#ffd23f")})
				fx.append({"kind": "ring", "x": tgt.x, "y": tgt.y, "r": 4, "to": 34, "life": .3, "max": .3, "col": Color("#ffd23f"), "w": 4})
				damage(tgt, s.brave, tw)
				sfx.emit(160, .2, "sawtooth", .04)
				return
			var hits: Array = [tgt]
			var end := Vector2(tgt.x, tgt.y)
			if s.pierce > 1:
				end = origin + (end - origin).normalized() * (s.range + 30)
				var line := in_range(tw.x, tw.y, s.range + 30, s.detect).filter(func(b): return b != tgt and MapArt.seg_dist(Vector2(b.x, b.y), origin, end) < b.def.r + 6)
				line = Data.stable_sort(line, func(a, b): return Vector2(a.x, a.y).distance_squared_to(origin) < Vector2(b.x, b.y).distance_squared_to(origin))
				hits.append_array(line.slice(0, s.pierce - 1))
			fx.append({"kind": "gust", "x1": origin.x, "y1": origin.y, "x2": end.x, "y2": end.y, "life": .15, "max": .15, "w": 3.0, "col": Color("#f4f0ff")})
			for b in hits:
				damage(b, s.dmg, tw)
				if s.push:
					push_back(b, s.push)
			sfx.emit(1000, .04, "triangle", .015)
		"geodude":
			if s.quake and _timer(tw, "q", 3, dt):
				var v := in_range(tw.x, tw.y, s.range * 1.4, true)
				if v.size():
					tw.timers.q = s.quake
					fx.append({"kind": "ring", "x": tw.x, "y": tw.y, "r": 20, "to": s.range * 1.4, "life": .5, "max": .5, "col": Color("#c8a060"), "w": 12, "fill": Color("#8a6a3a")})
					fx.append({"kind": "text", "x": tw.x, "y": tw.y - 34, "text": "Earthquake!", "col": Color("#ffe0a0"), "life": 1.0, "max": 1.0, "big": true})
					for b in v:
						damage(b, 8, tw)
					shake = maxf(shake, 7)
					sfx.emit(60, .5, "sawtooth", .06)
				else:
					tw.timers.q = .3
			if s.explode and _timer(tw, "x", 4, dt):
				var mine := traps.filter(func(r): return r.src == tw)
				if mine.size() and balls.size():
					tw.timers.x = s.explode
					for r in mine:
						fx.append({"kind": "ring", "x": r.x, "y": r.y, "r": 4, "to": 50, "life": .35, "max": .35, "col": Color("#ffb347"), "w": 6, "fill": Color("#ff7a1a")})
						for b in in_range(r.x, r.y, 50, true):
							damage(b, 10, tw)
						r.uses = 0
					shake = maxf(shake, 6)
					sfx.emit(70, .45, "sawtooth", .06)
				else:
					tw.timers.x = .5
			if tw.cd > 0:
				return
			tw.cd = s.rate
			var mine_n := 0
			for r in traps:
				if r.src == tw:
					mine_n += 1
			if mine_n < 6 * s.rocks and tw.spots.size():
				for i in s.rocks:
					var d: float = tw.spots[randi() % tw.spots.size()]
					var p := MapArt.pos_at(path, d)
					traps.append({"x": p.x + (randf() - .5) * 10, "y": p.y + (randf() - .5) * 10, "d": d, "uses": s.rockUses, "src": tw, "hit": {}, "rot": randf() * TAU})
					for k in 5:
						var a := randf() * TAU
						parts.append({"x": p.x, "y": p.y, "vx": cos(a) * 40, "vy": sin(a) * 40, "life": .3, "max": .3, "col": Color("#a08a6a"), "size": 2.4})
			if s.throw:
				var tgt := pick_target(tw)
				if tgt:
					tw.face = -1 if tgt.x < tw.x else 1
					proj.append({"kind": "rock", "x": tw.x, "y": tw.y - 10, "tgt": tgt, "tx": tgt.x, "ty": tgt.y, "src": tw, "spd": 460.0, "life": 1.2, "rot": 0.0})
		"machop":
			if s.chi and _timer(tw, "c", 4, dt):
				if running and balls.size():
					tw.timers.c = s.chi
					for o in towers:
						if o != tw and Vector2(o.x - tw.x, o.y - tw.y).length() <= 160:
							o.rush = 4.0
					fx.append({"kind": "ring", "x": tw.x, "y": tw.y, "r": 10, "to": 160, "life": .6, "max": .6, "col": Color("#ff6a3a"), "w": 8})
					fx.append({"kind": "text", "x": tw.x, "y": tw.y - 38, "text": "G-Max Chi Strike!", "col": Color("#ffb08a"), "life": 1.1, "max": 1.1, "big": true})
					sfx.emit(240, .3, "square", .04)
				else:
					tw.timers.c = .5
			if tw.cd > 0:
				return
			var tg := pick_targets(tw, s.targets)
			if tg.is_empty():
				return
			tw.cd = s.rate; tw.face = -1 if tg[0].x < tw.x else 1
			for b in tg:
				fx.append({"kind": "punch", "x": b.x, "y": b.y, "life": .2, "max": .2})
				damage(b, s.dmg, tw)
				if s.push:
					push_back(b, s.push)
			sfx.emit(220, .05, "square", .02)
		"abra":
			if s.trick and _timer(tw, "t", 4, dt):
				if balls.size():
					tw.timers.t = s.trick
					for b in balls:
						b.trick = 3.0
					fx.append({"kind": "flash", "life": .35, "max": .35, "col": Color(1, .55, .85)})
					fx.append({"kind": "text", "x": tw.x, "y": tw.y - 34, "text": "Trick Room!", "col": Color("#ffb3e6"), "life": 1.1, "max": 1.1, "big": true})
					sfx.emit(330, .4, "sine", .05)
				else:
					tw.timers.t = .5
			if tw.cd > 0:
				return
			var tgt := pick_target(tw)
			if not tgt:
				return
			tw.cd = s.rate; tw.face = -1 if tgt.x < tw.x else 1
			fx.append({"kind": "psy", "x1": tw.x, "y1": tw.y - 12, "x2": tgt.x, "y2": tgt.y, "life": .18, "max": .18})
			damage(tgt, s.dmg, tw)
			sfx.emit(800, .05, "sine", .015)
		"lapras":
			if s.gfreeze and _timer(tw, "g", 4, dt):
				if balls.size():
					tw.timers.g = s.gfreeze
					for b in balls:
						b.freeze_cd = 0
						freeze_ball(b, 2.0, s.brittle)
					fx.append({"kind": "flash", "life": .4, "max": .4, "col": Color(.75, .95, 1)})
					fx.append({"kind": "text", "x": tw.x, "y": tw.y - 38, "text": "G-Max Resonance!", "col": Color("#c8f4ff"), "life": 1.2, "max": 1.2, "big": true})
					shake = maxf(shake, 4)
					sfx.emit(1500, .5, "triangle", .05)
				else:
					tw.timers.g = .5
			if s.surf and _timer(tw, "s", 2, dt):
				var v := in_range(tw.x, tw.y, s.range, s.detect)
				if v.size():
					tw.timers.s = s.surf
					fx.append({"kind": "ring", "x": tw.x, "y": tw.y, "r": 14, "to": s.range, "life": .45, "max": .45, "col": Color("#5ab8ff"), "w": 10, "fill": Color(90 / 255.0, 184 / 255.0, 1)})
					for b in v:
						damage(b, 2, tw)
						push_back(b, 45)
					sfx.emit(160, .3, "sawtooth", .04)
				else:
					tw.timers.s = .3
			if s.cold and _timer(tw, "c", 3, dt):
				var best_b := strongest(in_range(tw.x, tw.y, s.range, s.detect, func(b): return not b.def.get("boss", false)))
				if best_b:
					tw.timers.c = s.cold
					fx.append({"kind": "ice", "x1": tw.x, "y1": tw.y - 10, "x2": best_b.x, "y2": best_b.y, "life": .3, "max": .3, "w": 6.0})
					fx.append({"kind": "text", "x": tw.x, "y": tw.y - 34, "text": "Sheer Cold!", "col": Color("#c8f4ff"), "life": 1.0, "max": 1.0})
					shatter(best_b, tw)
				else:
					tw.timers.c = .3
			if tw.cd > 0:
				return
			var tgt := pick_target(tw)
			if not tgt:
				return
			tw.cd = s.rate; tw.face = -1 if tgt.x < tw.x else 1
			var hit: Array = [tgt]
			if s.area:
				hit = in_range(tgt.x, tgt.y, s.area, s.detect)
				if not hit.has(tgt):
					hit.append(tgt)
				fx.append({"kind": "ring", "x": tgt.x, "y": tgt.y, "r": 6, "to": s.area, "life": .35, "max": .35, "col": Color("#c8f4ff"), "w": 4, "fill": Color("#e6fbff")})
			fx.append({"kind": "ice", "x1": tw.x, "y1": tw.y - 10, "x2": tgt.x, "y2": tgt.y, "life": .18, "max": .18, "w": 3.0})
			for b in hit:
				damage(b, s.dmg, tw)
				freeze_ball(b, s.freeze, s.brittle)
			sfx.emit(1600 + randf() * 200, .05, "triangle", .015)
		"snorlax":
			if tw.down > 0:
				tw.down -= dt
				if tw.down <= 0:
					tw.hold = s.hold
					fx.append({"kind": "text", "x": tw.x, "y": tw.y - 34, "text": "Snorlax is back!", "col": Color.WHITE, "life": 1.0, "max": 1.0})
				return
			if tw.hold <= 0:
				tw.down = s.recover
				fx.append({"kind": "text", "x": tw.x, "y": tw.y - 34, "text": "Snorlax got pushed aside!", "col": Color("#ffb3b3"), "life": 1.2, "max": 1.2})
				sfx.emit(120, .3, "triangle", .04)
				return
			if s.slam and _timer(tw, "s", 1, dt):
				var v := in_range(tw.x, tw.y, s.range, true)
				if v.size():
					tw.timers.s = s.slam
					tw.conf = .3
					fx.append({"kind": "ring", "x": tw.x, "y": tw.y + 6, "r": 10, "to": s.range, "life": .3, "max": .3, "col": Color("#e6d8b0"), "w": 6})
					for b in v:
						damage(b, s.slamDmg, tw)
					shake = maxf(shake, 2 if s.slamDmg < 5 else 4)
					sfx.emit(90, .15, "square", .03)
				else:
					tw.timers.s = .25
			if s.yawn and _timer(tw, "y", 2, dt):
				var v := in_range(tw.x, tw.y, s.range + 20, true, func(b): return not b.def.get("boss", false))
				if v.size():
					tw.timers.y = s.yawn
					for b in v:
						if b.sleep_cd <= 0:
							b.sleep = 1.0
							b.sleep_cd = 1.6
				else:
					tw.timers.y = .3
		"dratini":
			if s.outrage and _timer(tw, "o", 5, dt):
				if running and balls.size():
					tw.timers.o = s.outrage
					tw.outr = 5.0
					fx.append({"kind": "text", "x": tw.x, "y": tw.y - 38, "text": "Outrage!", "col": Color("#c9b0ff"), "life": 1.0, "max": 1.0, "big": true})
					sfx.emit(180, .3, "sawtooth", .04)
				else:
					tw.timers.o = .5
			if s.hyper and _timer(tw, "h", 3, dt):
				var best_b := strongest(in_range(tw.x, tw.y, s.range, s.detect))
				if best_b:
					tw.timers.h = s.hyper
					var origin := Vector2(tw.x, tw.y - 8)
					var end := origin + (Vector2(best_b.x, best_b.y) - origin).normalized() * 1200
					for o in balls.filter(func(b): return visible(b, s.detect)):
						if MapArt.seg_dist(Vector2(o.x, o.y), origin, end) < 16 + o.def.r:
							damage(o, 30 * (s.bossMul if o.def.get("boss", false) else 1), tw)
					fx.append({"kind": "beam", "x1": origin.x, "y1": origin.y, "x2": end.x, "y2": end.y, "life": .5, "max": .5, "tint": Color("#c9b0ff")})
					fx.append({"kind": "text", "x": tw.x, "y": tw.y - 34, "text": "Hyper Beam!", "col": Color("#e0d0ff"), "life": 1.0, "max": 1.0, "big": true})
					tw.face = -1 if end.x < tw.x else 1
					shake = maxf(shake, 5)
					sfx.emit(110, .5, "sawtooth", .06)
				else:
					tw.timers.h = .3
			if tw.cd > 0:
				return
			var tgt := pick_target(tw)
			if not tgt:
				return
			tw.cd = s.rate; tw.face = -1 if tgt.x < tw.x else 1
			var boss: bool = tgt.def.get("boss", false)
			fx.append({"kind": "dragon", "x1": tw.x, "y1": tw.y - 10, "x2": tgt.x, "y2": tgt.y, "life": .2, "max": .2})
			damage(tgt, s.dmg * (s.bossMul if boss else 1) + (s.rage if boss else 0), tw)
			sfx.emit(420, .07, "sawtooth", .02)
		"eevee", "vaporeon", "jolteon", "flareon":
			if s.muddy and _timer(tw, "m", 2, dt):
				var v := in_range(tw.x, tw.y, s.range, s.detect)
				if v.size():
					tw.timers.m = s.muddy
					fx.append({"kind": "ring", "x": tw.x, "y": tw.y, "r": 14, "to": s.range, "life": .45, "max": .45, "col": Color("#7a9ad0"), "w": 10, "fill": Color("#6a5a3a")})
					for b in v:
						damage(b, s.muddyDmg, tw)
						push_back(b, 40)
						b.wet = 1.5
					shake = maxf(shake, 3)
					sfx.emit(140, .35, "sawtooth", .04)
				else:
					tw.timers.m = .3
			if s.volt and _timer(tw, "v", 3, dt):
				var v := in_range(tw.x, tw.y, s.range, s.detect)
				if v.size():
					tw.timers.v = s.volt
					for b in v:
						fx.append({"kind": "bolt", "pts": [Vector2(b.x + (randf() - .5) * 20, b.y - 60), Vector2(b.x, b.y)], "life": .2, "max": .2, "col": Color("#fff6a8"), "w": 2.6})
						damage(b, 8, tw)
					fx.append({"kind": "text", "x": tw.x, "y": tw.y - 34, "text": "Thunder Fang!", "col": Color("#fff38a"), "life": 1.0, "max": 1.0, "big": true})
					shake = maxf(shake, 3)
					sfx.emit(110, .3, "sawtooth", .05)
				else:
					tw.timers.v = .3
			if s.resort and _timer(tw, "r", 3, dt):
				var best_b := strongest(in_range(tw.x, tw.y, s.range, s.detect))
				if best_b:
					tw.timers.r = s.resort
					fx.append({"kind": "ring", "x": best_b.x, "y": best_b.y, "r": 4, "to": 36, "life": .35, "max": .35, "col": Color("#ffd23f"), "w": 5})
					fx.append({"kind": "text", "x": tw.x, "y": tw.y - 34, "text": "Last Resort!", "col": Color("#ffe6a0"), "life": 1.0, "max": 1.0})
					damage(best_b, 25, tw)
					sfx.emit(200, .2, "square", .04)
				else:
					tw.timers.r = .3
			if tw.cd > 0:
				return
			var electric := tw.type == "Electric"
			var tg := pick_targets(tw, s.targets, (func(b): return not armored(b)) if electric else null)
			if tg.is_empty():
				return
			tw.cd = s.rate; tw.face = -1 if tg[0].x < tw.x else 1
			var col: Color = {"Water": Color("#7cc4ff"), "Electric": Color("#fff38a"), "Fire": Color("#ffa040")}.get(tw.type, Color("#ffe6a0"))
			for b in tg:
				fx.append({"kind": "swift", "x1": tw.x, "y1": tw.y - 10, "x2": b.x, "y2": b.y, "life": .2, "max": .2, "col": col})
				var hit: Array = [b]
				if s.area:
					for o in in_range(b.x, b.y, s.area, s.detect):
						if o != b:
							hit.append(o)
				for o in hit:
					if electric and armored(o):
						continue
					if s.burn:
						o.burn = {"left": s.burn, "every": .75, "timer": .75, "dmg": s.burnMul, "src": tw}
					if s.soak:
						o.wet = 1.5
					damage(o, s.dmg, tw)
			sfx.emit(1100 + randf() * 200, .04, "triangle", .015)
		"ditto":
			# not transformed: a feeble Pound
			if tw.cd > 0:
				return
			var tgt := pick_target(tw)
			if not tgt:
				return
			tw.cd = s.rate; tw.face = -1 if tgt.x < tw.x else 1
			fx.append({"kind": "punch", "x": tgt.x, "y": tgt.y, "life": .2, "max": .2})
			damage(tgt, s.dmg, tw)
			sfx.emit(260, .05, "square", .015)
		"chansey":
			if s.safeguard:
				tw.timers.sg = maxf(0, tw.timers.get("sg", 0.0) - dt)
			if s.toss and _timer(tw, "t", 2, dt):
				var best_b := strongest(in_range(tw.x, tw.y, s.range, s.detect))
				if best_b:
					tw.timers.t = s.toss
					fx.append({"kind": "ring", "x": best_b.x, "y": best_b.y, "r": 4, "to": 40, "life": .35, "max": .35, "col": Color("#ffb3d0"), "w": 6})
					fx.append({"kind": "text", "x": tw.x, "y": tw.y - 34, "text": "Seismic Toss!", "col": Color("#ffd0e0"), "life": 1.0, "max": 1.0})
					damage(best_b, 15, tw)
					shake = maxf(shake, 2)
					sfx.emit(120, .2, "square", .04)
				else:
					tw.timers.t = .3
			if tw.cd > 0:
				return
			var tgt := pick_target(tw)
			if not tgt:
				return
			tw.cd = s.rate; tw.face = -1 if tgt.x < tw.x else 1
			proj.append({"kind": "egg", "x": tw.x, "y": tw.y - 6, "tgt": tgt, "tx": tgt.x, "ty": tgt.y, "src": tw, "spd": 380.0, "life": 1.2, "rot": 0.0})
			sfx.emit(700, .05, "sine", .015)


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
	for i in 5:
		var a := randf() * TAU
		parts.append({"x": p.x, "y": p.y, "vx": cos(a) * 40, "vy": sin(a) * 40 - 20, "life": .5, "max": .5, "col": Color("#6a3aa8"), "size": 4.0, "grow": true})
	for b in in_range(p.x, p.y, s.radius, true):
		var sleeping: bool = b.sleep > 0
		if s.sleep and not b.def.get("boss", false) and b.sleep_cd <= 0:
			b.sleep = s.sleep
			b.sleep_cd = s.sleep + .6
		damage(b, s.dmg + (s.dream if sleeping else 0), src)


## Chansey's Safeguard: a ready one sends a leaking ball back to the start.
func _safeguard(b: Ball) -> bool:
	for tw in towers:
		if tw.s.safeguard and tw.timers.get("sg", 0.0) <= 0:
			tw.timers.sg = tw.s.safeguard
			b.d = 0
			var p := MapArt.pos_at(path, 0)
			b.x = p.x; b.y = p.y
			fx.append({"kind": "text", "x": end_pt.x, "y": end_pt.y - 40, "text": "Safeguard!", "col": Color("#ffb3d0"), "life": 1.2, "max": 1.2, "big": true})
			fx.append({"kind": "ring", "x": end_pt.x, "y": end_pt.y, "r": 8, "to": 50, "life": .4, "max": .4, "col": Color("#ffb3d0"), "w": 5})
			sfx.emit(880, .2, "triangle", .04)
			return true
	return false


# ---------- loop ----------
func step(dt: float) -> void:
	t += dt
	if running:
		qt += dt
		while q.size() and q[0].t <= qt:
			spawn_ball(q.pop_front().type, 0)
	# auras
	repel = maxf(0, repel - dt)
	for b in balls:
		b.slow = .6 if b.wet > 0 else 1.0
		b.revealed = false
		if b.trick > 0:
			b.trick -= dt
			b.slow = minf(b.slow, .75 if b.def.get("boss", false) else .5)
		if repel > 0:
			b.slow = minf(b.slow, .5)
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
	var blockers := towers.filter(func(o): return o.kind == "snorlax" and o.down <= 0 and o.hold > 0)
	for b in balls:
		if b.dead:
			continue
		var def = b.def
		b.sleep_cd -= dt
		b.freeze_cd -= dt
		if def.get("regen", false):
			b.hit_t += dt
			if b.hit_t > 1.5 and b.hp < b.max_hp:
				b.hp = minf(b.max_hp, b.hp + 1)
				b.hit_t = .5
		if b.freeze > 0:
			b.freeze -= dt
		elif b.sleep > 0:
			b.sleep -= dt
		else:
			var mv: float = 60 * def.spd * b.slow * dt * spd_mul
			if def.get("accel", false):
				b.age += dt
				mv *= minf(2.5, .6 + b.age * .12)
			var nd: float = b.d + mv
			for sn in blockers:
				var stop: float = sn.pd - def.r - 14
				if b.d <= stop + 1 and nd > stop:
					nd = maxf(b.d, stop)
					sn.hold -= dt * (8.0 if def.get("boss", false) else 1.0)
			b.d = nd
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
		if not b.dead and b.d >= path.total and not def.get("boss", false) and _safeguard(b):
			continue
		if not b.dead and b.d >= path.total:
			b.dead = true
			lives -= Data.rbe(b.type)
			alarm = .8
			shake = maxf(shake, 4)
			fx.append({"kind": "leak", "life": .4, "max": .4})
			sfx.emit(110, .2, "square", .04)
	# Geodude's rocks
	for r in traps:
		var src: Tower = r.src
		for b in balls:
			if r.uses <= 0:
				break
			if b.dead or r.hit.has(b.id) or absf(b.d - r.d) > b.def.r + 6:
				continue
			r.hit[b.id] = true
			r.uses -= 1
			damage(b, src.s.dmg, src)
	traps = traps.filter(func(r): return r.uses > 0)
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
		if p.has("rot"):
			p.rot += dt * 12
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
			elif p.kind == "rock":
				if not tgt.dead:
					damage(tgt, src.s.throw, src)
				for i in 5:
					var a := randf() * TAU
					parts.append({"x": p.x, "y": p.y, "vx": cos(a) * 60, "vy": sin(a) * 60, "life": .3, "max": .3, "col": Color("#a08a6a"), "size": 2.6})
			elif p.kind == "egg":
				var s := src.s
				var hit: Array = [] if tgt.dead else [tgt]
				if s.eggArea:
					for o in in_range(p.x, p.y, s.eggArea, s.detect):
						if not hit.has(o):
							hit.append(o)
					fx.append({"kind": "ring", "x": p.x, "y": p.y, "r": 4, "to": s.eggArea, "life": .3, "max": .3, "col": Color("#fff4d8"), "w": 4, "fill": Color("#ffe08a")})
				for o in hit:
					damage(o, s.dmg, src)
				for i in 6:
					var a := randf() * TAU
					parts.append({"x": p.x, "y": p.y, "vx": cos(a) * 70, "vy": sin(a) * 70, "life": .3, "max": .3, "col": Color("#fffaf0") if i % 2 else Color("#ffd23f"), "size": 2.4})
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
	for tw in towers:
		if tw.kind == "snorlax":
			tw.hold = tw.s.hold
			tw.down = 0.0
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
	var healed := 0
	for tw in towers:
		if tw.s.heal and lives < start_lives:
			var h := mini(int(tw.s.heal), start_lives - lives)
			lives += h
			healed += h
			fx.append({"kind": "text", "x": tw.x, "y": tw.y - 34, "text": "Soft-Boiled +%d HP" % h, "col": Color("#ffb3d0"), "life": 1.6, "max": 1.6, "big": true})
	var dancers := false
	for tw in towers:
		if tw.s.dance:
			tw.danced += 1
			dancers = true
	if dancers:
		refresh_buffs()
	var bk := Data.best_key(map.id, diff)
	if best.get(bk, 0) < wave:
		best[bk] = wave
	if wave == 40 and not freeplay:
		won = true
		ended.emit(true)
	else:
		toast.emit("Wave %d cleared. +₽%d%s%s" % [wave, bonus, (" and ₽%d from Pay Day" % pay) if pay else "", (". Chansey healed %d HP" % healed) if healed else ""])
	wave_cleared.emit()


## Everything needed to pick a run back up between waves: the map, the wave,
## money, Pikachu's HP and every Pokémon with its upgrades.
func snapshot() -> Dictionary:
	var ts: Array = []
	for tw in towers:
		ts.append({"kind": tw.kind, "x": tw.x, "y": tw.y, "a": tw.a, "b": tw.b, "mode": tw.mode, "pops": tw.pops, "spent": tw.spent, "danced": tw.danced})
	return {"map": map.id, "diff": diff, "wave": wave, "money": money, "lives": lives, "start_lives": start_lives, "freeplay": freeplay or won, "towers": ts, "items": item_uses.duplicate(), "candy": candy, "cleared": cleared.duplicate()}


func restore(d: Dictionary) -> bool:
	var m = null
	for mm in Data.MAPS:
		if mm.id == d.get("map", ""):
			m = mm
	if m == null:
		return false
	new_game(m, d.get("diff", "normal"))
	wave = int(d.wave); money = int(d.money); lives = int(d.lives); freeplay = bool(d.freeplay)
	start_lives = int(d.get("start_lives", start_lives))
	item_uses = d.get("items", {}).duplicate()
	candy = bool(d.get("candy", false))
	for id in d.get("cleared", []):
		for o in obs:
			if o.id == int(id):
				_remove_obstacle(o)
				break
	for e in d.towers:
		if not Data.TOWERS.has(e.kind):
			continue
		var tw := Tower.new()
		tw.id = next_id; next_id += 1
		tw.kind = e.kind; tw.x = float(e.x); tw.y = float(e.y); tw.a = int(e.a); tw.b = int(e.b)
		tw.mode = e.mode; tw.pops = int(e.pops); tw.spent = int(e.spent); tw.born = t - 1
		tw.danced = int(e.get("danced", 0))
		_init_tower(tw)
		towers.append(tw)
	refresh_buffs()
	return true


func game_over() -> void:
	over = true
	running = false
	var reached := wave - 1
	var bk := Data.best_key(map.id, diff)
	if best.get(bk, 0) < reached:
		best[bk] = reached
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
