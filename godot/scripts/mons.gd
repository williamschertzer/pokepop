class_name Mons
extends RefCounted
## Hand-drawn Pokémon. Every species and form has a drawing of its own, made
## from shaded parts (Pen.sh: fill, shadow, rim light, outline). Sprites face
## right, stand with their feet around y = 18 and fit roughly in ±30 × -40..20.

const OUT := Pen.OUT
const CREAM := "#f6e3b4"
const INK := "#1b1b22"

const DRAW := {
	"pikachu": "pikachu", "raichu": "raichu", "gmax": "gmax_pikachu", "ashpika": "ash_pikachu",
	"charmander": "charmander", "charmeleon": "charmeleon", "charizard": "charizard", "megax": "mega_charizard_x",
	"gastly": "gastly", "haunter": "haunter", "gengar": "gengar", "megagengar": "mega_gengar",
	"squirtle": "squirtle", "wartortle": "wartortle", "blastoise": "blastoise", "megablastoise": "mega_blastoise",
	"bulbasaur": "bulbasaur", "ivysaur": "ivysaur", "venusaur": "venusaur", "megavenusaur": "mega_venusaur",
	"meowth": "meowth", "persian": "persian", "wobbuffet": "wobbuffet",
	"mewtwo": "mewtwo", "armormewtwo": "armored_mewtwo", "megamewtwo": "mega_mewtwo_y",
	"magikarp": "magikarp", "gyarados": "gyarados", "megagyarados": "mega_gyarados",
	"pidgey": "pidgey", "pidgeotto": "pidgeotto", "pidgeot": "pidgeot", "megapidgeot": "mega_pidgeot",
	"geodude": "geodude", "graveler": "graveler", "golem": "golem",
	"machop": "machop", "machoke": "machoke", "machamp": "machamp", "gmaxmachamp": "gmax_machamp",
	"abra": "abra", "kadabra": "kadabra", "alakazam": "alakazam", "megaalakazam": "mega_alakazam",
	"lapras": "lapras", "gmaxlapras": "gmax_lapras", "snorlax": "snorlax", "gmaxsnorlax": "gmax_snorlax",
	"dratini": "dratini", "dragonair": "dragonair", "dragonite": "dragonite",
	"eevee": "eevee", "vaporeon": "vaporeon", "jolteon": "jolteon", "flareon": "flareon",
	"ditto": "ditto", "chansey": "chansey", "blissey": "blissey",
}


static func draw(c: Pen, sp: String, t: float, opt: Dictionary) -> void:
	Callable(Mons, DRAW[sp]).call(c, t, opt)


# ---------- helpers ----------
## Glossy round eye with one catchlight.
static func eye(c: Pen, x: float, y: float, rx: float, ry: float, col := INK) -> void:
	c.ell(x, y, rx, ry); c.fill(col)
	c.ell(x + rx * .3, y - ry * .38, rx * .42, ry * .36); c.fill("#fff")
	c.ell(x - rx * .3, y + ry * .45, rx * .2, ry * .16); c.fill(Color(1, 1, 1, .55))


## Eye with white sclera and a coloured iris, angled by `tilt` (positive frowns).
static func eye_iris(c: Pen, x: float, y: float, w: float, h: float, iris, tilt := 0.0) -> void:
	c.begin(); c.move_to(x - w, y - h * .2 + tilt); c.quad_to(x, y - h * 1.3 - absf(tilt) * .4, x + w, y - h * .2 - tilt)
	c.quad_to(x, y + h * 1.1, x - w, y - h * .2 + tilt); c.close(); c.fs("#fff", OUT, 1)
	c.ell(x + w * .25, y, w * .42, h * .62); c.fill(iris)
	c.ell(x + w * .3, y, w * .2, h * .36); c.fill(INK)
	c.ell(x + w * .42, y - h * .3, w * .14, h * .16); c.fill("#fff")


## A limb or tail drawn as a thick outlined stroke along the current path.
static func limb(c: Pen, col, w: float) -> void:
	c.stroke(OUT, w + 2.6, true); c.stroke(col, w, true)


static func blush(c: Pen, x: float, y: float, r: float, col) -> void:
	c.ell(x, y, r, r * .85); c.fs(col, Color(OUT, .55), .9)
	c.ell(x - r * .3, y - r * .3, r * .3, r * .22); c.fill(Color(1, 1, 1, .35))


static func flame(c: Pen, x: float, y: float, s: float, t: float, blue := false) -> void:
	var f := 1 + .16 * sin(t * 19 + x) + .07 * sin(t * 31)
	var lean := sin(t * 11 + y) * 1.5 * s
	var cols := ["#3db5ff", "#9fe2ff", "#ffffff"] if blue else ["#ff6a1a", "#ffc23a", "#fff6b8"]
	c.glow(x, y - 3 * s, 13 * s, Color(cols[0]))
	for i in 3:
		var k: float = [1.0, .68, .38][i]
		c.begin(); c.move_to(x + lean * k, y - 13 * s * f * k)
		c.bez_to(x + 8 * s * k, y - 4 * s * k, x + 7 * s * k, y + 6 * s * k, x, y + 6 * s * k)
		c.bez_to(x - 7 * s * k, y + 6 * s * k, x - 8 * s * k, y - 4 * s * k, x + lean * k, y - 13 * s * f * k)
		if i == 0:
			c.fs(cols[i], Color(OUT, .7), 1)
		else:
			c.fill(cols[i])


static func star(c: Pen, x: float, y: float, r: float, col) -> void:
	c.begin()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rr := r * .45 if i % 2 else r
		c.line_to(x + cos(a) * rr, y + sin(a) * rr)
	c.close()
	c.fs(col, Color(OUT, .5), .6)


static func bolt(c: Pen, pts: Array, col, base := "") -> void:
	c.poly(pts); c.sh(col)
	if base != "":
		c.save(); c.poly(pts); c.clip()
		c.ell(pts[0][0], pts[0][1], 5, 5); c.fill(base)
		c.restore()
		c.poly(pts); c.stroke(OUT, 1.4)


# ---------- Pikachu line ----------
static func _pika_ear(c: Pen, x: float, y: float, rot: float, len: float, col: String) -> void:
	c.save(); c.translate(x, y); c.rotate(rot)
	c.begin(); c.move_to(-3.8, 1); c.bez_to(-4.6, -7, -2.4, -len * .8, 0, -len); c.bez_to(2.4, -len * .8, 4.6, -7, 3.8, 1); c.close()
	c.sh(col, null)
	c.save(); c.clip(); c.ell(0, -len - 1, 6, len * .32); c.fill("#26201c"); c.restore()
	c.begin(); c.move_to(-3.8, 1); c.bez_to(-4.6, -7, -2.4, -len * .8, 0, -len); c.bez_to(2.4, -len * .8, 4.6, -7, 3.8, 1); c.close()
	c.stroke(OUT, 1.4)
	c.restore()


static func _pika_face(c: Pen, cheek: String, smile := true) -> void:
	eye(c, -5.2, -7.5, 2.5, 2.9); eye(c, 5.2, -7.5, 2.5, 2.9)
	blush(c, -9.6, -1.8, 3.1, cheek); blush(c, 9.6, -1.8, 3.1, cheek)
	c.ell(0, -4.6, 1, .6); c.fill(OUT)
	if smile:
		c.begin(); c.move_to(-2.6, -2.8); c.quad_to(-1.3, -1.2, 0, -2.8); c.quad_to(1.3, -1.2, 2.6, -2.8)
		c.quad_to(0, 1.6, -2.6, -2.8); c.fill("#b8384a")
		c.ell(0, -.6, 1.3, .7); c.fill("#f08aa0")
	c.begin(); c.move_to(-2.8, -2.8); c.quad_to(-1.4, -1.2, 0, -2.8); c.quad_to(1.4, -1.2, 2.8, -2.8); c.stroke(OUT, 1.1)


static func pikachu(c: Pen, _t: float, _o := {}) -> void:
	bolt(c, [[3, 11], [10, 6], [7, 3], [15, -2], [12, -5], [21, -13], [25, -9], [18, -3], [21, -1], [13, 6], [15, 8], [7, 13]], "#f7d02c", "#8f5f26")
	c.ell(-5.5, 17.2, 4.6, 2.5); c.sh("#f7d02c"); c.ell(5.5, 17.2, 4.6, 2.5); c.sh("#f7d02c")
	c.begin(); c.move_to(-9, -1); c.bez_to(-12.5, 7, -11.5, 17, 0, 17.5); c.bez_to(11.5, 17, 12.5, 7, 9, -1); c.close(); c.sh("#f7d02c")
	c.ell(-6.5, 6, 2.6, 3.8, .5); c.sh("#f7d02c"); c.ell(6.5, 6, 2.6, 3.8, -.5); c.sh("#f7d02c")
	_pika_ear(c, -6.5, -13, -.42, 17, "#f7d02c"); _pika_ear(c, 6.5, -13, .42, 17, "#f7d02c")
	c.begin(); c.move_to(-13.5, -5); c.bez_to(-13.5, -15, -7, -17, 0, -17); c.bez_to(7, -17, 13.5, -15, 13.5, -5)
	c.bez_to(13.5, 3, 7, 5, 0, 5); c.bez_to(-7, 5, -13.5, 3, -13.5, -5); c.close(); c.sh("#f7d02c")
	_pika_face(c, "#e3452c")


static func raichu(c: Pen, t: float, _o := {}) -> void:
	var sw := sin(t * 2.5) * 1.5
	c.begin(); c.move_to(6, 13); c.bez_to(20, 18, 28, 6, 24 + sw, -10); limb(c, "#3a2a1e", 2)
	bolt(c, [[24 + sw, -10], [29 + sw, -16], [26 + sw, -17], [31 + sw, -25], [22 + sw, -17], [25 + sw, -16], [20 + sw, -11]], "#f7d02c")
	for s in [-1, 1]:
		c.save(); c.translate(s * 9, -12); c.rotate(s * .75)
		c.begin(); c.move_to(-5, 1); c.bez_to(-7, -6, -6, -13, -1, -16); c.bez_to(3, -18, 6, -15, 3, -13); c.bez_to(6, -9, 6, -3, 5, 1); c.close(); c.sh("#7b4a24")
		c.begin(); c.move_to(-2.6, 0); c.bez_to(-4, -6, -3, -11, -.5, -13); c.bez_to(3, -10, 3, -4, 2.6, 0); c.close(); c.fill("#f2c43a")
		c.restore()
	c.ell(-6, 17.6, 5.2, 2.7); c.sh("#c46a2a"); c.ell(6, 17.6, 5.2, 2.7); c.sh("#c46a2a")
	c.begin(); c.move_to(-10, -1); c.bez_to(-13.5, 7, -12.5, 17.5, 0, 18); c.bez_to(12.5, 17.5, 13.5, 7, 10, -1); c.close(); c.sh("#ec8c2c")
	c.ell(0, 10, 7.5, 7); c.sh("#f8e2b2", null)
	c.ell(-8.5, 5, 2.8, 4.2, .5); c.sh("#ec8c2c"); c.ell(8.5, 5, 2.8, 4.2, -.5); c.sh("#ec8c2c")
	for s in [-1, 1]:
		c.poly([[s * 12, -6], [s * 18.5, -2], [s * 12.5, 1]]); c.sh("#ec8c2c")
	c.ell(0, -6, 14, 11); c.sh("#ec8c2c")
	eye(c, -5.2, -8, 2.5, 2.9); eye(c, 5.2, -8, 2.5, 2.9)
	blush(c, -9.6, -2.2, 3, "#f7d02c"); blush(c, 9.6, -2.2, 3, "#f7d02c")
	c.ell(0, -5, 1, .6); c.fill(OUT)
	c.begin(); c.move_to(-3.4, -3.2); c.quad_to(0, 2, 3.4, -3.2); c.quad_to(0, -1.8, -3.4, -3.2); c.fs("#a8304a", OUT, 1)
	c.poly([[-2.4, -2.9], [-1.6, -1.2], [-1, -2.6]]); c.fill("#fff")


static func gmax_pikachu(c: Pen, t: float, _o := {}) -> void:
	c.glow(14, -12, 30, Color("#fff38a"))
	bolt(c, [[4, 10], [12, 3], [9, 0], [18, -8], [14, -11], [26, -22], [30, -18], [22, -9], [26, -7], [15, 4], [18, 6], [8, 13]], "#fff6b8")
	var a0 := c.alpha
	for xyr in [[-12, -33, 7], [-3, -37, 9], [8, -36, 8], [-7, -30, 6], [4, -30, 7], [13, -31, 5]]:
		c.alpha = a0 * .92
		c.ell(xyr[0], xyr[1] + sin(t * 2 + xyr[0]) * 1, xyr[2], xyr[2] * .78); c.sh("#5d607a", null)
	c.alpha = a0
	if int(t * 3) % 4 == 0:
		c.begin(); c.move_to(-2, -29); c.line_to(-5, -23); c.line_to(-1, -23); c.line_to(-4, -17); c.stroke("#fff38a", 1.8)
	c.ell(-7.5, 17.5, 5.2, 2.6); c.sh("#f7d02c"); c.ell(7.5, 17.5, 5.2, 2.6); c.sh("#f7d02c")
	c.ell(0, 6.5, 16, 12.5); c.sh("#f7d02c")
	c.ell(-11, 5, 3.2, 4.4, .6); c.sh("#f7d02c"); c.ell(11, 5, 3.2, 4.4, -.6); c.sh("#f7d02c")
	_pika_ear(c, -8, -15, -.62, 10, "#f7d02c"); _pika_ear(c, 8, -15, .62, 10, "#f7d02c")
	c.ell(0, -6, 14.5, 11.5); c.sh("#f7d02c")
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 9, -16); c.line_to(s * 6, -13); c.line_to(s * 10, -12.5); c.stroke("#8f5f26", 1.4)
	_pika_face(c, "#e3452c")


static func ash_pikachu(c: Pen, t: float, _o := {}) -> void:
	pikachu(c, t)
	c.save(); c.translate(0, -15); c.rotate(-.12)
	c.begin(); c.move_to(-13, 2); c.bez_to(-13, -9, 13, -9, 13, 2); c.close(); c.sh("#e2262b")
	c.begin(); c.move_to(-6, 1); c.bez_to(-6, -6, 6, -6, 6, 1); c.close(); c.sh("#fbfbf6", null)
	c.poly([[-1.8, -3.6], [-.4, -3.6], [-.4, -1.2], [1.8, -1.2], [1.8, .2], [-1.8, .2]]); c.fill("#2c9a4a")
	c.begin(); c.move_to(-14, 2.4); c.quad_to(0, -.5, 18, 3.2); c.quad_to(6, 6, -14, 3.6); c.close(); c.sh("#e2262b")
	c.restore()


