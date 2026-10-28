class_name Art
extends RefCounted
## Original vector drawings of every Pokémon and Pokéball, ported from the web
## version's canvas code. Drawings are recorded once per animation frame and
## cached, so the game only replays them.

const OUT := Pen.OUT
const ANIM_FPS := 12.0
const ANIM_FRAMES := 72

const SPRITE_INFO := {
	"pikachu": {"name": "Pikachu", "scale": .86}, "raichu": {"name": "Raichu", "scale": .9}, "gmax": {"name": "Gigantamax Pikachu", "scale": 1.14},
	"charmander": {"name": "Charmander", "scale": .86}, "charmeleon": {"name": "Charmeleon", "scale": .9}, "charizard": {"name": "Charizard", "scale": .96}, "megax": {"name": "Mega Charizard X", "scale": 1.04},
	"gastly": {"name": "Gastly", "scale": .92, "float": true}, "haunter": {"name": "Haunter", "scale": .92, "float": true}, "gengar": {"name": "Gengar", "scale": .98}, "megagengar": {"name": "Mega Gengar", "scale": 1.06, "float": true},
	"squirtle": {"name": "Squirtle", "scale": .86}, "wartortle": {"name": "Wartortle", "scale": .9}, "blastoise": {"name": "Blastoise", "scale": 1.0}, "megablastoise": {"name": "Mega Blastoise", "scale": 1.04},
	"bulbasaur": {"name": "Bulbasaur", "scale": .9}, "ivysaur": {"name": "Ivysaur", "scale": .94}, "venusaur": {"name": "Venusaur", "scale": 1.0}, "megavenusaur": {"name": "Mega Venusaur", "scale": 1.04},
	"meowth": {"name": "Meowth", "scale": .88}, "persian": {"name": "Persian", "scale": .94}, "wobbuffet": {"name": "Wobbuffet", "scale": .9},
	"mewtwo": {"name": "Mewtwo", "scale": .98}, "armormewtwo": {"name": "Armored Mewtwo", "scale": 1.0}, "megamewtwo": {"name": "Mega Mewtwo Y", "scale": 1.04},
	"ashpika": {"name": "Ash's Pikachu", "scale": .95},
}

static var _mon_cache := {}
static var _ball_cache := {}
static var _pen := Pen.new()


# ---------- cached access ----------
## Returns the recorded drawing of a Pokémon at time t, centred on its feet area.
const ANIMATED := ["gmax", "charmander", "charmeleon", "charizard", "megax", "gastly", "haunter", "megagengar", "venusaur", "megavenusaur", "wobbuffet", "mewtwo", "armormewtwo", "megamewtwo"]


static func mon(sp: String, t: float, opt := {}, alpha := 1.0) -> Array:
	var frame := posmod(int(floor(t * ANIM_FPS)), ANIM_FRAMES) if ANIMATED.has(sp) else 18
	alpha = snappedf(alpha, 0.05)
	var key := "%s|%d|%s|%s|%s|%s" % [sp, frame, opt.get("shades", false), opt.get("conf", 0.0) > 0.0, opt.get("amulet", false), alpha]
	if _mon_cache.has(key):
		return _mon_cache[key]
	var c := _pen
	c.clear()
	draw_mon(c, sp, frame / ANIM_FPS, opt)
	var out := Pen.bake(c.cmds, alpha)
	c.cmds = []
	_mon_cache[key] = out
	return out


## Draws a Pokémon onto a CanvasItem at (x, y).
static func put_mon(ci: CanvasItem, sp: String, x: float, y: float, scale: float, flip: bool, t: float, alpha := 1.0, opt := {}) -> void:
	ci.draw_set_transform(Vector2(x, y), 0.0, Vector2(-scale if flip else scale, scale))
	Pen.draw_baked(ci, mon(sp, t, opt, alpha))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func ball(type: String, alpha := 1.0) -> Array:
	alpha = snappedf(alpha, 0.05)
	var key := "%s|%s" % [type, alpha]
	if _ball_cache.has(key):
		return _ball_cache[key]
	var c := _pen
	c.clear()
	if type == "rocket":
		draw_balloon(c)
	else:
		draw_ball(c, type)
	var out := Pen.bake(c.cmds, alpha)
	c.cmds = []
	_ball_cache[key] = out
	return out


static func put_ball(ci: CanvasItem, type: String, x: float, y: float, rot := 0.0, scale := 1.0, alpha := 1.0) -> void:
	ci.draw_set_transform(Vector2(x, y), rot, Vector2(scale, scale))
	Pen.draw_baked(ci, ball(type, alpha))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------- helpers ----------
static func eye(c: Pen, x: float, y: float, r: float, col := "#1b1b22") -> void:
	c.ell(x, y, r, r * 1.15); c.fill(col)
	c.ell(x + r * .35, y - r * .45, r * .4, r * .4); c.fill("#fff")


static func flame(c: Pen, x: float, y: float, s: float, t: float, blue := false) -> void:
	var f := 1 + .14 * sin(t * 19 + x) + .06 * sin(t * 31)
	var o := "#3db5ff" if blue else "#ff7a1a"
	var m := "#9fe2ff" if blue else "#ffc23a"
	var i := "#ffffff" if blue else "#fff2a8"
	for kc in [[1.0, o], [.66, m], [.36, i]]:
		var k: float = kc[0]
		c.begin(); c.move_to(x, y - 11 * s * f * k)
		c.bez_to(x + 7 * s * k, y - 3 * s * k, x + 6 * s * k, y + 6 * s * k, x, y + 6 * s * k)
		c.bez_to(x - 6 * s * k, y + 6 * s * k, x - 7 * s * k, y - 3 * s * k, x, y - 11 * s * f * k)
		c.fill(kc[1])


