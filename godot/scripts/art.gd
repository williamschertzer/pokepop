class_name Art
extends RefCounted
## Caches and places the Pokémon drawings (see Mons) and draws the Pokéballs.
## Drawings are recorded once per animation frame and cached, so the game only
## replays them.

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
	"magikarp": {"name": "Magikarp", "scale": .9}, "gyarados": {"name": "Gyarados", "scale": 1.0}, "megagyarados": {"name": "Mega Gyarados", "scale": 1.06},
	"pidgey": {"name": "Pidgey", "scale": .86}, "pidgeotto": {"name": "Pidgeotto", "scale": .92}, "pidgeot": {"name": "Pidgeot", "scale": 1.0}, "megapidgeot": {"name": "Mega Pidgeot", "scale": 1.04},
	"geodude": {"name": "Geodude", "scale": .9, "float": true}, "graveler": {"name": "Graveler", "scale": .96}, "golem": {"name": "Golem", "scale": 1.02},
	"machop": {"name": "Machop", "scale": .86}, "machoke": {"name": "Machoke", "scale": .94}, "machamp": {"name": "Machamp", "scale": 1.0}, "gmaxmachamp": {"name": "Gigantamax Machamp", "scale": 1.06},
	"abra": {"name": "Abra", "scale": .88}, "kadabra": {"name": "Kadabra", "scale": .94}, "alakazam": {"name": "Alakazam", "scale": .98}, "megaalakazam": {"name": "Mega Alakazam", "scale": 1.02, "float": true},
	"lapras": {"name": "Lapras", "scale": 1.0}, "gmaxlapras": {"name": "Gigantamax Lapras", "scale": 1.06},
	"snorlax": {"name": "Snorlax", "scale": 1.0}, "gmaxsnorlax": {"name": "Gigantamax Snorlax", "scale": 1.08},
	"dratini": {"name": "Dratini", "scale": .9}, "dragonair": {"name": "Dragonair", "scale": .98}, "dragonite": {"name": "Dragonite", "scale": 1.02},
	"eevee": {"name": "Eevee", "scale": .86}, "vaporeon": {"name": "Vaporeon", "scale": .96}, "jolteon": {"name": "Jolteon", "scale": .94}, "flareon": {"name": "Flareon", "scale": .94},
	"ditto": {"name": "Ditto", "scale": .9},
	"chansey": {"name": "Chansey", "scale": .92}, "blissey": {"name": "Blissey", "scale": 1.0},
}

static var _mon_cache := {}
static var _ball_cache := {}
static var _pen := Pen.new()


# ---------- cached access ----------
## Returns the recorded drawing of a Pokémon at time t, centred on its feet area.
const ANIMATED := ["gmax", "charmander", "charmeleon", "charizard", "megax", "gastly", "haunter", "megagengar", "venusaur", "megavenusaur", "wobbuffet", "mewtwo", "armormewtwo", "megamewtwo",
	"magikarp", "megagyarados", "pidgey", "pidgeotto", "pidgeot", "megapidgeot", "geodude", "gmaxmachamp", "megaalakazam", "gmaxlapras", "dragonair",
	"raichu", "meowth", "persian", "wartortle", "ivysaur", "gyarados", "abra", "kadabra", "alakazam", "lapras", "snorlax", "gmaxsnorlax", "dratini", "dragonite",
	"ditto", "vaporeon", "flareon", "eevee", "chansey", "blissey"]


static func mon(sp: String, t: float, opt := {}, alpha := 1.0) -> Array:
	var frame := posmod(int(floor(t * ANIM_FPS)), ANIM_FRAMES) if ANIMATED.has(sp) else 18
	alpha = snappedf(alpha, 0.05)
	var key := "%s|%d|%s|%s|%s|%s|%s" % [sp, frame, opt.get("shades", false), opt.get("conf", 0.0) > 0.0, opt.get("amulet", false), opt.get("sleep", false), alpha]
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


# ---------- Pokémon ----------
static func draw_mon(c: Pen, sp: String, t: float, opt := {}) -> void:
	var info: Dictionary = SPRITE_INFO[sp]
	var sc: float = info.scale
	var fl: bool = info.get("float", false)
	c.ell(0, 18 * sc, (9.0 if fl else 12.0) * sc, 3.4 * sc)
	c.fill(Color(0, 0, 0, .16 if fl else .26))
	c.save()
	c.scale(sc, sc)
	Mons.draw(c, sp, t, opt)
	c.restore()


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
		"timer":
			for x in [-.7, 0.0, .7]:
				c.fill_rect(a * x - a * .1, -a, a * .2, a * .9, Color("#1b1b22"))
			c.fill_rect(-a, -a * .45, 2 * a, a * .14, Color("#e3350d"))
		"net":
			c.begin()
			for x in [-.6, -.2, .2, .6]:
				c.move_to(a * x, -a); c.line_to(a * x, 0)
			for y in [-.7, -.35]:
				c.move_to(-a, a * y); c.line_to(a, a * y)
			c.stroke("#123c44", a * .08)
		"heal":
			c.fill_rect(-a, -a * .36, 2 * a, a * .18, Color("#ffd6e6"))
			c.fill_rect(-a * .1, -a * .9, a * .2, a * .5, Color("#ffffff"))
			c.fill_rect(-a * .25, -a * .75, a * .5, a * .2, Color("#ffffff"))
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