# ---------- Charmander line ----------
static func charmander(c: Pen, t: float, _o := {}) -> void:
	c.begin(); c.move_to(6, 13); c.quad_to(19, 16, 18, 3); limb(c, "#f2853a", 4.4)
	flame(c, 18, 0, .82, t)
	c.ell(-5, 17.2, 4.2, 2.5); c.sh("#f2853a"); c.ell(5, 17.2, 4.2, 2.5); c.sh("#f2853a")
	for s in [-1, 1]:
		for k in [-1.6, 0.0, 1.6]:
			c.ell(s * 5 + k + 2.2 * s, 18.6, .7, .7); c.fill("#fff")
	c.begin(); c.move_to(-7.5, -1); c.bez_to(-11, 6, -10, 16.5, 0, 17); c.bez_to(10, 16.5, 11, 6, 7.5, -1); c.close(); c.sh("#f2853a")
	c.ell(0, 10, 6, 6.8); c.sh("#f7d98a", null)
	for s in [-1, 1]:
		c.ell(s * 8.5, 4.5, 2.6, 4, s * -.7); c.sh("#f2853a")
		c.ell(s * 10.6, 7.4, .7, .7); c.fill("#fff")
	c.begin(); c.move_to(-11.5, -9); c.bez_to(-11.5, -18, -5, -20, 0, -20); c.bez_to(6, -20, 12, -17, 12, -9)
	c.bez_to(12, -2, 7, 1, 0, 1); c.bez_to(-7, 1, -11.5, -2, -11.5, -9); c.close(); c.sh("#f2853a")
	eye(c, -4.8, -10, 2.3, 3.3, "#1b2a3e"); eye(c, 4.8, -10, 2.3, 3.3, "#1b2a3e")
	c.ell(-1.6, -5.6, .5, .4); c.fill(OUT); c.ell(1.6, -5.6, .5, .4); c.fill(OUT)
	c.begin(); c.move_to(-5.5, -3.8); c.quad_to(0, 2.6, 5.5, -3.8); c.quad_to(0, -2, -5.5, -3.8); c.fs("#b83a2e", OUT, 1.1)
	c.ell(0, -1.4, 2, .9); c.fill("#ff8a8a")


static func charmeleon(c: Pen, t: float, _o := {}) -> void:
	c.begin(); c.move_to(6, 13); c.bez_to(16, 18, 24, 10, 21, -1); limb(c, "#d9482c", 4.6)
	flame(c, 21, -4, 1.05, t)
	for s in [-1, 1]:
		c.ell(s * 5.5, 17.8, 4.6, 2.6); c.sh("#d9482c")
		for k in [-1.8, 0.0, 1.8]:
			c.poly([[s * 7.6 + k, 18], [s * 7.6 + k + .7, 20.4], [s * 7.6 + k + 1.4, 18]]); c.fill("#fff")
	c.begin(); c.move_to(-8, -2); c.bez_to(-12, 6, -11, 17, 0, 17.5); c.bez_to(11, 17, 12, 6, 8, -2); c.close(); c.sh("#d9482c")
	c.ell(0, 9.5, 6.2, 7.4); c.sh("#f5d38a", null)
	for i in 3:
		c.begin(); c.move_to(-4.5, 6 + i * 3); c.quad_to(0, 7 + i * 3, 4.5, 6 + i * 3); c.stroke(Color("#c89a5a"), .8)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 7, 1); c.quad_to(s * 13, 3, s * 12, 9); limb(c, "#d9482c", 3.4)
		for k in [-1, 1]:
			c.poly([[s * 12 + k, 10], [s * 12.5 + k * 1.6, 13], [s * 13 + k * .4, 10]]); c.fill("#fff")
	c.begin(); c.move_to(3, -18); c.quad_to(11, -26, 18, -27); c.quad_to(13, -20, 9, -13); c.close(); c.sh("#d9482c")
	c.begin(); c.move_to(-11, -11); c.bez_to(-11, -19, -5, -21, 0, -21); c.bez_to(5, -21, 11, -19, 11, -11)
	c.bez_to(11, -6, 7, -4, 0, -4); c.bez_to(-7, -4, -11, -6, -11, -11); c.close(); c.sh("#d9482c")
	c.ell(0, -4.5, 7.5, 4.6); c.sh("#d9482c")
	eye_iris(c, -4.6, -12, 3, 2.3, "#2fa0a8", 1.4); eye_iris(c, 4.6, -12, 3, 2.3, "#2fa0a8", -1.4)
	c.ell(-1.8, -6.8, .6, .45); c.fill(OUT); c.ell(1.8, -6.8, .6, .45); c.fill(OUT)
	c.begin(); c.move_to(-5.5, -3.2); c.quad_to(0, -1.6, 5.5, -3.6); c.stroke(OUT, 1.2)
	c.poly([[3, -3.2], [3.8, -1.4], [4.6, -3.4]]); c.fill("#fff")


static func _zard_wing(c: Pen, s: int, flap: float, body: String, web: String, jag: bool) -> void:
	c.save(); c.translate(s * 5, -6); c.rotate(s * flap); c.scale(.74, .74)
	var tip := [s * 30, -28]
	var outer := [[0, 0], tip, [s * 31, -14], [s * 35, -6], [s * 27, -4], [s * 30, 4], [s * 20, 2], [s * 18, 9], [s * 6, 6]]
	if jag:
		outer = [[0, 0], [s * 24, -34], [s * 31, -24], [s * 37, -24], [s * 33, -12], [s * 38, -6], [s * 28, -3], [s * 31, 5], [s * 19, 2], [s * 16, 10], [s * 6, 6]]
	c.poly(outer); c.sh(body)
	var inner := [[s * 4, 1], [s * 26, -23], [s * 27, -13], [s * 31, -6], [s * 24, -4], [s * 26, 2], [s * 18, 0], [s * 15, 6], [s * 6, 4]]
	if jag:
		inner = [[s * 4, 1], [s * 22, -28], [s * 28, -21], [s * 33, -21], [s * 29, -11], [s * 33, -6], [s * 25, -3], [s * 27, 3], [s * 17, 0], [s * 14, 7], [s * 6, 4]]
	c.poly(inner); c.sh(web, null)
	c.begin()
	for p in [inner[2], inner[4], inner[6]]:
		c.move_to(s * 4, 1); c.line_to(p[0], p[1])
	c.stroke(Color(body).darkened(.2), 1.2)
	c.restore()


static func charizard(c: Pen, t: float, _o := {}) -> void:
	var body := "#f08a2c"
	var flap := sin(t * 4) * .1
	_zard_wing(c, -1, flap, body, "#2f8fa8", false); _zard_wing(c, 1, flap, body, "#2f8fa8", false)
	c.begin(); c.move_to(7, 13); c.bez_to(20, 18, 27, 8, 24, -2); limb(c, body, 5)
	flame(c, 24, -6, 1.3, t)
	c.ell(-6.5, 18, 5.2, 2.8); c.sh(body); c.ell(6.5, 18, 5.2, 2.8); c.sh(body)
	c.begin(); c.move_to(-8, -4); c.bez_to(-14, 4, -13, 17.5, 0, 18); c.bez_to(13, 17.5, 14, 4, 8, -4); c.close(); c.sh(body)
	c.begin(); c.move_to(-5, -4); c.bez_to(-9, 4, -8, 16, 0, 16.5); c.bez_to(8, 16, 9, 4, 5, -4); c.close(); c.sh("#f7d98a", null)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 8, 0); c.quad_to(s * 14, 3, s * 12, 9); limb(c, body, 3.6)
	_zard_head(c, t, body, "#f7d98a", "#2a6aa0", false)


static func mega_charizard_x(c: Pen, t: float, _o := {}) -> void:
	var body := "#2f3342"
	var flap := sin(t * 4) * .1
	_zard_wing(c, -1, flap, body, "#2aa8ff", true); _zard_wing(c, 1, flap, body, "#2aa8ff", true)
	c.begin(); c.move_to(7, 13); c.bez_to(20, 18, 27, 8, 24, -2); limb(c, body, 5)
	flame(c, 24, -6, 1.25, t, true)
	c.ell(-6.5, 18, 5.2, 2.8); c.sh(body); c.ell(6.5, 18, 5.2, 2.8); c.sh(body)
	c.begin(); c.move_to(-8, -4); c.bez_to(-14, 4, -13, 17.5, 0, 18); c.bez_to(13, 17.5, 14, 4, 8, -4); c.close(); c.sh(body)
	c.begin(); c.move_to(-5, -4); c.bez_to(-9, 4, -8, 16, 0, 16.5); c.bez_to(8, 16, 9, 4, 5, -4); c.close(); c.sh("#7cc4ee", null)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 8, 0); c.quad_to(s * 14, 3, s * 12, 9); limb(c, body, 3.6)
		c.poly([[s * 9, -4], [s * 15, -9], [s * 12, -2]]); c.sh("#7cc4ee")
	_zard_head(c, t, body, "#7cc4ee", "#ff3b3b", true)


static func _zard_head(c: Pen, t: float, body: String, pale: String, iris: String, mx: bool) -> void:
	c.begin(); c.rect(-4, -12, 8, 10); c.sh(body, null)
	c.ell(0, -4, 3.4, 4); c.fill(pale)
	for s in [-1, 1]:
		var hl := 9.0 if mx else 6.0
		c.begin(); c.move_to(s * 3.5, -23); c.quad_to(s * 7, -27, s * (8 + hl * .4), -27 - hl); c.quad_to(s * 9, -26, s * 7.5, -21); c.close(); c.sh(body)
		if mx:
			c.ell(s * (8 + hl * .4), -27 - hl, 1.3, 1.3); c.fill("#5ec8f0")
	c.begin(); c.move_to(-9, -17); c.bez_to(-9, -25, -4, -27, 0, -27); c.bez_to(4, -27, 9, -25, 9, -17)
	c.bez_to(9, -13, 6, -11, 0, -11); c.bez_to(-6, -11, -9, -13, -9, -17); c.close(); c.sh(body)
	c.ell(0, -12.5, 6.8, 4.6); c.sh(body)
	eye_iris(c, -4.2, -19.5, 2.8, 2.2, iris, 1.2); eye_iris(c, 4.2, -19.5, 2.8, 2.2, iris, -1.2)
	c.ell(-1.6, -14.5, .6, .45); c.fill(OUT); c.ell(1.6, -14.5, .6, .45); c.fill(OUT)
	c.begin(); c.move_to(-6, -11.5); c.quad_to(0, -9, 6, -11.5); c.stroke(OUT, 1.1)
	c.poly([[-4.6, -11], [-4, -9.4], [-3.4, -10.6]]); c.fill("#fff"); c.poly([[4.6, -11], [4, -9.4], [3.4, -10.6]]); c.fill("#fff")
	if mx:
		flame(c, 7.5, -11, .34, t * 1.3, true); flame(c, -7.5, -11, .34, t * 1.1, true)


# ---------- Gastly line ----------
static func gastly(c: Pen, t: float, _o := {}) -> void:
	c.translate(0, sin(t * 2.2) * 2 - 3)
	for i in 9:
		var a := i / 9.0 * TAU + t * .8
		var r := 10.5 + 2 * sin(t * 2 + i * 1.7)
		c.ell(cos(a) * r, sin(a) * r * .9, 8 + 2.5 * sin(t * 3 + i), 7); c.fill(Color(.62, .38, .86, .16))
	c.ell(0, 0, 11.5, 11.5); c.fill_fan(-3.5, -4.5, 15, Color("#4a3660"), Color("#0f0918"))
	c.ell(0, 0, 11.5, 11.5); c.stroke("#08040c", 1.5)
	c.ell(-4, -6.5, 3.4, 1.8, -.5); c.fill(Color(1, 1, 1, .12))
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 1.5, -6); c.quad_to(s * 10.5, -11, s * 9.5, -2); c.quad_to(s * 5, -.6, s * 1.5, -6); c.fill("#fff")
		c.ell(s * 6.4, -4, 1.5, 1.6); c.fill(INK)
	c.begin(); c.move_to(-7.5, 2); c.quad_to(0, 11, 7.5, 2); c.quad_to(0, 5.2, -7.5, 2); c.fill("#5a1638")
	c.ell(2, 6, 2.6, 1.4); c.fill("#e0608a")
	for s in [-1, 1]:
		c.poly([[s * 1.8, 3.6], [s * 4.6, 3.8], [s * 3.2, 6.6]]); c.fill("#fff")


static func haunter(c: Pen, t: float, _o := {}) -> void:
	c.translate(0, sin(t * 2) * 2 - 4)
	var wisp := sin(t * 3) * 2
	c.begin(); c.move_to(-12, -3)
	for p in [[-17, -12], [-10, -10], [-11, -20], [-4, -13], [-1, -23], [3, -13], [10, -20], [9, -10], [16, -12], [12, -3]]:
		c.line_to(p[0], p[1])
	c.bez_to(13, 7, 7, 11, 4, 13); c.bez_to(3, 17, 1 + wisp, 20, -2 + wisp, 22); c.bez_to(-2, 17, -5, 13, -9, 9); c.bez_to(-13, 5, -13, 1, -12, -3); c.close()
	c.sh("#6a4aa6", "#24123a", 1.5)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 1.4, -7); c.quad_to(s * 9.5, -12, s * 10, -3.5); c.quad_to(s * 5, -2.4, s * 1.4, -7); c.fs("#fff", null)
		c.ell(s * 6.2, -5.4, 1.5, 1.7); c.fill(INK)
	c.begin(); c.move_to(-8, 0); c.quad_to(0, 10, 8, 0); c.quad_to(0, 3.5, -8, 0); c.fill("#2a1240")
	c.begin(); c.move_to(-2, 4); c.quad_to(1, 13, 5, 9); c.quad_to(3, 5, 2, 4); c.fs("#ff7fb0", "#7a2a50", .9)
	for s in [-1, 1]:
		var hx: float = s * (20 + sin(t * 3) * 2)
		var hy := 1 + cos(t * 3 + s) * 3
		c.ell(hx, hy, 4.4, 3.8); c.sh("#6a4aa6", "#24123a", 1.2)
		for f in [-1, 0, 1]:
			c.ell(hx + f * 2.8, hy - 4.2, 1.4, 2.6, f * .35); c.sh("#6a4aa6", "#24123a", 1)


static func gengar(c: Pen, _t: float, _o := {}) -> void:
	_gengar_body(c, "#6c4c9e", "#2a1846", 9, 18.0)
	c.ell(-7, 14.5, 5, 2.7); c.sh("#6c4c9e", "#2a1846"); c.ell(7, 14.5, 5, 2.7); c.sh("#6c4c9e", "#2a1846")
	_gengar_face(c, "#6c4c9e", "#2a1846", false)


static func mega_gengar(c: Pen, t: float, _o := {}) -> void:
	c.ell(0, 15, 21, 5.5); c.fs("#12081f", "#9a6ad8", 1.6)
	for i in 5:
		var a := t * 2 + i * 1.3
		c.ell(-14 + i * 7, 13 - absf(sin(a)) * 3, 2.4, 1.6); c.fill(Color(.7, .45, 1, .45))
	c.glow(0, -6, 32, Color("#b07aff"))
	c.translate(0, sin(t * 2) * 1.2 - 4)
	_gengar_body(c, "#3f2a66", "#160b26", 11, 22.0)
	_gengar_face(c, "#3f2a66", "#160b26", true)
	c.ell(0, -11, 2.4, 3.3); c.fs("#ffd23f", "#160b26", 1); c.ell(0, -11, 1.1, 2); c.fill("#e2262b")