static func bolt_shape(c: Pen, x: float, y: float, s: float) -> void:
	c.poly([[x, y], [x + 8 * s, y - 8 * s], [x + 5 * s, y - 10 * s], [x + 14 * s, y - 19 * s], [x + 11 * s, y - 21 * s], [x + 19 * s, y - 30 * s], [x + 7 * s, y - 23 * s], [x + 10 * s, y - 19 * s], [x + 1 * s, y - 12 * s], [x + 4 * s, y - 9 * s], [x - 3 * s, y - 3 * s]])


static func star(c: Pen, x: float, y: float, r: float, col) -> void:
	c.begin()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rr := r * .45 if i % 2 else r
		c.line_to(x + cos(a) * rr, y + sin(a) * rr)
	c.close()
	c.fill(col)


static func pika_face(c: Pen, cheek: String) -> void:
	eye(c, -5, -8, 2.4); eye(c, 5, -8, 2.4)
	c.ell(-9.3, -2, 3, 2.8); c.fill(cheek); c.ell(9.3, -2, 3, 2.8); c.fill(cheek)
	c.ell(0, -5, .9, .6); c.fill(OUT)
	c.begin(); c.move_to(-2.6, -3.2); c.quad_to(-1.3, -1.6, 0, -3.2); c.quad_to(1.3, -1.6, 2.6, -3.2); c.stroke(OUT, 1.1)


# ---------- Pokémon ----------
static func draw_mon(c: Pen, sp: String, t: float, opt := {}) -> void:
	var info: Dictionary = SPRITE_INFO[sp]
	var sc: float = info.scale
	var fl: bool = info.get("float", false)
	c.ell(0, 18 * sc, (9.0 if fl else 12.0) * sc, 3.4 * sc)
	c.fill(Color(0, 0, 0, .16 if fl else .26))
	c.save()
	c.scale(sc, sc)
	match sp:
		"pikachu": pikachu(c, t)
		"raichu": raichu(c, t)
		"gmax": gmax(c, t)
		"charmander": charmander(c, t)
		"charmeleon": charmeleon(c, t)
		"charizard": zard(c, t, false)
		"megax": zard(c, t, true)
		"gastly": gastly(c, t)
		"haunter": haunter(c, t)
		"gengar": gengar(c, t, false)
		"megagengar": gengar(c, t, true)
		"squirtle": turtle(c, t, opt, 0)
		"wartortle": turtle(c, t, opt, 1)
		"blastoise": turtle(c, t, opt, 2)
		"megablastoise": turtle(c, t, opt, 3)
		"bulbasaur": bulba(c, t, 0)
		"ivysaur": bulba(c, t, 1)
		"venusaur": bulba(c, t, 2)
		"megavenusaur": bulba(c, t, 3)
		"meowth": meowth(c, t, false, opt)
		"persian": meowth(c, t, true, opt)
		"wobbuffet": wobb(c, t, opt)
		"mewtwo": mewtwo(c, t, 0)
		"armormewtwo": mewtwo(c, t, 1)
		"megamewtwo": mewtwo(c, t, 2)
		"ashpika": ashpika(c, t)
	c.restore()


static func pikachu(c: Pen, _t: float) -> void:
	bolt_shape(c, 5, 8, .85); c.fs("#f7d02c")
	c.ell(5, 6, 2.6, 2.2); c.fs("#8f5f26", null)
	for s in [-1, 1]:
		c.save(); c.translate(s * 7, -14); c.rotate(s * .5)
		c.ell(0, -8, 3.6, 10); c.fs("#f7d02c")
		c.save(); c.ell(0, -8, 3.6, 10); c.clip(); c.ell(0, -17, 6, 5); c.fill("#1d1d1d"); c.restore()
		c.ell(0, -8, 3.6, 10); c.stroke(OUT, 1.4)
		c.restore()
	c.ell(-6, 17, 4.5, 2.6); c.fs("#f7d02c"); c.ell(6, 17, 4.5, 2.6); c.fs("#f7d02c")
	c.ell(0, 8, 11, 10); c.fs("#f7d02c")
	c.ell(-7, 6, 2.8, 4.2, .5); c.fs("#f7d02c"); c.ell(7, 6, 2.8, 4.2, -.5); c.fs("#f7d02c")
	c.ell(0, -6, 13, 11); c.fs("#f7d02c")
	pika_face(c, "#e3452c")


static func raichu(c: Pen, _t: float) -> void:
	c.begin(); c.move_to(6, 12); c.bez_to(22, 16, 28, 2, 24, -12); c.stroke("#2b1d14", 2.4, true)
	c.poly([[24, -12], [30, -18], [26, -19], [29, -26], [20, -18], [24, -17]]); c.fs("#f7d02c")
	for s in [-1, 1]:
		c.save(); c.translate(s * 9, -13); c.rotate(s * .85)
		c.ell(0, -7, 5.5, 9.5); c.fs("#7b4a24"); c.ell(0, -6, 3.2, 6.5); c.fs("#f2c43a", null)
		c.restore()
	c.ell(-6, 18, 5, 2.8); c.fs("#7b4a24"); c.ell(6, 18, 5, 2.8); c.fs("#7b4a24")
	c.ell(0, 8, 12, 11); c.fs("#e98a2c"); c.ell(0, 10, 7, 7); c.fs("#f6dfb0", null)
	c.ell(-8, 5, 3, 4.5, .5); c.fs("#e98a2c"); c.ell(8, 5, 3, 4.5, -.5); c.fs("#e98a2c")
	c.ell(0, -6, 13.5, 11); c.fs("#e98a2c")
	pika_face(c, "#f7d02c")