static func _gengar_body(c: Pen, body: String, dk: String, n: int, rr: float) -> void:
	var pts: Array = [[-14, 6]]
	for i in n + 1:
		var a := PI * (1.04 + .92 * i / n)
		var r := rr if i % 2 else 13.5
		pts.append([cos(a) * r, sin(a) * r + 1])
	pts.append([14, 6])
	c.poly(pts); c.sh(body, dk)
	for s in [-1, 1]:
		c.poly([[s * 4.5, -9], [s * 14, -26], [s * 13, -7]]); c.sh(body, dk)
	c.ell(0, 1.5, 15, 13); c.sh(body, dk)
	for s in [-1, 1]:
		c.ell(s * 14, 4, 3.8, 5, s * -.4); c.sh(body, dk)
		for k in [-1, 0, 1]:
			c.poly([[s * 15 + k * 1.6, 8.4], [s * 15.6 + k * 2.2, 11], [s * 16.2 + k * 1.6, 8.4]]); c.fill("#fff")


static func _gengar_face(c: Pen, _body: String, dk: String, mega: bool) -> void:
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 1.8, -4.5); c.line_to(s * 11, -8.5); c.quad_to(s * 11, -1.2, s * 3, -1.4); c.close(); c.fill("#fff")
		c.ell(s * 6.8, -4, 2, 2); c.fill("#e2262b"); c.ell(s * 6.8, -4, .8, .9); c.fill(INK)
		if mega:
			c.begin(); c.move_to(s * 2, -6.5); c.line_to(s * 11, -10); c.stroke(dk, 1.4)
	c.begin(); c.move_to(-10.5, 2); c.quad_to(0, 14, 10.5, 2); c.quad_to(0, 5.4, -10.5, 2); c.close(); c.fill("#fbfbfb"); c.stroke(dk, 1.1)
	c.begin()
	for x in [-6.0, -3.0, 0.0, 3.0, 6.0]:
		c.move_to(x, 3.4 + absf(x) * -.14); c.line_to(x, 8.8 - absf(x) * .6)
	c.move_to(-9, 5); c.quad_to(0, 9, 9, 5)
	c.stroke("#9a8fae", .7)


# ---------- Squirtle line ----------
static func _shades(c: Pen, y: float, w: float) -> void:
	c.begin(); c.move_to(-w, y - 2); c.line_to(w, y - 2); c.line_to(w - 1, y + 1); c.quad_to(w * .55, y + 4.5, 2, y + 1); c.line_to(-2, y + 1); c.quad_to(-w * .55, y + 4.5, -w + 1, y + 1); c.close()
	c.fs("#111", "#000", 1)
	c.fill_rect(-w + 3, y - 1, 3, 1.2, Color(1, 1, 1, .55)); c.fill_rect(4, y - 1, 3, 1.2, Color(1, 1, 1, .55))


static func _plastron(c: Pen, x: float, y: float, rx: float, ry: float) -> void:
	c.ell(x, y, rx, ry); c.sh("#f1d98c", "#9a7a3a", 1.1)
	c.begin()
	for k in [-.45, 0.0, .45]:
		var yy: float = y + ry * k
		var hw: float = rx * sqrt(1 - k * k) * .92
		c.move_to(x - hw, yy); c.quad_to(x, yy + 1.2, x + hw, yy)
	c.move_to(x, y - ry * .95); c.line_to(x, y + ry * .95)
	c.stroke("#b89a4a", .9)


static func squirtle(c: Pen, _t: float, o := {}) -> void:
	var skin := "#7cc6ea"
	c.begin(); c.move_to(8, 14); c.bez_to(16, 18, 21, 12, 18, 6); c.bez_to(15, 2, 11, 6, 14, 9); limb(c, skin, 3.4)
	c.ell(0, 8, 12.5, 11.5); c.sh("#a5672f")
	c.ell(0, 8, 11, 10); c.sh("#f3ead0", null)
	c.ell(-5.5, 17.5, 4.4, 2.6); c.sh(skin); c.ell(5.5, 17.5, 4.4, 2.6); c.sh(skin)
	c.ell(0, 9, 9, 9.6); c.sh(skin)
	_plastron(c, 0, 10, 6.8, 7.6)
	c.ell(-9.5, 5, 2.8, 4.2, .6); c.sh(skin); c.ell(9.5, 5, 2.8, 4.2, -.6); c.sh(skin)
	c.ell(0, -8, 12.5, 11); c.sh(skin)
	eye(c, -4.8, -9, 2.6, 3.4, "#6b2b1d"); eye(c, 4.8, -9, 2.6, 3.4, "#6b2b1d")
	c.ell(-1.2, -4.8, .5, .4); c.fill(OUT); c.ell(1.2, -4.8, .5, .4); c.fill(OUT)
	c.begin(); c.move_to(-4.6, -3.4); c.quad_to(0, 1.6, 4.6, -3.4); c.quad_to(0, -1.8, -4.6, -3.4); c.fs("#b84a5a", OUT, 1.1)
	if o.get("shades", false):
		_shades(c, -10, 11.5)


static func wartortle(c: Pen, t: float, o := {}) -> void:
	var skin := "#8a9ee8"
	var fluff := "#f2f4ff"
	var sw := sin(t * 2) * 1.2
	for k in 3:
		c.ell(13 + k * 3.5, 11 - k * 4 + sw * k * .3, 6 - k, 4.6 - k * .6, .6 + k * .3); c.sh(fluff, "#7a86b0")
	c.begin(); c.move_to(12, 11); c.quad_to(18, 9, 17, 4); c.stroke("#b8c0e0", 1)
	c.ell(0, 8, 13, 12); c.sh("#9a5a2a")
	c.ell(0, 8, 11.5, 10.5); c.sh("#f3ead0", null)
	c.ell(-5.5, 17.8, 4.6, 2.6); c.sh(skin); c.ell(5.5, 17.8, 4.6, 2.6); c.sh(skin)
	c.ell(0, 9, 9.4, 10); c.sh(skin)
	_plastron(c, 0, 10, 7, 8)
	for s in [-1, 1]:
		c.ell(s * 9.8, 5, 2.9, 4.4, s * -.6); c.sh(skin)
		c.ell(s * 11.5, 8, .7, .7); c.fill("#fff")
	for s in [-1, 1]:
		c.save(); c.translate(s * 9, -15); c.rotate(s * .55)
		c.begin(); c.move_to(-3, 2); c.bez_to(-6, -4, -4, -11, 1, -13); c.bez_to(-1, -9, 1, -7, 3, -9); c.bez_to(4, -5, 4, -1, 3, 2); c.close(); c.sh(fluff, "#7a86b0")
		c.begin(); c.move_to(-1, 0); c.quad_to(-2, -6, 1, -10); c.stroke("#b8c0e0", .9)
		c.restore()
	c.ell(0, -8, 12, 10.5); c.sh(skin)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 2.4, -12.6); c.line_to(s * 8, -13.6); c.stroke(OUT, 1.3)
	eye_iris(c, -4.8, -9.6, 2.8, 2.6, "#6b2b1d", .6); eye_iris(c, 4.8, -9.6, 2.8, 2.6, "#6b2b1d", -.6)
	c.begin(); c.move_to(-4.5, -3.6); c.quad_to(0, -.6, 4.5, -3.6); c.stroke(OUT, 1.2)
	c.poly([[2.4, -3.2], [3.2, -1.4], [4, -3.4]]); c.fill("#fff")
	if o.get("shades", false):
		_shades(c, -10.5, 11)


static func _cannon(c: Pen, x: float, y: float, w: float, h: float, rot: float) -> void:
	c.save(); c.translate(x, y); c.rotate(rot)
	c.begin(); c.round_rect(-w / 2, -h, w, h, [1, 1, 0, 0]); c.sh("#b9c0c9", OUT, 1.3)
	c.fill_rect(-w / 2, -h * .62, w, 1.4, Color("#8a929e"))
	c.ell(0, -h, w / 2, w * .22); c.fs("#3a3f48", OUT, 1)
	c.restore()


static func blastoise(c: Pen, _t: float, o := {}) -> void:
	var skin := "#5d86d6"
	c.begin(); c.move_to(9, 15); c.quad_to(16, 18, 18, 12); limb(c, skin, 3.6)
	c.ell(0, 6, 17, 15); c.sh("#9a5a2a")
	c.ell(0, 6, 15, 13.5); c.sh("#f3ead0", null)
	_cannon(c, -12, -6, 6.4, 13, -.42); _cannon(c, 12, -6, 6.4, 13, .42)
	c.ell(-7, 17.8, 6, 3); c.sh(skin); c.ell(7, 17.8, 6, 3); c.sh(skin)
	for s in [-1, 1]:
		for k in [-1.6, 0.0, 1.6]:
			c.poly([[s * 9 + k, 18.4], [s * 9.6 + k, 20.6], [s * 10.2 + k, 18.4]]); c.fill("#fff")
	c.ell(0, 7, 12, 12); c.sh(skin)
	_plastron(c, 0, 8.5, 9, 9.5)
	for s in [-1, 1]:
		c.ell(s * 13, 6, 4.6, 6.4, s * -.4); c.sh(skin)
		c.ell(s * 14.6, 11, 3.4, 2.4); c.sh(skin)
	c.ell(0, -10, 10, 8.5); c.sh(skin)
	for s in [-1, 1]:
		c.poly([[s * 5, -16], [s * 9.5, -22], [s * 10, -14]]); c.sh(skin)
	c.ell(0, -10, 10, 8.5); c.sh(skin)
	eye_iris(c, -4.4, -11.4, 2.6, 2.2, "#6b2b1d", 1.2); eye_iris(c, 4.4, -11.4, 2.6, 2.2, "#6b2b1d", -1.2)
	c.begin(); c.move_to(-4.5, -5.6); c.quad_to(0, -4, 4.5, -5.6); c.stroke(OUT, 1.2)
	if o.get("shades", false):
		_shades(c, -12, 10)


static func mega_blastoise(c: Pen, _t: float, o := {}) -> void:
	var skin := "#4f74c4"
	c.ell(0, 6, 17.5, 15.5); c.sh("#8a4e24")
	c.ell(0, 6, 15.5, 14); c.sh("#f3ead0", null)
	_cannon(c, 0, -14, 11, 20, 0)
	c.ell(0, -14, 9, 4); c.sh("#9aa2ae")
	for s in [-1, 1]:
		_cannon(c, s * 14, -4, 5, 8, s * .5)
	c.ell(-7.5, 17.8, 6.4, 3); c.sh(skin); c.ell(7.5, 17.8, 6.4, 3); c.sh(skin)
	c.ell(0, 7, 12.5, 12); c.sh(skin)
	_plastron(c, 0, 8.5, 9.4, 9.5)
	for s in [-1, 1]:
		c.ell(s * 14, 5, 5, 6.6, s * -.4); c.sh(skin)
		c.save(); c.translate(s * 16, 9); c.rotate(s * 1.3)
		c.begin(); c.round_rect(-3.4, -9, 6.8, 11, 1.5); c.sh("#b9c0c9", OUT, 1.2)
		c.ell(0, -9, 2.6, 1.2); c.fill("#3a3f48")
		c.restore()
	c.ell(0, -8, 10, 8.5); c.sh(skin)
	for s in [-1, 1]:
		c.poly([[s * 5, -14], [s * 10, -20], [s * 10, -12]]); c.sh(skin)
	c.ell(0, -8, 10, 8.5); c.sh(skin)
	eye_iris(c, -4.4, -9.4, 2.6, 2.2, "#6b2b1d", 1.4); eye_iris(c, 4.4, -9.4, 2.6, 2.2, "#6b2b1d", -1.4)
	c.begin(); c.move_to(-4.5, -3.8); c.quad_to(0, -2.4, 4.5, -3.8); c.stroke(OUT, 1.2)
	if o.get("shades", false):
		_shades(c, -10, 10)


# ---------- Bulbasaur line ----------
static func _bulba_body(c: Pen, skin: String, w: float, big: bool) -> void:
	var spot := Color(skin).darkened(.3)
	for s in [-1, 1]:
		c.ell(s * (w - 2), 14.5, 4.6, 3.6); c.sh(skin)
		c.ell(s * (w * .45), 16.6, 4.2, 2.8); c.sh(skin)
		for k in [-1.4, 0.0, 1.4]:
			c.poly([[s * (w * .45) + k - .5, 18.8], [s * (w * .45) + k, 20.4], [s * (w * .45) + k + .5, 18.8]]); c.fill("#fff")
	c.ell(0, 9, w + 1, 8.5 + (1.5 if big else 0.0)); c.sh(skin)
	for xyr in [[-w * .6, 7, 2], [w * .55, 6, 1.6], [w * .2, 12, 1.4]]:
		c.ell(xyr[0], xyr[1], xyr[2], xyr[2] * .8); c.fill(spot)


static func _bulba_head(c: Pen, skin: String, y: float, w: float, fierce: float) -> void:
	var spot := Color(skin).darkened(.3)
	for s in [-1, 1]:
		c.poly([[s * (w * .45), y - 6], [s * (w * .95), y - 12], [s * (w * .95), y - 2]]); c.sh(skin)
	c.begin(); c.move_to(-w, y); c.bez_to(-w, y - 9, -5, y - 10, 0, y - 10); c.bez_to(5, y - 10, w, y - 9, w, y)
	c.bez_to(w, y + 6, 6, y + 7.5, 0, y + 7.5); c.bez_to(-6, y + 7.5, -w, y + 6, -w, y); c.close(); c.sh(skin)
	c.ell(-w * .55, y - 5.5, 1.8, 1.3); c.fill(spot); c.ell(w * .35, y - 7, 1.3, 1); c.fill(spot)
	if fierce == 0:
		for s in [-1, 1]:
			c.ell(s * w * .48, y - .8, 2.8, 3.2); c.fs("#fff", OUT, 1)
			c.ell(s * (w * .48 - .5), y - .3, 1.9, 2.4); c.fill("#c0303a")
			c.ell(s * (w * .48 - .5), y - .2, 1, 1.5); c.fill(INK)
			c.ell(s * (w * .48 - .5) + .6, y - 1.2, .6, .7); c.fill("#fff")
	else:
		eye_iris(c, -w * .48, y - .5, 3.1, 2.9, "#c0303a", fierce); eye_iris(c, w * .48, y - .5, 3.1, 2.9, "#c0303a", -fierce)
	c.ell(-1.2, y + 2.6, .5, .4); c.fill(OUT); c.ell(1.2, y + 2.6, .5, .4); c.fill(OUT)
	c.begin(); c.move_to(-5, y + 3.8); c.quad_to(0, y + 8.4, 5, y + 3.8); c.quad_to(0, y + 5.4, -5, y + 3.8); c.fs("#b84a5a", OUT, 1.1)


static func bulbasaur(c: Pen, _t: float, _o := {}) -> void:
	var skin := "#7ccdb0"
	_bulba_body(c, skin, 12, false)
	c.begin(); c.move_to(-10, 4); c.bez_to(-11, -8, -4, -14, 1, -14); c.bez_to(7, -14, 12, -8, 10, 4); c.close(); c.sh("#5fb24f", "#2e6b2a")
	c.begin(); c.move_to(1, -14); c.quad_to(-1, -5, 0, 3); c.move_to(-6, -10); c.quad_to(-6, -3, -4, 3); c.move_to(7, -10); c.quad_to(6, -3, 5, 3); c.stroke("#2e6b2a", 1)
	_bulba_head(c, skin, 4, 11, 0)


static func ivysaur(c: Pen, t: float, _o := {}) -> void:
	var skin := "#6fbfa6"
	var sw := sin(t * 2) * .04
	for s in [-1, 1]:
		c.save(); c.translate(s * 3, -4); c.rotate(s * (.35 + sw))
		c.begin(); c.move_to(0, 0); c.quad_to(s * 9, -7, s * 19, -2); c.quad_to(s * 10, 4, 0, 0); c.close(); c.sh("#4fa84a", "#2e6b2a")
		c.begin(); c.move_to(s * 2, -.5); c.quad_to(s * 10, -2, s * 17, -2); c.stroke("#2e6b2a", .8)
		c.restore()
	_bulba_body(c, skin, 12.5, false)
	c.begin(); c.move_to(-6, -6); c.bez_to(-8, -14, -3, -21, 0, -22); c.bez_to(3, -21, 8, -14, 6, -6); c.close(); c.sh("#f08bb0", "#9a3d63")
	c.begin(); c.move_to(0, -21); c.quad_to(-2, -14, -1, -7); c.stroke("#c45a84", .9)
	c.begin(); c.move_to(-8, -2); c.quad_to(-6, -9, -2, -7); c.quad_to(-2, -2, -8, -2); c.move_to(8, -2); c.quad_to(6, -9, 2, -7); c.quad_to(2, -2, 8, -2); c.fs("#4fa84a", "#2e6b2a", 1)
	_bulba_head(c, skin, 5, 11.5, 1)


static func venusaur(c: Pen, t: float, _o := {}) -> void:
	_venu(c, t, "#5aa68f", 1.0, false)


static func mega_venusaur(c: Pen, t: float, _o := {}) -> void:
	_venu(c, t, "#4f9a85", 1.2, true)


static func _venu(c: Pen, t: float, skin: String, k: float, mega: bool) -> void:
	var sw := sin(t * 2) * .05
	for s in [-1, 1]:
		for j in 2:
			c.save(); c.translate(s * 4, -2 - j * 3); c.rotate(s * (.15 + j * .45) + sw)
			c.begin(); c.move_to(0, 0); c.quad_to(s * 12 * k, -8, s * 25 * k, -1); c.quad_to(s * 12 * k, 6, 0, 0); c.close(); c.sh("#3f9a45", "#22602a")
			c.begin(); c.move_to(s * 2, 0); c.line_to(s * 23 * k, -1); c.stroke("#22602a", .8)
			c.restore()
	c.ell(0, -5, 5, 5); c.sh("#8a6a3a")
	for i in 5:
		var a := -PI / 2 + (i - 2) * .66
		c.save(); c.translate(cos(a) * 9 * k, -12 + sin(a) * 6 * k); c.rotate(a + PI / 2)
		c.begin(); c.move_to(0, 4); c.bez_to(-7 * k, 2, -6 * k, -9 * k, 0, -10 * k); c.bez_to(6 * k, -9 * k, 7 * k, 2, 0, 4); c.close(); c.sh("#f07a92", "#9a3d4f")
		c.ell(-1.5, -4 * k, 1.2, 1.4); c.fill("#fff"); c.ell(1.6, -2 * k, .9, 1); c.fill("#fff")
		c.restore()
	c.ell(0, -12, 4.5 * k, 3.4 * k); c.sh("#ffd23f" if mega else "#f6c4cc", "#9a3d4f")
	_bulba_body(c, skin, 14, true)
	_bulba_head(c, skin, 5, 12.5, 1.6)
	if mega:
		for i in 5:
			var a := i / 5.0 * TAU - PI / 2
			c.ell(cos(a) * 2.6, -3.5 + sin(a) * 2.3, 2, 1.6, a); c.sh("#f07a92", "#9a3d4f", .9)
		c.ell(0, -3.5, 1.2, 1.2); c.fill("#ffd23f")



# ---------- Meowth, Persian, Wobbuffet ----------
static func _whiskers(c: Pen, y: float, inner: float, outer: float, n: int) -> void:
	c.begin()
	for s in [-1, 1]:
		for k in n:
			var f := k - (n - 1) / 2.0
			c.move_to(s * inner, y + f * 1.2); c.quad_to(s * (inner + outer) * .5, y + f * 2 - 1, s * outer, y - 1.5 + f * 3.4)
	c.stroke(Color(OUT, .8), .6)


static func _amulet(c: Pen, o: Dictionary, y: float) -> void:
	if o.get("amulet", false):
		c.glow(0, y, 10, Color("#ffd23f"))
		c.begin(); c.move_to(-5, y - 4); c.quad_to(0, y - 1, 5, y - 4); c.stroke("#c8a040", .9)
		c.ell(0, y, 2.8, 3.4); c.sh("#ffd23f", "#9a7414", 1)


static func meowth(c: Pen, t: float, o := {}) -> void:
	var fur := "#f4e3b0"
	var brown := "#7a5a3a"
	var sw := sin(t * 2.5) * 1.5
	c.begin(); c.move_to(6, 14); c.bez_to(18, 16, 22, 4, 16 + sw, -3); c.bez_to(13 + sw, -7, 10 + sw, -3, 13 + sw, -1); limb(c, fur, 2.4)
	c.ell(13 + sw, -1.5, 2.6, 2.6); c.sh(brown)
	c.ell(-4.5, 17.8, 4, 2.4); c.sh(brown); c.ell(4.5, 17.8, 4, 2.4); c.sh(brown)
	c.begin(); c.move_to(-6, 1); c.bez_to(-9, 7, -8.5, 17, 0, 17.5); c.bez_to(8.5, 17, 9, 7, 6, 1); c.close(); c.sh(fur)
	c.ell(-7, 6, 2.4, 4.2, .5); c.sh(fur); c.ell(7, 6, 2.4, 4.2, -.5); c.sh(fur)
	for s in [-1, 1]:
		c.poly([[s * 3.5, -15], [s * 13, -25], [s * 12.5, -10]]); c.sh(fur)
		c.poly([[s * 5.6, -14.6], [s * 11.6, -21.4], [s * 11.2, -12]]); c.fill("#2a1d18")
	c.begin(); c.move_to(-13, -8); c.bez_to(-13, -16, -7, -19, 0, -19); c.bez_to(7, -19, 13, -16, 13, -8)
	c.bez_to(13, -1, 7, 2, 0, 2); c.bez_to(-7, 2, -13, -1, -13, -8); c.close(); c.sh(fur)
	c.ell(0, -15.5, 3.3, 3.8); c.sh("#ffd23f", "#9a7414", 1.2); c.fill_rect(-1, -17, 2, 2.8, Color("#9a7414"))
	for s in [-1, 1]:
		c.ell(s * 4.8, -9, 2.6, 3.1); c.fs("#fff", OUT, 1); c.ell(s * 4.8, -9, .8, 2.6); c.fill(INK)
	_whiskers(c, -4, 11.5, 20, 3)
	c.ell(0, -5.6, .9, .6); c.fill("#e88a8a")
	c.begin(); c.move_to(-2.8, -3.6); c.quad_to(-1.4, -2, 0, -3.6); c.quad_to(1.4, -2, 2.8, -3.6); c.stroke(OUT, 1.1)
	c.poly([[-2.3, -3.2], [-1.7, -1.5], [-1.1, -3]]); c.fill("#fff")
	_amulet(c, o, 4)


static func persian(c: Pen, t: float, o := {}) -> void:
	var fur := "#efe0b8"
	var sw := sin(t * 2) * 2
	c.begin(); c.move_to(7, 15); c.bez_to(22, 18, 26, 2, 20 + sw, -8); c.bez_to(18 + sw, -12, 15 + sw, -9, 17 + sw, -6); limb(c, fur, 2.6)
	for s in [-1, 1]:
		c.ell(s * 4, 18, 3.4, 2.2); c.sh(fur)
		c.begin(); c.move_to(s * 3.6, 4); c.quad_to(s * 4.6, 12, s * 4, 17); limb(c, fur, 3.2)
	c.begin(); c.move_to(-5.5, -2); c.bez_to(-8, 4, -9, 14, 0, 15); c.bez_to(9, 14, 8, 4, 5.5, -2); c.close(); c.sh(fur)
	for s in [-1, 1]:
		c.poly([[s * 5, -15], [s * 12, -26], [s * 13, -11]]); c.sh(fur)
		c.poly([[s * 6.8, -14.4], [s * 11.4, -22], [s * 11.8, -12.4]]); c.fill("#e8a0a0")
	c.begin(); c.move_to(-16, -6); c.bez_to(-15, -15, -8, -19, 0, -19); c.bez_to(8, -19, 15, -15, 16, -6)
	c.bez_to(11, -1, 6, 0, 0, 0); c.bez_to(-6, 0, -11, -1, -16, -6); c.close(); c.sh(fur)
	c.ell(0, -14.5, 2.6, 3); c.sh("#e2262b", "#7a1010", 1); c.ell(-.8, -15.6, .8, .8); c.fill("#fff")
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 1.8, -9.5); c.quad_to(s * 5, -12, s * 8.4, -10); c.quad_to(s * 5, -6.6, s * 1.8, -9.5); c.fs("#fff", OUT, 1)
		c.ell(s * 5.2, -9.4, .7, 1.9); c.fill("#2a6a3a")
	_whiskers(c, -5, 13, 27, 2)
	c.ell(0, -5.2, .9, .6); c.fill("#e88a8a")
	c.begin(); c.move_to(-2.4, -3.4); c.quad_to(-1.2, -2, 0, -3.4); c.quad_to(1.2, -2, 2.4, -3.4); c.stroke(OUT, 1.1)
	_amulet(c, o, 4)


static func wobbuffet(c: Pen, t: float, o := {}) -> void:
	var conf: bool = o.get("conf", 0.0) > 0.0
	if conf:
		c.rotate(sin(t * 14) * .18)
	c.begin(); c.move_to(6, 15); c.quad_to(18, 19, 18, 9); limb(c, "#16161a", 1.8)
	c.ell(19, 5, 5, 4.4); c.sh("#26262c", "#000")
	for e in [-1.8, 1.8]:
		c.ell(19 + e, 4.6, 1.2, 1.4); c.fill("#fff")
	c.save()
	var sq := 1 + sin(t * 3) * .04
	c.scale(1 / sq, sq)
	c.begin(); c.move_to(-11.5, 18); c.bez_to(-14.5, -8, -10, -26, 0, -26); c.bez_to(10, -26, 14.5, -8, 11.5, 18); c.close(); c.sh("#5aa6e8", "#1f4a7a", 1.5)
	c.begin(); c.move_to(-3, -26); c.quad_to(-4, -29, -1, -29); c.stroke("#1f4a7a", 1)
	for s in [-1, 1]:
		c.ell(s * 12, 3, 2.8, 8.4, s * -.12); c.sh("#5aa6e8", "#1f4a7a")
	if conf:
		for s in [-1, 1]:
			c.begin()
			for i in 14:
				var a := i * .7 + t * 10
				var r := .3 + i * .18
				c.line_to(s * 4.5 + cos(a) * r, -14 + sin(a) * r)
			c.stroke("#1f2a44", 1.4)
	else:
		for s in [-1, 1]:
			c.begin(); c.move_to(s * 2.2, -14); c.quad_to(s * 4.4, -13, s * 6.8, -14); c.stroke("#1f2a44", 1.5)
	c.ell(0, -7, 4, 1.8); c.sh("#e86a8a", "#a03050", 1)
	c.restore()
	c.ell(-5, 18, 4, 2); c.sh("#5aa6e8", "#1f4a7a"); c.ell(5, 18, 4, 2); c.sh("#5aa6e8", "#1f4a7a")
	if conf:
		for i in 3:
			var a := t * 6 + i * TAU / 3
			star(c, cos(a) * 13, -30 + sin(a) * 3, 3.4, "#ffd23f")


# ---------- Mewtwo ----------
static func _mewtwo_base(c: Pen, t: float, aura: String, tail_k: float) -> void:
	var skin := "#d8cfe2"
	var pur := "#9a62c4"
	c.save(); c.alpha *= .2 + .1 * sin(t * 3); c.ell(0, -3, 22, 28); c.fill(aura); c.restore()
	var sw := sin(t * 2) * 2
	c.begin(); c.move_to(4, 12); c.bez_to(20 * tail_k, 20, 28 * tail_k, 2, 19 + sw, -8); c.bez_to(16 + sw, -12, 12 + sw, -10, 13 + sw, -6); limb(c, pur, 5)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 4, 6); c.quad_to(s * 7.5, 11, s * 5, 17); limb(c, skin, 4.2)
		c.ell(s * 5.6, 18.4, 4.2, 2.3); c.sh(skin, OUT, 1.2)
	c.begin(); c.move_to(-4, -6); c.bez_to(-9, 0, -8, 12, 0, 12.5); c.bez_to(8, 12, 9, 0, 4, -6); c.close(); c.sh(skin)
	c.ell(0, 8, 5.6, 4.6); c.sh(pur, null)
	c.begin(); c.move_to(-2, -8); c.line_to(-2, -3); c.line_to(2, -3); c.line_to(2, -8); c.close(); c.sh(skin, null)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 5, -4); c.quad_to(s * 13, 0, s * 12, 8); limb(c, skin, 2.8)
		for k in [-1, 1]:
			c.ell(s * 12.4 + k * 1.4, 11.4, .9, 1.3); c.fs(skin, OUT, .7)
		c.ell(s * 12.4, 9.6, 2.4, 2.2); c.sh(skin, OUT, 1.1)


static func _mewtwo_head(c: Pen, y: float, r: float, ear: float, tube := true) -> void:
	var skin := "#d8cfe2"
	if tube:
		c.begin(); c.move_to(2, y - 1); c.bez_to(9, y + 1, 9, y + 6, 3, y + 9); limb(c, skin, 1.8)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * (r - 4), y - r + 2); c.quad_to(s * (r - 1), y - r - ear, s * (r + .5), y - r - ear + 1); c.quad_to(s * (r + 1), y - r + 3, s * (r - 1), y - 1); c.close(); c.sh(skin)
	c.begin(); c.move_to(-r, y); c.bez_to(-r, y - r * 1.1, r, y - r * 1.1, r, y); c.bez_to(r, y + r * .6, 2, y + r * .9, 0, y + r * .9)
	c.bez_to(-2, y + r * .9, -r, y + r * .6, -r, y); c.close(); c.sh(skin)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 1.2, y - .4); c.line_to(s * r * .78, y - 1.8); c.line_to(s * r * .68, y + 1.2); c.close(); c.fill("#7a2fb0")
		c.ell(s * r * .48, y - .3, .6, .8); c.fill("#fff")