static func gmax(c: Pen, t: float) -> void:
	c.glow(12, -12, 26, Color("#fff38a"))
	bolt_shape(c, 3, 12, 1.45); c.fs("#fff6b8", "#f2b400", 1.6)
	var a0 := c.alpha
	c.alpha = a0 * .85
	for xyr in [[-10, -34, 7], [0, -38, 9], [10, -34, 7], [-3, -31, 7], [6, -31, 6]]:
		c.ell(xyr[0], xyr[1] + sin(t * 2 + xyr[0]) * 1, xyr[2], xyr[2] * .8); c.fs("#5d607a", null)
	c.alpha = a0
	if int(t * 3) % 4 == 0:
		c.begin(); c.move_to(-2, -30); c.line_to(-5, -24); c.line_to(-1, -24); c.line_to(-4, -18); c.stroke("#fff38a", 1.6)
	for s in [-1, 1]:
		c.save(); c.translate(s * 8, -15); c.rotate(s * .6)
		c.ell(0, -5, 3.6, 7); c.fs("#f7d02c")
		c.save(); c.ell(0, -5, 3.6, 7); c.clip(); c.ell(0, -12, 6, 4); c.fill("#1d1d1d"); c.restore()
		c.restore()
	c.ell(-7, 17, 5, 2.8); c.fs("#f7d02c"); c.ell(7, 17, 5, 2.8); c.fs("#f7d02c")
	c.ell(0, 7, 15, 12.5); c.fs("#f7d02c")
	c.ell(-10, 5, 3.2, 4.5, .5); c.fs("#f7d02c"); c.ell(10, 5, 3.2, 4.5, -.5); c.fs("#f7d02c")
	c.ell(0, -6, 14, 11.5); c.fs("#f7d02c")
	pika_face(c, "#e3452c")


static func ashpika(c: Pen, t: float) -> void:
	pikachu(c, t)
	c.ell(0, -12.5, 14.5, 2.6); c.fs("#e2262b")
	c.begin(); c.ellipse(0, -13, 12, 8, 0, PI, 0); c.close(); c.fs("#e2262b")
	c.begin(); c.ellipse(0, -14, 6, 5.4, 0, PI, 0); c.close(); c.fill("#fff")
	c.fill_rect(-1.6, -18, 1.4, 3.4, Color("#2c9a4a")); c.fill_rect(-1.6, -15.2, 3.4, 1.2, Color("#2c9a4a"))


static func charmander(c: Pen, t: float) -> void:
	c.begin(); c.move_to(6, 13); c.quad_to(19, 15, 18, 3); c.stroke(OUT, 6.4, true); c.stroke("#f2853a", 4, true)
	flame(c, 18, 0, .8, t)
	c.ell(-5, 17, 4, 2.5); c.fs("#f2853a"); c.ell(5, 17, 4, 2.5); c.fs("#f2853a")
	c.ell(0, 8, 9.5, 10.5); c.fs("#f2853a"); c.ell(0, 10, 6, 7); c.fs("#f7d98a", null)
	c.ell(-9, 4, 2.6, 4, .6); c.fs("#f2853a"); c.ell(9, 4, 2.6, 4, -.6); c.fs("#f2853a")
	c.ell(0, -8, 12, 11); c.fs("#f2853a")
	for s in [-1, 1]:
		c.ell(s * 4.6, -9, 2.3, 3.2); c.fill("#1b2a3e"); c.ell(s * 4.6 + .8, -10.2, .9, 1); c.fill("#fff")
	c.begin(); c.arc(0, -6, 4, .25 * PI, .75 * PI); c.stroke(OUT, 1.3)


static func charmeleon(c: Pen, t: float) -> void:
	c.begin(); c.move_to(6, 13); c.quad_to(22, 15, 20, 0); c.stroke(OUT, 7, true); c.stroke("#d9482c", 4.6, true)
	flame(c, 20, -4, 1.05, t)
	c.ell(-5, 18, 4.5, 2.6); c.fs("#d9482c"); c.ell(5, 18, 4.5, 2.6); c.fs("#d9482c")
	c.ell(0, 8, 10, 11); c.fs("#d9482c"); c.ell(0, 10, 6.4, 7.4); c.fs("#f5d38a", null)
	c.ell(-9.5, 4, 2.8, 4.4, .6); c.fs("#d9482c"); c.ell(9.5, 4, 2.8, 4.4, -.6); c.fs("#d9482c")
	c.poly([[3, -17], [12, -23], [8, -13]]); c.fs("#d9482c")
	c.ell(0, -8, 11.5, 10.5); c.fs("#d9482c")
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 1.5, -11); c.line_to(s * 8, -12.5); c.line_to(s * 7, -7.5); c.close(); c.fill("#fff")
		c.ell(s * 5.6, -9.8, 1.3, 1.6); c.fill("#1b2a3e")
	c.begin(); c.move_to(-4, -3.5); c.quad_to(0, -1.5, 4, -3.5); c.stroke(OUT, 1.3)