static func mewtwo(c: Pen, t: float, _o := {}) -> void:
	_mewtwo_base(c, t, "#a6c8ff", 1.0)
	_mewtwo_head(c, -14, 7, 4)


static func armored_mewtwo(c: Pen, t: float, _o := {}) -> void:
	_mewtwo_base(c, t, "#a6c8ff", 1.0)
	var arm := "#8b93a3"
	c.begin(); c.move_to(-7.5, -6); c.line_to(7.5, -6); c.line_to(6, 5); c.quad_to(0, 8, -6, 5); c.close(); c.sh(arm, "#3b414d")
	c.fill_rect(-5, -1, 10, 1.5, Color("#c7ccd6"))
	for s in [-1, 1]:
		c.ell(s * 7.6, -4, 3.4, 2.6); c.sh(arm, "#3b414d")
		c.save(); c.translate(s * 12.2, 4); c.rotate(s * -.15)
		c.begin(); c.round_rect(-2.2, -3, 4.4, 6, 1); c.sh(arm, "#3b414d", 1)
		c.restore()
	_mewtwo_head(c, -14, 7, 4)
	c.begin(); c.arc(0, -14, 7.9, PI * 1.02, PI * 1.98); c.line_to(6.8, -16.4); c.line_to(1.4, -16.4); c.line_to(0, -14.6); c.line_to(-1.4, -16.4); c.line_to(-6.8, -16.4); c.close(); c.sh(arm, "#3b414d")
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 4, -20.5); c.line_to(s * 7.5, -24); c.line_to(s * 6.4, -19); c.close(); c.sh(arm, "#3b414d", 1)
	c.ell(0, -19.5, 1.2, 1.2); c.fill("#c070ff")


static func mega_mewtwo_y(c: Pen, t: float, _o := {}) -> void:
	_mewtwo_base(c, t, "#ff9ad6", .85)
	var sw := sin(t * 2.4) * 1.5
	c.begin(); c.move_to(0, -18); c.bez_to(8, -25, 16, -28 + sw, 24, -21 + sw); c.bez_to(26, -18 + sw, 23, -15 + sw, 21, -17 + sw); limb(c, "#9a62c4", 2.6)
	_mewtwo_head(c, -14, 5.6, 2.6, false)
	for s in [-1, 1]:
		c.ell(s * 3.4, -12, 1.2, 1.2); c.fill("#9a62c4")



# ---------- Magikarp line ----------
static func magikarp(c: Pen, t: float, _o := {}) -> void:
	var hop := absf(sin(t * 9))
	c.save(); c.translate(0, 4 - hop * 5); c.rotate(-sin(t * 9) * .2)
	c.poly([[-10, 2], [-21, -9], [-18, 2], [-21, 13]]); c.sh("#f6e3a0")
	c.begin(); c.move_to(-12, -6); c.line_to(-8, -15); c.line_to(-5, -10); c.line_to(-1, -18); c.line_to(2, -11); c.line_to(6, -17); c.line_to(8, -8); c.close(); c.sh("#f6e3a0")
	c.ell(0, 3, 13.5, 11); c.sh("#f0703a")
	c.ell(1, 8.5, 9, 4.6); c.fill("#f6c49a")
	for i in 3:
		for j in 2:
			c.begin(); c.arc(-6 + i * 4.5 + j * 2, -1 + j * 4.5, 3.4, -1, 1); c.stroke("#c24a22", .9)
	c.ell(6.5, -1.5, 4.4, 4.6); c.fs("#fff", OUT, 1.1); c.ell(7.2, -1.4, 1.4, 1.4); c.fill(INK)
	c.ell(13, 4.5, 2.4, 3.2); c.sh("#ffd6c0", OUT, 1.1)
	c.begin(); c.move_to(12, 2); c.bez_to(18, -2, 21, -8, 18, -13); c.move_to(12, 7); c.bez_to(19, 9, 21, 13, 19, 17); c.stroke(OUT, 2.2, true)
	c.begin(); c.move_to(12, 2); c.bez_to(18, -2, 21, -8, 18, -13); c.move_to(12, 7); c.bez_to(19, 9, 21, 13, 19, 17); c.stroke("#f6e3a0", 1, true)
	c.ell(-1, 11, 4.4, 2.4, -.4); c.sh("#f6e3a0")
	c.restore()


static func _gyara(c: Pen, t: float, body: String, fin: String, belly: String, eye_col: String, mega: bool) -> void:
	var sw := sin(t * 3) * 1.5
	c.save(); c.alpha *= .5; c.ell(-2, 17, 18, 3.8); c.fill("#8fd0ff"); c.restore()
	var segs := [[Vector2(-18, 15), Vector2(-24, 4), Vector2(-10, 0), Vector2(0, 6)], [Vector2(0, 6), Vector2(12, 12), Vector2(16, 0), Vector2(10, -8)],
		[Vector2(10, -8), Vector2(6, -14), Vector2(6 + sw * .5, -20), Vector2(8 + sw, -22)]]
	for f in [[0, .45, -1], [0, .75, -1], [1, .7, 1], [1, .95, 1], [2, .4, 1]]:
		var q: Array = segs[f[0]]
		var p := _bz(q, f[1])
		var d := (_bz(q, f[1] + .02) - p).normalized()
		var n: Vector2 = Vector2(d.y, -d.x) * float(f[2])
		var tip: Vector2 = p + n * (15.0 if mega else 13.0) - d * 3
		c.poly([[p.x - d.x * 3, p.y - d.y * 3], [tip.x, tip.y], [p.x + d.x * 3, p.y + d.y * 3]]); c.sh(fin, OUT, 1.1)
	for w in [[12.6, OUT, false], [10.0, body, false], [3.0, belly, true]]:
		c.save()
		if w[2]:
			c.translate(.8, 1.4)
		c.begin(); c.move_to(-18, 15)
		for q in segs:
			c.bez_to(q[1].x, q[1].y, q[2].x, q[2].y, q[3].x, q[3].y)
		c.stroke(w[1], w[0], true)
		c.restore()
	c.poly([[-18, 15], [-27, 10], [-24, 17], [-28, 22], [-17, 19]]); c.sh(fin)
	c.save(); c.translate(9 + sw, -24)
	c.begin(); c.move_to(-2, -7); c.line_to(-6, -19 if mega else -16); c.line_to(1, -10); c.line_to(2, -18 if mega else -14); c.line_to(5, -8); c.close(); c.sh(fin)
	c.begin(); c.move_to(-9, 0); c.bez_to(-9, -8, 2, -10, 7, -6); c.bez_to(11, -3, 14, -1, 14, 1); c.line_to(2, 2); c.close(); c.sh(body)
	c.begin(); c.move_to(-7, 2); c.line_to(14, 1); c.bez_to(13, 6, 8, 10, 0, 9); c.bez_to(-5, 8, -8, 5, -7, 2); c.close(); c.sh(body)
	c.begin(); c.move_to(-1, 2.6); c.line_to(13, 1.6); c.quad_to(8, 7, 0, 6.4); c.close(); c.fill("#7a1a1a")
	for x in [3.0, 6.0, 9.0, 11.5]:
		c.poly([[x, 1.9], [x + .8, 4.2], [x + 1.6, 1.8]]); c.fill("#fff")
	c.begin(); c.move_to(1, -4); c.line_to(7, -6.4); c.line_to(6.2, -1.8); c.close(); c.fs("#fff", OUT, .9)
	c.ell(5, -3.8, 1.1, 1.3); c.fill(eye_col)
	c.begin(); c.move_to(0, -6); c.line_to(7.5, -8.4); c.stroke(OUT, 1.4)
	c.begin(); c.move_to(12, 3); c.bez_to(17, 4, 19, 1, 18, -3); limb(c, belly, 1)
	c.restore()


static func _bz(q: Array, t: float) -> Vector2:
	var u := 1.0 - t
	return q[0] * (u * u * u) + q[1] * (3.0 * u * u * t) + q[2] * (3.0 * u * t * t) + q[3] * (t * t * t)


static func gyarados(c: Pen, t: float, _o := {}) -> void:
	_gyara(c, t, "#3c78c8", "#f2f0e6", "#f2d28a", INK, false)


static func mega_gyarados(c: Pen, t: float, _o := {}) -> void:
	_gyara(c, t, "#2a3e8a", "#e2453c", "#7a90b8", "#e2262b", true)


# ---------- Pidgey line ----------
static func _bird_face(c: Pen, y: float, fierce: float) -> void:
	for s in [-1, 1]:
		c.poly([[s * 1.6, y - 2.6], [s * 9.4, y - 3.6], [s * 7.6, y + 1.6]]); c.fill("#1b1b22")
		c.ell(s * 4.6, y - 1, 1.9, 2.1 - fierce * .3); c.fill("#fff")
		c.ell(s * 4.9, y - .8, 1.1, 1.4); c.fill(INK)
		if fierce > 0:
			c.begin(); c.move_to(s * 1.6, y - 3.2 - fierce); c.line_to(s * 8, y - 3.8); c.stroke(OUT, 1.2)
	c.begin(); c.move_to(-3, y + 1.6); c.quad_to(0, y + .6, 3, y + 1.6); c.line_to(0, y + 6); c.close(); c.sh("#e8a050", OUT, 1)


static func pidgey(c: Pen, t: float, _o := {}) -> void:
	var brown := "#b07a46"
	var flap := sin(t * 10) * .25
	c.poly([[5, 11], [15, 16], [16, 9]]); c.sh(brown)
	for s in [-1, 1]:
		c.save(); c.translate(s * 8, 3); c.rotate(s * (.4 + flap))
		c.begin(); c.move_to(0, -3); c.bez_to(s * 8, -5, s * 12, 0, s * 11, 4); c.line_to(s * 8, 2.6); c.line_to(s * 7, 5); c.line_to(s * 4, 3.4); c.quad_to(0, 4, 0, -3); c.close(); c.sh(brown)
		c.restore()
	c.ell(0, 6, 10, 10.5); c.sh(brown)
	c.ell(0, 9, 6.6, 7); c.sh("#f3dfb4", null)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 3, 16); c.line_to(s * 3, 18.5); c.move_to(s * 3, 18.5); c.line_to(s * 5, 19); c.move_to(s * 3, 18.5); c.line_to(s * 1.4, 19.2); c.stroke("#e89aa0", 1.4, true)
	c.begin(); c.move_to(-1, -15); c.quad_to(1, -22, 6, -21); c.quad_to(3, -18, 5, -14); c.close(); c.sh(brown)
	c.ell(0, -7, 10, 9); c.sh(brown)
	c.ell(0, -4, 7.4, 5.6); c.sh("#f3dfb4", null)
	_bird_face(c, -7, 0)


static func pidgeotto(c: Pen, t: float, _o := {}) -> void:
	var brown := "#a8703e"
	var flap := sin(t * 10) * .25
	for i in 3:
		c.poly([[4, 10], [14 + i * 2, 13 + i * 3.5], [15 + i * 2.4, 9 + i * 3]]); c.sh("#e2453c" if i == 1 else brown)
	for s in [-1, 1]:
		c.save(); c.translate(s * 9, 1); c.rotate(s * (.5 + flap))
		c.begin(); c.move_to(0, -4); c.bez_to(s * 10, -7, s * 16, -1, s * 15, 4); c.line_to(s * 11, 3); c.line_to(s * 10, 6); c.line_to(s * 6, 4); c.line_to(s * 5, 6); c.quad_to(0, 4, 0, -4); c.close(); c.sh(brown)
		c.restore()
	c.ell(0, 6, 11, 11); c.sh(brown)
	c.ell(0, 9, 7, 7.6); c.sh("#f3dfb4", null)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 3.4, 16); c.line_to(s * 3.4, 18.6); c.move_to(s * 3.4, 18.6); c.line_to(s * 5.6, 19.4); c.move_to(s * 3.4, 18.6); c.line_to(s * 1.6, 19.6); c.stroke("#e8a050", 1.6, true)
	var sw := sin(t * 3) * .05
	for i in 4:
		c.save(); c.translate(1, -15); c.rotate(-.9 + i * .28 + sw)
		c.begin(); c.move_to(0, 0); c.quad_to(6, -3, 15 - i, -1); c.quad_to(6, 2, 0, 0); c.close(); c.sh("#ffd23f" if i % 2 else "#e2453c")
		c.restore()
	c.ell(0, -7, 10.5, 9); c.sh(brown)
	c.ell(0, -4, 7.6, 5.6); c.sh("#f3dfb4", null)
	_bird_face(c, -7, 1)


static func _pidgeot_plume(c: Pen, t: float, cols: Array, len: float) -> void:
	for i in cols.size():
		c.save(); c.translate(-1, -17); c.rotate(-.55 + i * .24 + sin(t * 3 + i) * .06)
		c.begin(); c.move_to(0, 0); c.bez_to(len * .4, -4, len * .8, -3, len, 1); c.bez_to(len * .7, 1, len * .4, 3, 0, 0); c.close(); c.sh(cols[i])
		c.restore()


static func _pidgeot_body(c: Pen, t: float, brown: String, span: float, tail: Array) -> void:
	var flap := sin(t * 9) * .2
	for i in tail.size():
		c.save(); c.translate(3, 11); c.rotate(.15 + i * .22)
		c.begin(); c.move_to(0, 0); c.quad_to(8, -3, 17, 1); c.quad_to(8, 4, 0, 0); c.close(); c.sh(tail[i])
		c.restore()
	for s in [-1, 1]:
		c.save(); c.translate(s * 9, -1); c.rotate(s * (.25 + flap))
		c.begin(); c.move_to(0, -4); c.bez_to(s * span * .5, -12, s * span, -9, s * span, -4)
		for k in 4:
			c.line_to(s * (span - 3 - k * 4), -1 + k * 1.6 + (2.4 if k % 2 else 0.0))
		c.quad_to(s * 2, 6, 0, -4); c.close(); c.sh(brown)
		c.begin(); c.move_to(s * 3, -3); c.quad_to(s * span * .5, -8, s * (span - 2), -5); c.stroke(Color(brown).darkened(.25), .9)
		c.restore()
	c.ell(0, 5, 11.5, 12); c.sh(brown)
	c.ell(0, 8, 7.6, 8.6); c.sh("#f3dfb4", null)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 3.6, 16); c.line_to(s * 3.6, 18.8); c.move_to(s * 3.6, 18.8); c.line_to(s * 6, 19.6); c.move_to(s * 3.6, 18.8); c.line_to(s * 1.6, 19.8); c.stroke("#e8a050", 1.7, true)


static func pidgeot(c: Pen, t: float, _o := {}) -> void:
	var brown := "#9a6438"
	_pidgeot_plume(c, t, ["#e2453c", "#ffd23f", "#e2453c", "#ffd23f"], 24)
	_pidgeot_body(c, t, brown, 22, ["#e2453c", "#ffd23f", "#e2453c"])
	c.ell(0, -8, 10, 9); c.sh(brown)
	c.ell(0, -5, 7.6, 5.6); c.sh("#f3dfb4", null)
	_bird_face(c, -8, 1.4)


static func mega_pidgeot(c: Pen, t: float, _o := {}) -> void:
	var brown := "#8a5a3a"
	_pidgeot_plume(c, t, ["#3c78c8", "#e2453c", "#ffd23f", "#3c78c8", "#e2453c"], 32)
	_pidgeot_body(c, t, brown, 27, ["#3c78c8", "#e2453c", "#ffd23f", "#3c78c8"])
	c.ell(0, -8, 10, 9); c.sh(brown)
	c.ell(0, -5, 7.6, 5.6); c.sh("#f3dfb4", null)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 2, -13); c.quad_to(s * 6, -16, s * 9, -14); c.stroke("#3c78c8", 1.6, true)
	_bird_face(c, -8, 1.6)



# ---------- Geodude line ----------
## Craggy blob: an ellipse whose rim is pushed in and out by a fixed pattern.
static func _crag(c: Pen, x: float, y: float, rx: float, ry: float, n: int, seed: int) -> void:
	c.begin()
	for i in n:
		var a := TAU * i / n
		var k := 1.0 + .09 * sin(i * 2.7 + seed) + .05 * cos(i * 5.3 + seed * 2)
		var px := x + cos(a) * rx * k
		var py := y + sin(a) * ry * k
		if i == 0:
			c.move_to(px, py)
		else:
			c.line_to(px, py)
	c.close()


static func _rock_face(c: Pen, y: float, mouth := 1) -> void:
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 1.2, y - 2.4); c.line_to(s * 6.6, y - 3.8); c.stroke(OUT, 1.8, true)
		c.ell(s * 3.8, y, 1.6, 1.9); c.fill(INK); c.ell(s * 3.8 + .5, y - .6, .5, .5); c.fill("#fff")
	if mouth == 1:
		c.begin(); c.move_to(-3.4, y + 5); c.quad_to(0, y + 3.6, 3.4, y + 5); c.stroke(OUT, 1.3)
	else:
		c.begin(); c.move_to(-4, y + 4); c.quad_to(0, y + 8, 4, y + 4); c.close(); c.fs("#5a2a2a", OUT, 1)
		c.fill_rect(-3, y + 4.1, 6, 1.2, Color("#fff"))


static func geodude(c: Pen, t: float, _o := {}) -> void:
	var rock := "#9a9488"
	c.translate(0, sin(t * 3) * 1.5 - 3)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 9, 2); c.bez_to(s * 15, 8, s * 20, 6, s * 19, -1); limb(c, rock, 4.6)
		_crag(c, s * 19, -4, 5, 4.6, 9, 3 + s); c.sh(rock)
		c.begin(); c.move_to(s * 16.5, -6); c.line_to(s * 19, -3); c.move_to(s * 19, -7.5); c.line_to(s * 21, -4.5); c.stroke(Color(rock).darkened(.35), 1)
	_crag(c, 0, 0, 12.5, 11.5, 16, 1); c.sh(rock)
	for xy in [[-7, -6, 1.6], [7, 5, 1.3], [-6, 6, 1], [5, -8, .9]]:
		c.ell(xy[0], xy[1], xy[2] * 1.4, xy[2]); c.fill(Color(rock).darkened(.25))
	_rock_face(c, -2)


static func graveler(c: Pen, t: float, _o := {}) -> void:
	var rock := "#8c8476"
	var sw := sin(t * 2) * .08
	for s in [-1, 1]:
		for k in [-1, 1]:
			c.save(); c.translate(s * 12, 3 + k * 5); c.rotate(s * (k * .5 + sw))
			_crag(c, s * 4, 0, 5, 3.8, 8, 2 + k); c.sh(rock)
			c.restore()
	c.ell(-5.5, 16.6, 5, 3); c.sh(rock); c.ell(5.5, 16.6, 5, 3); c.sh(rock)
	_crag(c, 0, 1, 14, 14, 11, 5); c.sh(rock)
	for xy in [[-9, -8], [8, -10], [10, 7], [-10, 8], [0, -13]]:
		_crag(c, xy[0], xy[1], 2.6, 2, 6, xy[0]); c.sh(Color(rock).darkened(.08), OUT, 1)
	_rock_face(c, -1, 2)


static func golem(c: Pen, t: float, _o := {}) -> void:
	var shell := "#8a8a6a"
	var skin := "#c89a62"
	c.ell(-7, 16.4, 5.4, 3.2); c.sh(skin); c.ell(7, 16.4, 5.4, 3.2); c.sh(skin)
	for s in [-1, 1]:
		c.ell(s * 16.5, 5, 4.6, 5.4, s * .3); c.sh(skin)
		for k in [-1, 0, 1]:
			c.ell(s * 18 + k * 1.6, 9.4, .9, 1.3); c.fs("#fff", OUT, .6)
	c.ell(0, 2, 16, 14.5); c.sh(shell)
	for i in 8:
		var a := -PI * .95 + i * .27
		c.begin(); c.move_to(cos(a) * 10, 2 + sin(a) * 9); c.line_to(cos(a) * 15.6, 2 + sin(a) * 13.8); c.stroke(Color(shell).darkened(.3), 1.2)
	for i in 3:
		var a := PI * .25 + i * .25
		c.begin(); c.move_to(cos(a) * 9, 2 + sin(a) * 8); c.line_to(cos(a) * 15.4, 2 + sin(a) * 13.4); c.stroke(Color(shell).darkened(.3), 1.2)
	var bob := sin(t * 2) * .5
	c.ell(0, -1 + bob, 8, 7); c.sh(skin)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 1.4, -4.5 + bob); c.line_to(s * 6, -5.6 + bob); c.stroke(OUT, 1.6, true)
		c.ell(s * 3.4, -2.4 + bob, 1.3, 1.5); c.fill(INK)
	c.begin(); c.move_to(-3, 2.4 + bob); c.quad_to(0, 4.6 + bob, 3, 2.4 + bob); c.stroke(OUT, 1.2)


# ---------- Machop line ----------
static func _fighter_head(c: Pen, skin: String, y: float, r: float, crest: int, eye_col) -> void:
	if crest == 3:
		for i in 3:
			c.poly([[-4.6 + i * 3.4, y - r + 1], [-3.4 + i * 3.4 + (i - 1) * .8, y - r - 6], [-1.6 + i * 3.4, y - r + 1]]); c.sh(Color(skin).darkened(.25), OUT, 1.1)
	else:
		c.begin(); c.move_to(-5, y - r + 2); c.quad_to(-3, y - r - 6, 0, y - r - 7.5); c.quad_to(3, y - r - 6, 5, y - r + 2); c.close(); c.sh(skin)
		c.ell(0, y - r - 2, 2.2, 2.4); c.sh("#c0303a" if crest == 2 else Color(skin).darkened(.2), OUT, 1)
	c.ell(0, y, r, r * .92); c.sh(skin)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 1.4, y - 2.4); c.line_to(s * 6, y - 3.8); c.stroke(OUT, 1.6, true)
		c.ell(s * 3.6, y - .2, 1.4, 1.7); c.fill(eye_col); c.ell(s * 3.6 + .4, y - .8, .45, .45); c.fill("#fff")
	c.begin(); c.move_to(-2.8, y + 4); c.quad_to(0, y + 3, 2.8, y + 4); c.stroke(OUT, 1.2)


static func _fighter_arm(c: Pen, skin: String, x: float, y: float, s: int, w: float, up: bool) -> void:
	c.begin(); c.move_to(x, y)
	if up:
		c.quad_to(x + s * 9, y + 2, x + s * 9, y - 7)
	else:
		c.quad_to(x + s * 7, y + 3, x + s * 8, y + 9)
	limb(c, skin, w)
	var fx := x + s * (9.0 if up else 8.0)
	var fy := y + (-9.0 if up else 11.0)
	c.ell(fx, fy, w * .9, w * .8); c.sh(skin)


static func machop(c: Pen, _t: float, _o := {}) -> void:
	var skin := "#9ab0c8"
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 3.6, 8); c.line_to(s * 4.6, 15.5); limb(c, skin, 3.6)
		c.ell(s * 5, 17.4, 4, 2.3); c.sh(skin)
	c.begin(); c.move_to(-7, -3); c.bez_to(-9, 5, -7, 12, 0, 12); c.bez_to(7, 12, 9, 5, 7, -3); c.close(); c.sh(skin)
	c.begin(); c.move_to(-3, 1); c.quad_to(0, 2.4, 3, 1); c.move_to(0, 2); c.line_to(0, 7); c.move_to(-3, 5); c.quad_to(0, 6, 3, 5); c.stroke(Color(skin).darkened(.3), .9)
	_fighter_arm(c, skin, -6, -1, -1, 3.4, true); _fighter_arm(c, skin, 6, -1, 1, 3.4, true)
	_fighter_head(c, skin, -10, 8, 3, "#c0303a")


static func machoke(c: Pen, _t: float, _o := {}) -> void:
	var skin := "#8d95b4"
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 4, 8); c.line_to(s * 5, 15.5); limb(c, skin, 4.4)
		c.ell(s * 5.6, 17.6, 4.6, 2.5); c.sh(skin)
	c.begin(); c.move_to(-9, -4); c.bez_to(-11, 5, -8, 12, 0, 12); c.bez_to(8, 12, 11, 5, 9, -4); c.close(); c.sh(skin)
	c.begin(); c.move_to(-8, 8); c.line_to(8, 8); c.line_to(7, 13); c.quad_to(0, 15, -7, 13); c.close(); c.sh("#2a2a34")
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 2, -3); c.quad_to(s * 6, 0, s * 5, 5); c.stroke("#c0303a", 1.2)
	_fighter_arm(c, skin, -8, -2, -1, 4.2, true); _fighter_arm(c, skin, 8, -2, 1, 4.2, true)
	_fighter_head(c, skin, -11, 7.5, 1, "#c0303a")


static func _machamp(c: Pen, t: float, gmax: bool) -> void:
	var skin := "#7a8aa8"
	if gmax:
		c.save(); c.alpha *= .3 + .12 * sin(t * 6); c.ell(0, -2, 26, 27); c.fill("#ff6a3a"); c.restore()
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 4.6, 8); c.line_to(s * 5.6, 15.5); limb(c, skin, 5)
		c.ell(s * 6.2, 17.8, 5, 2.7); c.sh(skin)
	_fighter_arm(c, skin, -8, 3, -1, 4, false); _fighter_arm(c, skin, 8, 3, 1, 4, false)
	c.begin(); c.move_to(-11, -5); c.bez_to(-12, 5, -9, 12, 0, 12); c.bez_to(9, 12, 12, 5, 11, -5); c.close(); c.sh(skin)
	c.begin(); c.move_to(-9, 8); c.line_to(9, 8); c.line_to(8, 13); c.quad_to(0, 15, -8, 13); c.close(); c.sh("#2a2a34")
	c.begin(); c.round_rect(-9.5, 6.6, 19, 3.4, 1); c.sh("#ffd23f", OUT, 1)
	if gmax:
		c.glow(0, 8.3, 9, Color("#ff9a3a"))
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 2, -4); c.quad_to(s * 7, -1, s * 6, 5); c.stroke(Color(skin).darkened(.3), 1)
	_fighter_arm(c, skin, -10, -4, -1, 4.6, true); _fighter_arm(c, skin, 10, -4, 1, 4.6, true)
	if gmax:
		for s in [-1, 1]:
			for k in [[-13.0, 4.0], [-6.0, 12.0]]:
				var f := 1 + .2 * sin(t * 12 + k[0] + s)
				c.save(); c.alpha *= .6; c.ell(s * (k[1] + 6), k[0] + (0.0 if k[0] < 0 else 2.0), 6 * f, 5 * f); c.fill("#ff7a2a"); c.restore()
	_fighter_head(c, skin, -12, 7.5, 2, "#c0303a")


static func machamp(c: Pen, t: float, _o := {}) -> void:
	_machamp(c, t, false)


static func gmax_machamp(c: Pen, t: float, _o := {}) -> void:
	_machamp(c, t, true)


# ---------- Abra line ----------
static func _psi_head(c: Pen, gold: String, y: float, ear: float, awake: bool, star: bool, stache: float) -> void:
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 3, y - 6); c.quad_to(s * 7, y - 10 - ear * .5, s * 9, y - 8 - ear); c.quad_to(s * 10, y - 4, s * 8, y - 1); c.close(); c.sh(gold)
		c.begin(); c.move_to(s * 5, y - 5); c.quad_to(s * 7.4, y - 8 - ear * .5, s * 8.4, y - 6 - ear); c.stroke(Color(gold).darkened(.3), 1)
	c.begin(); c.move_to(-9, y); c.bez_to(-9, y - 8, 9, y - 8, 9, y); c.bez_to(9, y + 4, 5, y + 7, 0, y + 7); c.bez_to(-5, y + 7, -9, y + 4, -9, y); c.close(); c.sh(gold)
	c.ell(0, y + 4, 4.6, 2.8); c.sh(Color(gold).lightened(.25), null)
	if star:
		star(c, 0, y - 4, 2.6, "#c0303a")
	if stache > 0:
		for s in [-1, 1]:
			c.begin(); c.move_to(s * 1, y + 3.6); c.bez_to(s * 6, y + 3.4, s * (6 + stache * .3), y + 6, s * (5 + stache * .5), y + 3.6 + stache); c.stroke(OUT, 2.2, true)
			c.begin(); c.move_to(s * 1, y + 3.6); c.bez_to(s * 6, y + 3.4, s * (6 + stache * .3), y + 6, s * (5 + stache * .5), y + 3.6 + stache); c.stroke("#a87a3a", 1, true)
	for s in [-1, 1]:
		if awake:
			c.begin(); c.move_to(s * 1.4, y - 1.6); c.line_to(s * 7.8, y - 2.8); c.quad_to(s * 7.6, y + 1.6, s * 2.6, y + .8); c.close(); c.fs("#fff", OUT, 1)
			c.ell(s * 5, y - .7, 1.2, 1.5); c.fill(INK)
		else:
			c.begin(); c.move_to(s * 1.8, y - .2); c.quad_to(s * 4.4, y + 1.2, s * 7, y - .6); c.stroke(OUT, 1.5, true)
	c.ell(-1, y + 2.4, .4, .3); c.fill(OUT); c.ell(1, y + 2.4, .4, .3); c.fill(OUT)


static func _psi_body(c: Pen, t: float, gold: String, armor: String, tail_band: bool, pads: float) -> void:
	var sw := sin(t * 2) * 1.2
	c.begin(); c.move_to(5, 12); c.bez_to(17, 16, 21, 6, 15 + sw, -2); limb(c, gold, 4)
	if tail_band:
		c.begin(); c.move_to(17.4 + sw * .6, 5); c.line_to(20 + sw * .6, 6.4); c.stroke("#c0303a", 2.4)
	c.ell(-5, 17.6, 4.2, 2.4); c.sh(gold); c.ell(5, 17.6, 4.2, 2.4); c.sh(gold)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 4, 10); c.line_to(s * 5, 16); limb(c, gold, 3.2)
	c.begin(); c.move_to(-7, -2); c.bez_to(-10, 6, -8, 13, 0, 13); c.bez_to(8, 13, 10, 6, 7, -2); c.close(); c.sh(armor)
	c.begin(); c.move_to(-5, 3); c.quad_to(0, 5, 5, 3); c.move_to(-4.4, 7); c.quad_to(0, 9, 4.4, 7); c.stroke(Color(armor).lightened(.2), 1)
	if pads > 0:
		for s in [-1, 1]:
			c.begin(); c.move_to(s * 3, -3); c.quad_to(s * (8 + pads), -6, s * (10 + pads), 0); c.quad_to(s * 7, 1, s * 3, -3); c.close(); c.sh(armor)