static func zard(c: Pen, t: float, mx: bool) -> void:
	var body := "#2f3342" if mx else "#f08a2c"
	var belly := "#7cc4ee" if mx else "#f7d98a"
	var wing := "#26a8ff" if mx else "#2f8fa8"
	var flap := sin(t * 4) * .08
	for s in [-1, 1]:
		c.save(); c.rotate(s * flap)
		c.poly([[s * 6, -4], [s * 31, -27], [s * 28, -13], [s * 34, -3], [s * 25, -1], [s * 27, 8], [s * 10, 6]]); c.fs(body)
		c.poly([[s * 9, -3], [s * 28, -22], [s * 25, -11], [s * 29, -3], [s * 22, -1], [s * 23, 5], [s * 11, 4]]); c.fs(wing, null)
		c.restore()
	c.begin(); c.move_to(6, 13); c.quad_to(24, 16, 23, -1); c.stroke(OUT, 7.4, true); c.stroke(body, 5, true)
	flame(c, 23, -5, 1.5 if mx else 1.25, t, mx)
	c.ell(-6, 19, 4.8, 2.8); c.fs(body); c.ell(6, 19, 4.8, 2.8); c.fs(body)
	c.ell(0, 8, 11, 12); c.fs(body); c.ell(0, 10, 7, 8); c.fs(belly, null)
	c.ell(-10, 4, 3, 4.6, .6); c.fs(body); c.ell(10, 4, 3, 4.6, -.6); c.fs(body)
	c.ell(0, -6, 5, 5); c.fs(body, null)
	for s in [-1, 1]:
		c.poly([[s * 3, -17], [s * (10 if mx else 8), -29], [s * 7, -15]]); c.fs(body)
	c.ell(0, -13, 9.5, 8); c.fs(body); c.ell(0, -9, 6.5, 4.2); c.fs(body)
	for s in [-1, 1]:
		c.ell(s * 4, -14, 1.7, 2); c.fill("#ff3b3b" if mx else "#1b2a3e"); c.ell(s * 4 + .5, -14.8, .6, .6); c.fill("#fff")
	c.ell(-2, -9, .7, .6); c.fill(OUT); c.ell(2, -9, .7, .6); c.fill(OUT)
	if mx:
		flame(c, -6, -7, .42, t * 1.3, true); flame(c, 6, -7, .42, t * 1.1, true)


static func gastly(c: Pen, t: float) -> void:
	var bob := sin(t * 2.2) * 2
	c.translate(0, bob - 2)
	for i in 8:
		var a := i / 8.0 * TAU + t * .8
		c.ell(cos(a) * 9, sin(a) * 9, 10 + 3 * sin(t * 3 + i), 9); c.fill(Color(170 / 255.0, 110 / 255.0, 220 / 255.0, .2))
	c.ell(0, 0, 11.5, 11.5); c.fill_fan(-3, -4, 14, Color("#4a3660"), Color("#130c1c")); c.ell(0, 0, 11.5, 11.5); c.stroke("#08040c", 1.4)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 1.8, -5.5); c.quad_to(s * 10, -10, s * 9.5, -2); c.quad_to(s * 5, -1, s * 1.8, -5.5); c.fill("#fff")
		c.ell(s * 6.2, -3.8, 1.4, 1.4); c.fill("#111")
	c.begin(); c.move_to(-7, 2); c.quad_to(0, 10, 7, 2); c.quad_to(0, 5, -7, 2); c.fill("#5a1638")
	for s in [-1, 1]:
		c.poly([[s * 2, 3.4], [s * 4.6, 3.4], [s * 3.3, 6]]); c.fill("#fff")


static func haunter(c: Pen, t: float) -> void:
	var bob := sin(t * 2) * 2
	c.translate(0, bob - 3)
	c.begin(); c.move_to(-12, -2)
	for p in [[-15, -11], [-9, -9], [-9, -18], [-3, -12], [0, -21], [3, -12], [9, -18], [9, -9], [15, -11], [12, -2]]:
		c.line_to(p[0], p[1])
	c.quad_to(11, 10, 3, 14); c.quad_to(0, 10, -2, 19); c.quad_to(-7, 12, -11, 8); c.quad_to(-13, 4, -12, -2); c.close()
	c.fs("#6a4aa6", "#2a1640")
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 1.5, -6); c.quad_to(s * 9, -11, s * 9.5, -3); c.quad_to(s * 5, -2, s * 1.5, -6); c.fill("#fff")
		c.ell(s * 6, -4.6, 1.4, 1.6); c.fill("#111")
	c.begin(); c.move_to(-7, 1); c.quad_to(0, 10, 7, 1); c.quad_to(0, 4, -7, 1); c.fill("#2a1240")
	c.ell(0, 5.5, 2.4, 1.6); c.fill("#ff7fb0")
	for s in [-1, 1]:
		var hx = s * (21 + sin(t * 3) * 2)
		var hy := -1 + cos(t * 3 + s) * 3
		c.ell(hx, hy, 4.2, 3.6); c.fs("#6a4aa6", "#2a1640", 1.2)
		for f in [-1, 0, 1]:
			c.ell(hx + f * 2.6, hy - 4, 1.3, 2.4, f * .3); c.fs("#6a4aa6", "#2a1640", 1)


static func gengar(c: Pen, t: float, mega: bool) -> void:
	var bob := sin(t * 2) * 1.5 if mega else 0.0
	var body := "#3f2a66" if mega else "#6c4c9e"
	var dk := "#160b26" if mega else "#2a1846"
	if mega:
		c.ell(0, 15, 19, 5); c.fs("#12081f", "#9a6ad8", 1.6)
		c.save()
		c.glow(0, -6, 30, Color("#b07aff"))
	c.translate(0, bob - (4.0 if mega else 0.0))
	var spikes: Array = [[-13, 4]]
	var n := 11 if mega else 9
	for i in n + 1:
		var a := PI * (1.05 + .9 * i / n)
		var r := (22.0 if mega else 18.0) if i % 2 else 13.0
		spikes.append([cos(a) * r, sin(a) * r + 1])
	spikes.append([13, 4])
	c.poly(spikes); c.fs(body, dk)
	for s in [-1, 1]:
		c.poly([[s * 5, -9], [s * 14, -25], [s * 13, -7]]); c.fs(body, dk)
	if mega:
		c.restore()
	if not mega:
		c.ell(-7, 13, 4.8, 2.6); c.fs(body, dk); c.ell(7, 13, 4.8, 2.6); c.fs(body, dk)
	c.ell(0, 1, 14.5, 13); c.fs(body, dk)
	c.ell(-13.5, 3, 3.6, 4.8, .4); c.fs(body, dk); c.ell(13.5, 3, 3.6, 4.8, -.4); c.fs(body, dk)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 2, -4.5); c.line_to(s * 10.5, -8); c.quad_to(s * 10.5, -1.5, s * 3, -1.6); c.close(); c.fill("#fff")
		c.ell(s * 6.6, -4, 1.9, 1.9); c.fill("#e2262b"); c.ell(s * 6.6, -4, .8, .8); c.fill("#111")
	if mega:
		c.ell(0, -10, 2.2, 3.2); c.fill("#ffd23f"); c.ell(0, -10, 1, 1.8); c.fill("#e2262b")
	c.begin(); c.move_to(-9.5, 2); c.quad_to(0, 13, 9.5, 2); c.quad_to(0, 5.5, -9.5, 2); c.close(); c.fill("#fbfbfb"); c.stroke(dk, 1)
	c.begin()
	for x in [-5.0, -2.5, 0.0, 2.5, 5.0]:
		c.move_to(x, 3.6 + absf(x) * -.18); c.line_to(x, 8.4 - absf(x) * .55)
	c.stroke("#9a8fae", .7)


static func turtle(c: Pen, _t: float, o: Dictionary, st: int) -> void:
	var skin: String = ["#7cc6ea", "#7f9ee8", "#5d86d6", "#4f74c4"][st]
	var shell := "#a5672f"
	var rim := "#f3ead0"
	var belly := "#f1d98c"
	if st == 1:
		c.ell(14, 11, 7, 5, .5); c.fs("#eef2ff", "#8a96b8"); c.ell(17, 7, 4, 3, .8); c.fs("#eef2ff", "#8a96b8")
	else:
		c.begin(); c.move_to(8, 14); c.quad_to(19, 16, 16, 7); c.quad_to(12, 5, 13, 10); c.stroke(OUT, 5, true); c.stroke(skin, 3, true)
	c.ell(0, 8, 12.5 + st, 11.5 + st * .5); c.fs(shell); c.ell(0, 8, 11 + st, 10 + st * .5); c.fs(rim, null)
	if st == 2:
		for s in [-1, 1]:
			c.save(); c.translate(s * 12, -3); c.rotate(s * .5)
			c.begin(); c.rect(-3, -11, 6, 12); c.fs("#b9c0c9"); c.ell(0, -11, 3, 1.4); c.fs("#3a3f48")
			c.restore()
	if st == 3:
		c.begin(); c.rect(-5, -31, 10, 15); c.fs("#b9c0c9"); c.ell(0, -31, 5, 2); c.fs("#3a3f48")
		for s in [-1, 1]:
			c.begin(); c.rect(s * 15 - 3, 2, 6, 10); c.fs("#b9c0c9"); c.ell(s * 15, 12, 3, 1.3); c.fs("#3a3f48")
	c.ell(-6, 18, 4.5, 2.6); c.fs(skin); c.ell(6, 18, 4.5, 2.6); c.fs(skin)
	c.ell(0, 9, 9.5, 10); c.fs(skin); c.ell(0, 10, 7, 8); c.fs(belly, "#b89a4a", 1)
	c.begin(); c.move_to(-6, 7); c.line_to(6, 7); c.move_to(-6.5, 11); c.line_to(6.5, 11); c.stroke("#b89a4a", .9)
	c.ell(-9.5, 5, 2.8, 4.2, .6); c.fs(skin); c.ell(9.5, 5, 2.8, 4.2, -.6); c.fs(skin)
	if st == 1:
		for s in [-1, 1]:
			c.save(); c.translate(s * 10, -14); c.rotate(s * .7); c.ell(0, -4, 3.5, 7); c.fs("#eef2ff", "#8a96b8"); c.restore()
	if st >= 2:
		for s in [-1, 1]:
			c.poly([[s * 5, -16], [s * 9, -21], [s * 10, -14]]); c.fs(skin)
	c.ell(0, -8, 11.0 if st >= 2 else 12.0, 9.5 if st >= 2 else 10.5); c.fs(skin)
	for s in [-1, 1]:
		if st < 2:
			c.ell(s * 4.6, -9, 2.3, 3.1); c.fill("#6b2b1d"); c.ell(s * 4.6 + .8, -10.2, .9, 1); c.fill("#fff")
		else:
			c.begin(); c.move_to(s * 2, -11); c.line_to(s * 7.5, -12); c.line_to(s * 6.5, -8); c.close(); c.fill("#fff")
			c.ell(s * 5.2, -9.8, 1.2, 1.4); c.fill("#6b2b1d")
	c.begin(); c.arc(0, -5.5, 3.6, .2 * PI, .8 * PI); c.stroke(OUT, 1.2)
	if o.get("shades", false):
		c.begin(); c.move_to(-11, -12); c.line_to(11, -12); c.line_to(10, -9); c.quad_to(6, -5.5, 2, -9); c.line_to(-2, -9); c.quad_to(-6, -5.5, -10, -9); c.close(); c.fill("#111")
		c.fill_rect(-8, -11, 3, 1.2, Color(1, 1, 1, .55)); c.fill_rect(4, -11, 3, 1.2, Color(1, 1, 1, .55))