static func abra(c: Pen, t: float, _o := {}) -> void:
	var gold := "#e8c040"
	_psi_body(c, t, gold, "#8a5a2a", false, 0)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 6, 0); c.quad_to(s * 9, 6, s * 2.6, 7); limb(c, gold, 2.8)
	for k in [-1, 1]:
		c.ell(k * 1.4, 7, 1.6, 1.3); c.fs(gold, OUT, .8)
	_psi_head(c, gold, -10, 6, false, false, 0)
	var zy := -22 - fmod(t * 3, 5)
	c.begin(); c.move_to(9, zy); c.line_to(12, zy); c.line_to(9, zy + 3); c.line_to(12, zy + 3); c.stroke(Color(1, 1, 1, .85), 1)


static func _spoon(c: Pen, x: float, y: float, rot: float) -> void:
	c.save(); c.translate(x, y); c.rotate(rot)
	c.begin(); c.move_to(0, 0); c.line_to(0, -9); c.stroke(OUT, 2.4, true); c.begin(); c.move_to(0, 0); c.line_to(0, -9); c.stroke("#c8ccd6", 1.2, true)
	c.ell(0, -11.4, 2.2, 3); c.sh("#d8dce6", OUT, 1)
	c.restore()


static func kadabra(c: Pen, t: float, _o := {}) -> void:
	var gold := "#e2b030"
	_psi_body(c, t, gold, "#8a5a2a", true, 2)
	c.begin(); c.move_to(-6, -1); c.quad_to(-11, 4, -9, 9); limb(c, gold, 2.8)
	c.begin(); c.move_to(6, -1); c.quad_to(12, 2, 13, 8); limb(c, gold, 2.8)
	_spoon(c, 13, 9, .25)
	c.ell(13, 9, 2.2, 2); c.sh(gold, OUT, 1)
	_psi_head(c, gold, -11, 9, true, true, 4)


static func alakazam(c: Pen, t: float, _o := {}) -> void:
	var gold := "#dcaa30"
	_psi_body(c, t, gold, "#8a5a2a", false, 4)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 8, -1); c.quad_to(s * 14, 3, s * 13, 8); limb(c, gold, 2.8)
		_spoon(c, s * 13.4, 8.6, s * .3)
		c.ell(s * 13.4, 8.6, 2.2, 2); c.sh(gold, OUT, 1)
	_psi_head(c, gold, -12, 10, true, true, 9)


static func mega_alakazam(c: Pen, t: float, _o := {}) -> void:
	var gold := "#e0b438"
	c.save(); c.alpha *= .25 + .1 * sin(t * 3); c.ell(0, -5, 24, 27); c.fill("#ff9ad6"); c.restore()
	c.translate(0, sin(t * 2) * 2 - 3)
	for i in 5:
		var a := -PI / 2 + (i - 2) * .55 + sin(t * 1.5) * .05
		_spoon(c, cos(a) * 22, -6 + sin(a) * 17 + sin(t * 2 + i) * 1.5, a + PI / 2)
	_psi_body(c, t, gold, "#7a4a22", false, 5)
	c.ell(0, -1, 5, 5); c.sh("#c0303a", OUT, 1)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 8, -1); c.quad_to(s * 13, 4, s * 11, 8); limb(c, gold, 2.6)
	c.begin(); c.move_to(-4, -7); c.bez_to(-8, 2, -4, 10, 0, 14); c.bez_to(4, 10, 8, 2, 4, -7); c.close(); c.sh("#f2efe6", "#9a9488", 1)
	_psi_head(c, gold, -13, 10, true, false, 6)
	c.ell(0, -17.5, 1.8, 2.2); c.sh("#c0303a", OUT, 1)


# ---------- Lapras ----------
static func _lapras(c: Pen, t: float, gmax: bool) -> void:
	var blue := "#5aa8d8"
	var shell := "#8ab8d0" if gmax else "#9a9aa8"
	var bob := sin(t * 2) * .8
	c.save(); c.alpha *= .5; c.ell(2, 17.5, 20, 3.6); c.fill("#8fd0ff"); c.restore()
	c.poly([[14, 12], [24, 15], [15, 17]]); c.sh(blue)
	c.ell(-11, 15.6, 7, 3, -.3); c.sh(blue); c.ell(11, 16.4, 7, 3, .3); c.sh(blue)
	c.ell(2, 9, 15.5, 9); c.sh("#f2e6c0")
	c.ell(5, 4, 14, 9.4); c.sh(shell)
	for xy in [[-1, -1], [5.5, -3.4], [12, -.6], [2.6, 4.6], [9.6, 5.2], [16, 4]]:
		c.begin(); c.move_to(xy[0] - 2.4, xy[1] + 1.6); c.line_to(xy[0], xy[1] - 2.4); c.line_to(xy[0] + 2.4, xy[1] + 1.6); c.close(); c.sh("#f0f6ff" if gmax else "#d8d8e0", "#5a5a68", 1)
	c.begin(); c.move_to(-6, 7); c.bez_to(-15, 1, -14, -10, -8, -16 + bob); limb(c, blue, 6.4)
	c.begin(); c.move_to(-7, 7); c.bez_to(-12.6, 2, -12, -8, -7.6, -13 + bob); c.stroke("#f2e6c0", 2.4, true)
	c.save(); c.translate(-6, -21 + bob)
	c.poly([[-1, -5], [1, -11], [3, -5]]); c.sh(blue, OUT, 1.1)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 5, -3); c.bez_to(s * 10, -5, s * 11, 1, s * 7.6, 1); c.bez_to(s * 9, -2, s * 7, -2, s * 6, 0); c.close(); c.sh(blue, OUT, 1)
	c.ell(0, 0, 8.4, 6.6); c.sh(blue)
	eye(c, -3.2, -.6, 1.7, 2.2); eye(c, 3.2, -.6, 1.7, 2.2)
	c.begin(); c.arc(0, 2.2, 2.6, .2 * PI, .8 * PI); c.stroke(OUT, 1.1)
	c.restore()


static func lapras(c: Pen, t: float, _o := {}) -> void:
	_lapras(c, t, false)


static func gmax_lapras(c: Pen, t: float, _o := {}) -> void:
	for i in 3:
		c.save(); c.alpha *= .35; c.ell(2, -6 - i * 5, 28 - i * 4, 8, sin(t + i) * .1); c.fill(["#7af0c8", "#9ad0ff", "#ff9ad6"][i]); c.restore()
	_lapras(c, t, true)
	for i in 4:
		var a := t * 1.5 + i * TAU / 4
		star(c, cos(a) * 18 + 3, -26 + sin(a) * 4, 2.2, "#fff6b8")


# ---------- Snorlax ----------
static func _lax(c: Pen, t: float, gmax: bool) -> void:
	var teal := "#2f6a74"
	var cream := "#f0e2bc"
	var breathe := 1 + sin(t * 2) * .02
	c.save(); c.scale(breathe, 1 / breathe)
	for s in [-1, 1]:
		c.ell(s * 11, 15.4, 7.4, 4.6); c.sh(cream)
		c.ell(s * 11, 15.6, 3.6, 2.4); c.fill("#c8a878")
		for k in [-2.6, 0.0, 2.6]:
			c.ell(s * 11 + k, 11.8, 1, .8); c.fill("#c8a878")
		for k in [-1.6, 0.0, 1.6]:
			c.poly([[s * (17 + k * .3), 2 + k], [s * 20.5, 4 + k * 1.2], [s * (17 + k * .3), 4 + k]]); c.fill("#fff")
	for s in [-1, 1]:
		c.ell(s * 17, 3, 5, 8.4, s * .35); c.sh(teal)
	c.ell(0, 4, 18.5, 15.5); c.sh(teal)
	c.ell(0, 7, 13.5, 11.5); c.sh(cream, null)
	if gmax:
		c.ell(0, 6, 9.5, 5); c.sh("#8a6a3a")
		c.ell(0, 0, 6.4, 5.2); c.sh("#5aa650")
		c.ell(-3.4, -1.4, 3.8, 3.2); c.sh("#7cc66a", null)
		c.ell(3, -2.2, 3, 2.6); c.sh("#6ab85a", null)
		for xy in [[-7, 9], [6, 9], [0, 11], [-2, -3], [3, 1]]:
			c.ell(xy[0], xy[1], 1.4, 1.4); c.fill("#ff8ab4")
	for s in [-1, 1]:
		c.poly([[s * 5, -18], [s * 10.5, -25], [s * 11, -15]]); c.sh(teal)
	c.ell(0, -12, 12.4, 9.4); c.sh(teal)
	c.begin(); c.move_to(-9, -9); c.bez_to(-8, -15, -3, -16, 0, -13); c.bez_to(3, -16, 8, -15, 9, -9); c.bez_to(8, -3, 4, -2.6, 0, -2.6); c.bez_to(-4, -2.6, -8, -3, -9, -9); c.close(); c.sh(cream, null)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 2, -10.6); c.quad_to(s * 4.4, -9.6, s * 6.8, -10.8); c.stroke(OUT, 1.4, true)
	c.begin(); c.move_to(-3.6, -6.4); c.quad_to(0, -5.4, 3.6, -6.4); c.stroke(OUT, 1.2)
	c.poly([[-2.4, -6.2], [-1.6, -4.6], [-.8, -6]]); c.fill("#fff"); c.poly([[.8, -6], [1.6, -4.6], [2.4, -6.2]]); c.fill("#fff")
	c.restore()


static func snorlax(c: Pen, t: float, _o := {}) -> void:
	_lax(c, t, false)


static func gmax_snorlax(c: Pen, t: float, _o := {}) -> void:
	_lax(c, t, true)


# ---------- Dratini line ----------
static func dratini(c: Pen, t: float, _o := {}) -> void:
	var blue := "#7aa4e8"
	var sw := sin(t * 3) * 2
	var path := func(): c.begin(); c.move_to(17, 14 + sw * .5); c.bez_to(4, 22, -14, 18, -10, 8); c.bez_to(-6, 0, 4, 2, 4, -6); c.bez_to(4, -10, 1, -13, -2, -14)
	path.call(); c.stroke(OUT, 10, true); path.call(); c.stroke(blue, 7.4, true)
	c.save(); c.translate(.8, 1.2)
	c.begin(); c.move_to(15, 15 + sw * .5); c.bez_to(4, 21, -12, 17, -8.6, 9); c.stroke("#eef2ff", 2.6, true)
	c.restore()
	c.ell(-4, -17, 7.6, 6.4); c.sh(blue)
	c.ell(-3, -12.6, 4.6, 2.8); c.sh("#eef2ff", null)
	c.ell(-4, -23, 1.4, 1.2); c.sh("#eef2ff", OUT, .8)
	for s in [-1, 1]:
		c.save(); c.translate(-4 + s * 7, -18); c.rotate(s * .2)
		c.begin(); c.move_to(0, 0); c.line_to(s * 5, -4); c.line_to(s * 3, 0); c.line_to(s * 6, 2); c.close(); c.sh("#f6f6ff", OUT, 1)
		c.restore()
	eye(c, -7, -17.6, 1.8, 2.3, "#5a2a8a"); eye(c, -1.2, -17.6, 1.8, 2.3, "#5a2a8a")
	c.begin(); c.move_to(-5.6, -13.4); c.quad_to(-4, -12.4, -2.4, -13.4); c.stroke(OUT, 1)


static func dragonair(c: Pen, t: float, _o := {}) -> void:
	var blue := "#5a8ae0"
	var sw := sin(t * 3) * 2
	var path := func(): c.begin(); c.move_to(20, 12 + sw * .5); c.bez_to(8, 24, -18, 20, -13, 7); c.bez_to(-9, -2, 6, 3, 5, -8); c.bez_to(4, -14, 0, -18, -3, -19)
	path.call(); c.stroke(OUT, 11, true); path.call(); c.stroke(blue, 8.4, true)
	c.save(); c.translate(.8, 1.2)
	c.begin(); c.move_to(18, 13 + sw * .5); c.bez_to(8, 23, -16, 19, -11.6, 8); c.stroke("#eef2ff", 2.8, true)
	c.restore()
	c.ell(21, 12 + sw * .5, 3, 3); c.sh("#4ab0f0", "#1a4a8a", 1)
	c.ell(3, -6, 2.6, 2.6); c.sh("#4ab0f0", "#1a4a8a", 1)
	c.ell(-5, -22, 7.6, 6.2); c.sh(blue)
	c.ell(-4, -17.8, 4.6, 2.8); c.sh("#eef2ff", null)
	c.poly([[-6.6, -27], [-5, -34], [-3.2, -27]]); c.sh("#f6f6ff", OUT, 1)
	for s in [-1, 1]:
		c.save(); c.translate(-5 + s * 7.4, -23); c.rotate(s * -.35)
		c.begin(); c.move_to(0, 0); c.quad_to(s * 4, -4, s * 8, -3); c.quad_to(s * 6, -1, s * 7, 1); c.quad_to(s * 4, 0, 0, 1.6); c.close(); c.sh("#f6f6ff", OUT, 1)
		c.restore()
	eye(c, -8, -22.4, 1.7, 2.2, "#5a2a8a"); eye(c, -2, -22.4, 1.7, 2.2, "#5a2a8a")
	c.begin(); c.move_to(-6.4, -18.4); c.quad_to(-4.8, -17.4, -3.2, -18.4); c.stroke(OUT, 1)