static func bulba(c: Pen, t: float, st: int) -> void:
	var skin: String = ["#7ccdb0", "#6fbfa6", "#5aa68f", "#4f9a85"][st]
	var spot := "#3f8d78"
	if st == 0:
		c.ell(0, -5, 10, 9); c.fs("#5fb24f", "#2e6b2a")
		c.begin(); c.move_to(0, -14); c.line_to(0, 2); c.move_to(-6, -11); c.quad_to(-3, -4, -2, 1); c.move_to(6, -11); c.quad_to(3, -4, 2, 1); c.stroke("#2e6b2a", 1)
	if st == 1:
		for s in [-1, 1]:
			c.ell(s * 12, -5, 10, 4.5, s * -.4); c.fs("#4fa84a", "#2e6b2a")
		c.ell(0, -11, 7, 8); c.fs("#f08bb0", "#9a3d63"); c.ell(-1.5, -15, 2.4, 2.4); c.fill("#f9c4d8")
	if st >= 2:
		var k := 1.22 if st == 3 else 1.0
		var sw := sin(t * 2) * .05
		for s in [-1, 1]:
			c.ell(s * 16 * k, -1, 12 * k, 5, s * -.25 + sw); c.fs("#3f9a45", "#22602a")
		for i in 5:
			var a := -PI / 2 + (i - 2) * .62
			c.ell(cos(a) * 10 * k, -10 + sin(a) * 7 * k, 7 * k, 4.5 * k, a); c.fs("#f07a92", "#9a3d4f")
			c.ell(cos(a) * 11 * k, -10 + sin(a) * 8 * k, 1.4, 1.4); c.fill("#fff")
		c.ell(0, -11, 4 * k, 3 * k); c.fs("#ffd23f" if st == 3 else "#f6b8c4", "#9a3d4f")
	for s in [-1, 1]:
		c.ell(s * 10, 15, 4.5, 3); c.fs(skin); c.ell(s * 5, 17, 4, 2.6); c.fs(skin)
	c.ell(0, 8, 13 + st, 8.5); c.fs(skin)
	for s in [-1, 1]:
		c.poly([[s * 6, -2], [s * 12, -6], [s * 11, 2]]); c.fs(skin)
	c.ell(0, 4, 11.5, 8.5); c.fs(skin)
	for xyr in [[-6, -.5, 1.8], [5, -1.5, 1.4], [8, 5, 1.2]]:
		c.ell(xyr[0], xyr[1], xyr[2], xyr[2] * .8); c.fill(spot)
	for s in [-1, 1]:
		c.ell(s * 5, 4, 2.4, 2.2); c.fill("#fff"); c.ell(s * 5.2, 4.3, 1.5, 1.6); c.fill("#c0303a"); c.ell(s * 5.2, 4.4, .6, .8); c.fill("#111")
	c.begin(); c.move_to(-4, 8); c.quad_to(0, 10.5, 4, 8); c.stroke(OUT, 1.2)
	if st == 3:
		for i in 4:
			var a := i / 4.0 * TAU
			c.ell(cos(a) * 2.2, -2 + sin(a) * 2.2, 1.8, 1.8); c.fill("#f07a92")
		c.ell(0, -2, 1.1, 1.1); c.fill("#ffd23f")


static func meowth(c: Pen, _t: float, per: bool, o: Dictionary) -> void:
	var fur := "#efe0b8" if per else "#f4e3b0"
	var dark := "#7a5a3a"
	c.begin(); c.move_to(7, 14); c.bez_to(20, 16, 23, 0, 14, -4); c.stroke(OUT, 4.4 if per else 3.8, true); c.stroke(fur, 2.8 if per else 2.2, true)
	c.ell(14, -4, 2.6, 2.6); c.fs(fur if per else dark)
	c.ell(-5, 18, 4, 2.4); c.fs(fur if per else dark); c.ell(5, 18, 4, 2.4); c.fs(fur if per else dark)
	c.ell(0, 9, 7.5 if per else 8.0, 9.0 if per else 10.0); c.fs(fur)
	c.ell(-7, 6, 2.4, 4, .5); c.fs(fur); c.ell(7, 6, 2.4, 4, -.5); c.fs(fur)
	for s in [-1, 1]:
		c.poly([[s * 4, -15], [s * 13, -24], [s * 12, -10]]); c.fs(fur)
		c.poly([[s * 6, -15], [s * 11.5, -21], [s * 11, -12]]); c.fill("#e8a0a0" if per else "#2a1d18")
	c.ell(0, -8, 13.5 if per else 12.0, 9.5 if per else 10.5); c.fs(fur)
	if per:
		c.ell(0, -15, 2.6, 3); c.fs("#e2262b", "#7a1010", 1); c.ell(-.7, -16, .8, .8); c.fill("#fff")
	else:
		c.ell(0, -15, 3.2, 3.8); c.fs("#ffd23f", "#9a7414", 1.2); c.fill_rect(-1, -16.4, 2, 2.6, Color("#9a7414"))
	for s in [-1, 1]:
		c.ell(s * 4.8, -9, 2.5, 2.9); c.fs("#fff", OUT, 1); c.ell(s * 4.8, -9, .7, 2.5); c.fill("#2a6a3a" if per else "#111")
	c.begin()
	for s in [-1, 1]:
		for k in ([-1, 1] if per else [-1, 0, 1]):
			c.move_to(s * 8, -4 + k * 1.5); c.line_to(s * (24 if per else 17), -6 + k * 3.2)
	c.stroke(OUT, .8)
	c.begin(); c.move_to(-2.6, -3.6); c.quad_to(-1.3, -2, 0, -3.6); c.quad_to(1.3, -2, 2.6, -3.6); c.stroke(OUT, 1.1)
	c.poly([[-2.2, -3.2], [-1.6, -1.6], [-1, -3]]); c.fill("#fff")
	if o.get("amulet", false):
		c.glow(0, 3, 10, Color("#ffd23f"))
		c.ell(0, 3, 2.8, 3.4); c.fs("#ffd23f", "#9a7414", 1)


static func wobb(c: Pen, t: float, o: Dictionary) -> void:
	var conf: bool = o.get("conf", 0.0) > 0.0
	if conf:
		c.rotate(sin(t * 14) * .18)
	c.begin(); c.move_to(6, 15); c.quad_to(18, 19, 18, 9); c.stroke("#111", 4, true)
	c.ell(19, 5, 4.8, 4.2); c.fs("#16161a", "#000")
	for e in [-1.7, 1.7]:
		c.ell(19 + e, 4.6, 1.2, 1.3); c.fill("#fff")
	c.save()
	var sq := 1 + sin(t * 3) * .04
	c.scale(1 / sq, sq)
	c.begin(); c.move_to(-11, 18); c.bez_to(-14, -8, -10, -25, 0, -25); c.bez_to(10, -25, 14, -8, 11, 18); c.close(); c.fs("#5aa6e8", "#1f4a7a")
	c.ell(-11.5, 3, 2.6, 8, .12); c.fs("#5aa6e8", "#1f4a7a"); c.ell(11.5, 3, 2.6, 8, -.12); c.fs("#5aa6e8", "#1f4a7a")
	if conf:
		for s in [-1, 1]:
			c.begin()
			for i in 14:
				var a := i * .7 + t * 10
				var r := .3 + i * .18
				c.line_to(s * 4.5 + cos(a) * r, -13 + sin(a) * r)
			c.stroke("#1f2a44", 1.4)
	else:
		for s in [-1, 1]:
			c.begin(); c.move_to(s * 2.4, -13); c.line_to(s * 6.6, -13); c.stroke("#1f2a44", 1.4)
	c.ell(0, -6.5, 3.8, 1.6); c.fs("#e86a8a", "#a03050", 1)
	c.restore()
	c.ell(-5, 18, 4, 2); c.fs("#5aa6e8", "#1f4a7a"); c.ell(5, 18, 4, 2); c.fs("#5aa6e8", "#1f4a7a")
	if conf:
		for i in 3:
			var a := t * 6 + i * TAU / 3
			star(c, cos(a) * 13, -29 + sin(a) * 3, 3.4, "#ffd23f")


static func mewtwo(c: Pen, t: float, form: int) -> void:
	var skin := "#d8cfe2"
	var pur := "#9a62c4"
	c.save(); c.alpha *= .22 + .1 * sin(t * 3); c.ell(0, -2, 21, 27); c.fill("#ff9ad6" if form == 2 else "#a6c8ff"); c.restore()
	c.begin(); c.move_to(4, 12); c.bez_to(22, 18, 27, 0, 18, -8); c.stroke(OUT, 7, true); c.stroke(pur, 5, true)
	for s in [-1, 1]:
		c.ell(s * 5, 13, 3.4, 6); c.fs(skin); c.ell(s * 5.5, 19.5, 4, 2); c.fs(skin)
	c.ell(0, 3, 7.5, 10); c.fs(skin); c.ell(0, 9, 6, 4.5); c.fs(pur, null)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 6, -3); c.quad_to(s * 14, 2, s * 13, 9); c.stroke(OUT, 4.6, true); c.stroke(skin, 3, true)
		c.ell(s * 13, 10, 2.3, 2.3); c.fs(skin)
	c.begin(); c.move_to(3, -14); c.quad_to(10, -11, 4, -6); c.stroke(OUT, 3, true); c.stroke(skin, 1.8, true)
	if form == 2:
		c.begin(); c.move_to(0, -17); c.bez_to(10, -23, 18, -27, 25, -19); c.stroke(OUT, 4.4, true); c.stroke(pur, 3, true)
		c.ell(0, -14, 5.5, 5); c.fs(skin)
		for s in [-1, 1]:
			c.ell(s * 3.5, -19, 1.4, 2.6, s * .3); c.fs(skin)
	else:
		for s in [-1, 1]:
			c.ell(s * 5, -19, 2.2, 3, s * .4); c.fs(skin)
		c.ell(0, -14, 7, 6); c.fs(skin)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 1.2, -15); c.line_to(s * (4.4 if form == 2 else 5.2), -16.2); c.line_to(s * (3.8 if form == 2 else 4.6), -13.4); c.close(); c.fill("#7a2fb0")
	if form == 1:
		c.begin(); c.arc(0, -14, 7.9, PI * 1.02, PI * 1.98); c.line_to(6.8, -16.6); c.line_to(-6.8, -16.6); c.close(); c.fs("#8b93a3", "#3b414d")
		c.ell(0, 1, 8, 5.5); c.fs("#8b93a3", "#3b414d")
		c.fill_rect(-5, -.5, 10, 1.5, Color("#c7ccd6"))
		for s in [-1, 1]:
			c.ell(s * 7, -4, 3, 2.4); c.fs("#8b93a3", "#3b414d")