static func dragonite(c: Pen, t: float, _o := {}) -> void:
	var orange := "#f0a050"
	var flap := sin(t * 6) * .12
	for s in [-1, 1]:
		c.save(); c.translate(s * 7, -5); c.rotate(s * (.4 + flap))
		c.begin(); c.move_to(0, 0); c.quad_to(s * 6, -9, s * 14, -9); c.line_to(s * 12, -4); c.line_to(s * 15, -1); c.quad_to(s * 8, 3, 0, 2); c.close(); c.sh("#3aa89a")
		c.begin(); c.move_to(0, 0); c.quad_to(s * 6, -9, s * 14, -9); c.stroke(orange, 1.6)
		c.restore()
	c.begin(); c.move_to(6, 12); c.bez_to(16, 18, 22, 10, 21, 4); limb(c, orange, 5)
	c.ell(-6.4, 17.4, 5.2, 3); c.sh(orange); c.ell(6.4, 17.4, 5.2, 3); c.sh(orange)
	c.begin(); c.move_to(-9, -4); c.bez_to(-14, 4, -13, 17, 0, 17.5); c.bez_to(13, 17, 14, 4, 9, -4); c.close(); c.sh(orange)
	c.ell(0, 8.6, 8, 8.4); c.sh("#f6e0a8", null)
	for i in 4:
		var y := 3.0 + i * 3.6
		var hw := 7.6 * sqrt(maxf(0, 1 - pow((y - 8.6) / 8.4, 2)))
		c.begin(); c.move_to(-hw, y); c.quad_to(0, y + 1, hw, y); c.stroke("#c8a060", .9)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 9, 0); c.quad_to(s * 13, 4, s * 11, 8); limb(c, orange, 3.4)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 3, -17); c.quad_to(s * 5, -25, s * 10, -26); limb(c, orange, 1)
		c.ell(s * 10.4, -26, 1.4, 1.2); c.sh(orange, OUT, .8)
	c.begin(); c.move_to(-9, -10); c.bez_to(-9, -18, -4, -19, 0, -19); c.bez_to(5, -19, 9, -17, 9, -10); c.bez_to(9, -6, 5, -4, 0, -4); c.bez_to(-5, -4, -9, -6, -9, -10); c.close(); c.sh(orange)
	c.ell(0, -6.4, 5.4, 3.2); c.sh("#f6e0a8", null)
	eye(c, -4, -11.4, 1.7, 2.2); eye(c, 4, -11.4, 1.7, 2.2)
	c.ell(-1.4, -7.6, .5, .4); c.fill(OUT); c.ell(1.4, -7.6, .5, .4); c.fill(OUT)
	c.begin(); c.move_to(-3.6, -5.4); c.quad_to(0, -2.8, 3.6, -5.4); c.stroke(OUT, 1.1)



# ---------- Eevee line ----------
static func _vee_body(c: Pen, body: String, legs := true) -> void:
	if legs:
		for s in [-1, 1]:
			c.begin(); c.move_to(s * 3.6, 9); c.line_to(s * 4.4, 15.6); limb(c, body, 3.2)
			c.ell(s * 4.8, 17.4, 3.4, 2.2); c.sh(body, OUT, 1.2)
	c.begin(); c.move_to(-6, 2); c.bez_to(-9, 8, -8, 16, -1, 16); c.bez_to(6, 16, 9, 9, 6, 2); c.close(); c.sh(body)


static func _vee_face(c: Pen, y: float, iris: String, fierce := 0.0) -> void:
	for s in [-1, 1]:
		c.ell(s * 4.4, y, 2.5, 3.1 - fierce * .4); c.fill(iris)
		c.ell(s * 4.4, y + .3, 1.4, 1.9 - fierce * .3); c.fill(INK)
		c.ell(s * 4.4 + .8, y - 1.1, .8, .9); c.fill("#fff")
		if fierce > 0:
			c.begin(); c.move_to(s * 1.6, y - 3.2); c.line_to(s * 7.4, y - 3.6 - fierce); c.stroke(OUT, 1.1)
	c.ell(0, y + 3.4, .9, .6); c.fill(OUT)
	c.begin(); c.move_to(-2.2, y + 4.8); c.quad_to(-1.1, y + 6, 0, y + 4.8); c.quad_to(1.1, y + 6, 2.2, y + 4.8); c.stroke(OUT, 1)


static func _vee_head(c: Pen, body: String, y: float) -> void:
	c.begin(); c.move_to(-11, y); c.bez_to(-11, y - 9, -5, y - 10, 0, y - 10); c.bez_to(5, y - 10, 11, y - 9, 11, y)
	c.bez_to(11, y + 6, 5, y + 8.5, 0, y + 8.5); c.bez_to(-5, y + 8.5, -11, y + 6, -11, y); c.close(); c.sh(body)


static func eevee(c: Pen, t: float, _o := {}) -> void:
	var body := "#b8834a"
	var sw := sin(t * 2.5) * .08
	c.save(); c.translate(6, 11); c.rotate(.55 + sw)
	c.begin(); c.move_to(0, 0); c.bez_to(2, -7, 0, -14, 1, -19); c.bez_to(13, -17, 16, -6, 9, 0); c.close(); c.sh(body)
	c.begin(); c.move_to(1, -19); c.bez_to(7, -18.5, 11, -16, 13, -11); c.bez_to(8, -12, 4, -14, 1, -19); c.close(); c.sh(CREAM, null)
	c.restore()
	_vee_body(c, body)
	c.begin()
	for i in 11:
		var a := PI * .05 + i * PI * .09
		var r := 10.0 if i % 2 else 7.0
		c.line_to(cos(a) * r * 1.05, 1 + sin(a) * r * .85)
	c.close(); c.sh(CREAM)
	for s in [-1, 1]:
		c.save(); c.translate(s * 6.5, -12); c.rotate(s * .5)
		c.begin(); c.move_to(-4.4, 1); c.bez_to(-5.4, -8, -2, -15, 0, -16); c.bez_to(2, -15, 5.4, -8, 4.4, 1); c.close(); c.sh(body)
		c.begin(); c.move_to(-2.2, 0); c.bez_to(-3, -6, -1, -11, 0, -12); c.bez_to(1, -11, 3, -6, 2.2, 0); c.close(); c.fill("#5a3a1c")
		c.restore()
	_vee_head(c, body, -5)
	_vee_face(c, -6.6, "#5a2a14")


static func vaporeon(c: Pen, t: float, _o := {}) -> void:
	var body := "#6cc2ea"
	var frill := "#f2f6ff"
	var sw := sin(t * 3) * 2
	c.begin(); c.move_to(5, 12); c.bez_to(15, 15, 20, 7, 20 + sw, -1); limb(c, body, 4.2)
	c.begin(); c.move_to(20 + sw, -1); c.quad_to(25 + sw, -9, 29 + sw, -10); c.quad_to(27 + sw, -3, 30 + sw, 3); c.quad_to(24 + sw, 2, 20 + sw, -1); c.close(); c.sh(body)
	c.begin(); c.move_to(1, 2); c.quad_to(5, -6, 12, -4); c.quad_to(9, 0, 7, 4); c.close(); c.sh("#3a8ac0")
	_vee_body(c, body)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 3, -1); c.quad_to(s * 10, -2, s * 13, 2); c.quad_to(s * 9, 3, s * 10, 6); c.quad_to(s * 6, 3, s * 3, 3); c.close(); c.sh(frill)
	for s in [-1, 1]:
		c.save(); c.translate(s * 9, -10); c.rotate(s * 1.0)
		c.begin(); c.move_to(-4, 2); c.quad_to(-6, -6, 0, -12); c.quad_to(6, -6, 4, 2); c.close(); c.sh(frill)
		for k in [-2, 0, 2]:
			c.begin(); c.move_to(k * .6, 0); c.line_to(k * 1.2, -8); c.stroke("#9ac8e8", .8)
		c.restore()
	c.begin(); c.move_to(-5, -12); c.quad_to(0, -23, 6, -13); c.quad_to(0, -15, -5, -12); c.close(); c.sh(frill)
	_vee_head(c, body, -5)
	c.ell(0, -1.5, 5.4, 3); c.sh("#a8e0f6", null)
	_vee_face(c, -6.6, "#1a3a6a")


static func jolteon(c: Pen, t: float, _o := {}) -> void:
	var body := "#f5d143"
	c.poly([[5, 9], [16, 0], [14, 7], [23, 4], [16, 12], [22, 15], [7, 15]]); c.sh("#fbfbf0")
	_vee_body(c, body)
	c.poly([[-7, 1], [-13, 3], [-8, 5], [-11, 9], [-5, 7], [-3, 11], [0, 6], [3, 11], [5, 7], [11, 9], [8, 5], [13, 3], [7, 1]]); c.sh("#fbfbf0")
	for s in [-1, 1]:
		c.save(); c.translate(s * 6.5, -12); c.rotate(s * .5)
		c.poly([[-3.8, 1], [0, -17], [3.8, 1]]); c.sh(body)
		c.poly([[-1.6, -1], [0, -10], [1.6, -1]]); c.fill("#2a2a2a")
		c.restore()
	c.poly([[-6, -13], [-3, -18], [-1, -14], [2, -19], [3, -13], [7, -16], [5, -11]]); c.sh(body)
	_vee_head(c, body, -5)
	for s in [-1, 1]:
		c.poly([[s * 10, -3], [s * 15, -1], [s * 10, 1]]); c.sh(body)
	_vee_face(c, -6.6, "#3a1a10", 1)
	if int(t * 4) % 3 == 0:
		c.begin(); c.move_to(-15, -12); c.line_to(-18, -8); c.line_to(-15, -8); c.line_to(-18, -4); c.stroke("#fff38a", 1.5)


static func flareon(c: Pen, t: float, _o := {}) -> void:
	var body := "#ef6b32"
	var fluff := "#fbe4a0"
	var sw := sin(t * 3) * 1.2
	_crag(c, 15, 2 + sw, 8, 10.5, 14, 7); c.sh(fluff)
	c.begin(); c.move_to(11, 7 + sw); c.quad_to(15, 1 + sw, 18, -5 + sw); c.stroke(Color(fluff).darkened(.2), 1)
	_vee_body(c, body)
	_crag(c, 0, 2, 11, 7.5, 16, 3); c.sh(fluff)
	for s in [-1, 1]:
		c.save(); c.translate(s * 7, -12); c.rotate(s * .45)
		c.begin(); c.move_to(-4.6, 1); c.bez_to(-5.4, -8, -2, -15, 0, -16); c.bez_to(2, -15, 5.4, -8, 4.6, 1); c.close(); c.sh(body)
		c.begin(); c.move_to(-2.2, 0); c.bez_to(-3, -6, -1, -11, 0, -12); c.bez_to(1, -11, 3, -6, 2.2, 0); c.close(); c.fill("#a83a18")
		c.restore()
	_vee_head(c, body, -5)
	_crag(c, 0, -15.5, 4.4, 2.6, 10, 2); c.sh(fluff)
	_vee_face(c, -6.4, "#3a1a10")


# ---------- Ditto ----------
static func ditto(c: Pen, t: float, _o := {}) -> void:
	var w := 1 + sin(t * 2.6) * .05
	c.save(); c.scale(w, 1 / w)
	c.begin(); c.move_to(-15, 17)
	c.bez_to(-19, 6, -14, -6, -9, -8); c.bez_to(-8, -15, -2, -16, 1, -11); c.bez_to(6, -16, 13, -12, 11, -5); c.bez_to(18, 0, 19, 12, 15, 17)
	c.close(); c.sh("#b48ad8", "#5a3a8a", 1.5, 1.4)
	for s in [-1, 1]:
		c.ell(s * 15, 12, 3.6, 2.4, s * .5); c.sh("#b48ad8", "#5a3a8a", 1.2)
	c.ell(-6, -4, 3.4, 1.6, -.4); c.fill(Color(1, 1, 1, .4))
	c.ell(-4, 2, 1.1, 1.2); c.fill("#2a1a3a"); c.ell(4, 2, 1.1, 1.2); c.fill("#2a1a3a")
	c.begin(); c.move_to(-5.4, 7); c.bez_to(-2, 9.6, 2, 9.6, 6, 6.4); c.stroke("#2a1a3a", 1.1)
	c.restore()


# ---------- Chansey line ----------
static func _egg_pouch(c: Pen, t: float, y: float, line: String) -> void:
	var bob := sin(t * 2) * .4
	c.ell(0, y + 3.4 + bob, 3.6, 4.4); c.sh("#ffffff", "#c8a890", 1)
	c.begin(); c.move_to(-7.5, y + 4 + bob); c.quad_to(0, y + 2 + bob, 7.5, y + 4 + bob); c.bez_to(7, y + 10 + bob, -7, y + 10 + bob, -7.5, y + 4 + bob); c.close(); c.sh("#fff6ee", line, 1.2)
	for s in [-1, 1]:
		c.ell(s * 5, y + 4 + bob, 2.6, 2.2); c.sh("#f5a9c0", line, 1.1)


static func _chansey_face(c: Pen, y: float, line: String) -> void:
	for s in [-1, 1]:
		c.ell(s * 5, y, 1.8, 2.4); c.fill("#3a1020")
		c.ell(s * 5 + .6, y - 1, .7, .8); c.fill("#fff")
		c.ell(s * 9, y + 4, 2.4, 1.4); c.fill(Color("#ff6a90", .5))
	c.begin(); c.move_to(-2.8, y + 4); c.quad_to(0, y + 7, 2.8, y + 4); c.quad_to(0, y + 5, -2.8, y + 4); c.fs("#c8486a", line, 1)


static func chansey(c: Pen, t: float, _o := {}) -> void:
	var pink := "#f5a9c0"
	var line := "#a04a68"
	c.ell(-6.4, 17.8, 4.8, 2.6); c.sh(pink, line, 1.2); c.ell(6.4, 17.8, 4.8, 2.6); c.sh(pink, line, 1.2)
	for s in [-1, 1]:
		for k in 3:
			c.begin(); c.move_to(s * 11, -6 + k * 4.4); c.quad_to(s * 17, -8 + k * 4.4, s * 17.4, -4 + k * 4.4); c.quad_to(s * 14, -3 + k * 4.4, s * 11, -2 + k * 4.4); c.close(); c.sh(pink, line, 1.1)
	c.begin(); c.move_to(0, -18); c.bez_to(10, -18, 15, -6, 15, 4); c.bez_to(15, 13, 8, 18, 0, 18); c.bez_to(-8, 18, -15, 13, -15, 4); c.bez_to(-15, -6, -10, -18, 0, -18); c.close(); c.sh(pink, line, 1.3)
	for s in [-1, 1]:
		c.ell(s * 11, 2, 2.6, 3.6, s * -.5); c.sh(pink, line, 1.1)
	_egg_pouch(c, t, 3, line)
	_chansey_face(c, -7, line)


static func blissey(c: Pen, t: float, _o := {}) -> void:
	var pink := "#f7b4c8"
	var line := "#a04a68"
	c.ell(-6.6, 18, 5, 2.6); c.sh(pink, line, 1.2); c.ell(6.6, 18, 5, 2.6); c.sh(pink, line, 1.2)
	c.begin(); c.move_to(-14, -1); c.bez_to(-17, 13, -10, 18.5, 0, 18.5); c.bez_to(10, 18.5, 17, 13, 14, -1); c.close(); c.sh("#fff6f8", line, 1.3)
	c.begin(); c.move_to(-12, 9); c.quad_to(0, 13, 12, 9); c.stroke(Color(line, .5), 1)
	for s in [-1, 1]:
		c.begin(); c.move_to(s * 10, -14); c.bez_to(s * 20, -20, s * 22, -8, s * 16, -6); c.bez_to(s * 19, -10, s * 15, -12, s * 13, -9); c.close(); c.sh(pink, line, 1.2)
		c.ell(s * 13, 2, 3, 3.6, s * -.4); c.sh(pink, line, 1.1)
	c.ell(0, -6, 14, 12); c.sh(pink, line, 1.3)
	c.begin(); c.move_to(-3, -17); c.quad_to(0, -23, 3, -17); c.stroke(line, 1.2)
	_egg_pouch(c, t, 1, line)
	_chansey_face(c, -9, line)