# ---------- Pokéballs ----------
static func draw_ball(c: Pen, type: String) -> void:
	var b: Dictionary = Data.BALLS[type]
	var r: float = b.r
	var a := r
	c.save()
	c.begin(); c.arc(0, 0, r); c.clip()
	c.fill_rect(-r, -r, 2 * r, 2 * r, Color("#f6f6f2"))
	c.fill_rect(-r, -r, 2 * r, r, Color(b.top))
	match type:
		"great":
			for s in [-1, 1]:
				c.begin(); c.ellipse(s * a * .55, -a * .5, a * .28, a * .42, s * .6); c.fill("#e3350d")
		"ultra":
			for s in [-1, 1]:
				c.fill_rect(a * .32 if s > 0 else -a * .72, -a, a * .4, a * .95, Color("#f4c21b"))
			c.fill_rect(-a * .32, -a, a * .64, a * .4, Color("#232328"))
		"quick":
			for ang in [-2.4, -1.57, -.74]:
				c.save(); c.rotate(ang + PI / 2)
				c.begin(); c.move_to(-a * .3, -a); c.line_to(a * .3, -a); c.line_to(0, -a * .45); c.close(); c.fill("#f6d43a")
				c.restore()
			c.fill_rect(-a, -a * .32, 2 * a, a * .12, Color("#f6d43a"))
		"dusk":
			c.begin(); c.arc(0, 0, a * .62, PI * 1.12, PI * 1.88); c.stroke("#f08a24", a * .12)
			c.fill_rect(-a, -a * .3, 2 * a, a * .18, Color("#173020"))
			c.begin(); c.arc(0, -a * .62, a * .12); c.fill("#f08a24")
		"heavy":
			c.fill_rect(-a, -a * .42, 2 * a, a * .24, Color("#2c5aa0"))
			c.fill_rect(-a, -a, 2 * a, a * .3, Color("#6d7888"))
		"master":
			for s in [-1, 1]:
				c.begin(); c.arc(s * a * .52, -a * .52, a * .2); c.fill("#e85aa8")
	c.begin(); c.ellipse(-a * .38, -a * .55, a * .28, a * .16, -.6); c.fill(Color(1, 1, 1, .28))
	c.fill_rect(-r, -r * .12, 2 * r, r * .24, Color("#16161a"))
	c.restore()
	if type == "master":
		c.text("M", 0, -a * .56, a * .62, Color.WHITE, true, 1)
	c.begin(); c.arc(0, 0, r * .34); c.fill("#16161a")
	c.begin(); c.arc(0, 0, r * .22); c.fill("#fbfbf8")
	c.begin(); c.arc(0, 0, r); c.stroke("#16161a", 1.6)


static func draw_balloon(c: Pen) -> void:
	var r: float = Data.BALLS.rocket.r
	c.begin(); c.move_to(-r * .6, r * .75); c.line_to(-10, r + 18); c.move_to(r * .6, r * .75); c.line_to(10, r + 18); c.stroke("#4a3a2a", 1.2)
	c.begin(); c.round_rect(-14, r + 16, 28, 16, 3); c.fill("#9a6a3a"); c.stroke("#4a3020", 1.2)
	c.fill_rect(-14, r + 21, 28, 2, Color("#7a5028")); c.fill_rect(-14, r + 26, 28, 2, Color("#7a5028"))
	c.ell(0, r + 24, 5, 5); c.fs("#fff", "#e2262b", 1.4)
	c.text("R", 0, r + 24.5, 8, Color("#e2262b"), false, 1)
	for s in [-1, 1]:
		c.poly([[s * r * .35, -r * .8], [s * r * .95, -r * 1.15], [s * r * .85, -r * .3]]); c.fs("#f4e3b0")
		c.poly([[s * r * .45, -r * .75], [s * r * .85, -r * 1.0], [s * r * .78, -r * .42]]); c.fill("#2a1d18")
	c.ell(0, 0, r, r * .92); c.fs("#f4e3b0", OUT, 1.8)
	c.ell(-r * .4, -r * .45, r * .3, r * .18, -.5); c.fill(Color(1, 1, 1, .3))
	c.ell(0, -r * .55, r * .2, r * .24); c.fs("#ffd23f", "#9a7414", 1.2)
	for s in [-1, 1]:
		c.ell(s * r * .32, -r * .12, r * .16, r * .2); c.fs("#fff", OUT, 1.2)
		c.ell(s * r * .32, -r * .1, r * .05, r * .17); c.fill("#111")
	c.begin()
	for s in [-1, 1]:
		for k in [-1, 0, 1]:
			c.move_to(s * r * .5, r * .18 + k * 3); c.line_to(s * r * 1.15, r * .1 + k * 7)
	c.stroke(OUT, 1)
	c.begin(); c.move_to(-r * .25, r * .3); c.quad_to(-r * .12, r * .42, 0, r * .3); c.quad_to(r * .12, r * .42, r * .25, r * .3); c.stroke(OUT, 1)
	c.poly([[-r * .15, r * .33], [-r * .1, r * .45], [-r * .05, r * .35]]); c.fill("#fff")


static func coin(c: CanvasItem, x: float, y: float, r: float, ph: float, a := 1.0) -> void:
	var sx := maxf(.15, absf(cos(ph)))
	c.draw_set_transform(Vector2(x, y), 0, Vector2(sx, 1))
	var pts := PackedVector2Array()
	for i in 16:
		var ang := TAU * i / 16.0
		pts.append(Vector2(cos(ang) * r, sin(ang) * r * 1.2))
	c.draw_colored_polygon(pts, Color(1, .81, .2, a))
	pts.append(pts[0])
	c.draw_polyline(pts, Color(.66, .48, .07, a), 1.2, true)
	c.draw_rect(Rect2(-r * .5, -r * .6, r * .25, r * .5), Color(1, 1, 1, .6 * a))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
