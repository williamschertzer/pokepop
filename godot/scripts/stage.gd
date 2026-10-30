class_name Stage
extends Control
## The game field. Draws the map, balls, Pokémon and effects, and turns clicks
## and taps into placing or selecting Pokémon.

signal tower_clicked(tw)  # Game.Tower or null
signal place_requested(x: float, y: float, keep: bool)
signal touch_preview(x: float, y: float)
signal obstacle_clicked(o: Dictionary)

const W := Data.W
const H := Data.H

var game: Game
var placing := ""
var ghost = null  # Vector2 or null
var ghost_touch := false
var selected = null  # Game.Tower or null
var sel_obs = null  # obstacle Dictionary or null
var hit_pad := 0.0  # extra reach for fingers when the field is drawn small (phones)

var _bg_layer: Control
var _fx_layer: Control
var _last_touch := -10000
var _last_cd := {}  # tower id -> cooldown last frame, to spot when it attacks
var _kick := {}  # tower id -> attack animation time left


func _init() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg_layer = Control.new()
	_bg_layer.size = Vector2(W, H)
	_bg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_layer.draw.connect(_draw_bg)
	add_child(_bg_layer)
	_fx_layer = Control.new()
	_fx_layer.size = Vector2(W, H)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.draw.connect(_draw_world)
	add_child(_fx_layer)


func refresh_bg() -> void:
	_bg_layer.queue_redraw()


func _process(_dt: float) -> void:
	var off := Vector2.ZERO
	if game and game.shake > 0:
		off = Vector2((randf() - .5) * game.shake, (randf() - .5) * game.shake)
	_bg_layer.position = off
	_fx_layer.position = off
	_fx_layer.queue_redraw()


# ---------- input ----------
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_last_touch = Time.get_ticks_msec()


func _gui_input(event: InputEvent) -> void:
	if not game or not game.map:
		return
	var touch := Time.get_ticks_msec() - _last_touch < 600
	if event is InputEventMouseMotion:
		if event.device == -1 or touch:
			touch = true
		var p: Vector2 = event.position
		if placing != "" and not touch:
			ghost = p
		var over_tower := false
		for tw in game.towers:
			if Vector2(tw.x, tw.y).distance_to(p) < 20:
				over_tower = true
		if placing == "":
			var o = game.obstacle_at(p.x, p.y)
			if o != null and Data.OBSTACLES.has(o.kind):
				over_tower = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if over_tower else Control.CURSOR_CROSS
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == -1:
			touch = true
		if game.over:
			return
		var p: Vector2 = event.position
		if placing != "":
			if touch:
				if ghost != null and ghost_touch and ghost.distance_to(p) < 30 + hit_pad * 1.5:
					place_requested.emit(ghost.x, ghost.y, false)
				else:
					ghost = p
					ghost_touch = true
					touch_preview.emit(p.x, p.y)
			else:
				place_requested.emit(p.x, p.y, event.shift_pressed)
			accept_event()
			return
		var hit = null
		for i in range(game.towers.size() - 1, -1, -1):
			var tw = game.towers[i]
			if Vector2(tw.x, tw.y).distance_to(p) < 22 + (hit_pad if touch else 0.0):
				hit = tw
				break
		if hit == null:
			var o = game.obstacle_at(p.x, p.y, 4 + (hit_pad if touch else 0.0))
			if o != null and Data.OBSTACLES.has(o.kind):
				obstacle_clicked.emit(o)
				accept_event()
				return
		tower_clicked.emit(hit)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and not ghost_touch:
		ghost = null


# ---------- drawing helpers ----------
static func ell_pts(cx: float, cy: float, rx: float, ry: float, rot := 0.0, n := 24) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cr := cos(rot)
	var sr := sin(rot)
	for i in n:
		var a := TAU * i / n
		var ex := cos(a) * rx
		var ey := sin(a) * ry
		out.append(Vector2(cx + ex * cr - ey * sr, cy + ex * sr + ey * cr))
	return out


static func fill_ell(ci: CanvasItem, cx: float, cy: float, rx: float, ry: float, col: Color, rot := 0.0) -> void:
	ci.draw_colored_polygon(ell_pts(cx, cy, rx, ry, rot), col)


static func stroke_ell(ci: CanvasItem, cx: float, cy: float, rx: float, ry: float, col: Color, w: float, rot := 0.0) -> void:
	var p := ell_pts(cx, cy, rx, ry, rot, 40)
	p.append(p[0])
	ci.draw_polyline(p, col, w, true)


static func dashed_circle(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float, on: float, off: float, offset := 0.0) -> void:
	var circ := TAU * r
	if circ <= 0:
		return
	var pos := fposmod(offset, on + off)
	var a := -pos / r
	while a < TAU:
		var a2 := minf(a + on / r, TAU)
		if a2 > 0:
			ci.draw_arc(c, r, maxf(a, 0), a2, maxi(2, int((a2 - maxf(a, 0)) * r / 4)), col, w, true)
		a += (on + off) / r


static func text(ci: CanvasItem, s: String, x: float, y: float, size: int, col: Color, display := false, outline := 0, outline_col := Color.BLACK) -> void:
	var f: Font = Pen.font_display if display else Pen.font_body
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := Vector2(x - w / 2, y + (f.get_ascent(size) - f.get_descent(size)) / 2)
	if outline > 0:
		ci.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, outline_col)
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static var _glow_tex: Texture2D


## Soft round glow fading from col at the centre to transparent at radius r.
static func glow(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(.5, .5)
		gt.fill_to = Vector2(1, .5)
		gt.width = 128
		gt.height = 128
		_glow_tex = gt
	ci.draw_texture_rect(_glow_tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2), false, col)


# ---------- drawing ----------
## Small moving touches that make each map feel alive. Purely visual.
func _draw_ambience(ci: CanvasItem, theme: String, gt: float) -> void:
	match theme:
		"route":
			for i in 4:
				var x := fposmod(gt * 22 + i * 260, W + 80) - 40
				var y := 80 + i * 130 + sin(gt * 1.3 + i * 2) * 30
				var flap := absf(sin(gt * 14 + i)) * 4 + 1
				var col: Color = [Color("#fff6a8"), Color("#ffffff"), Color("#ffc0e0"), Color("#c0e8ff")][i]
				fill_ell(ci, x - 3, y, 3, flap, col)
				fill_ell(ci, x + 3, y, 3, flap, col)
		"forest":
			for i in 14:
				var x := fposmod(i * 173.0 + sin(gt * .3 + i) * 40, W)
				var y := fposmod(i * 97.0 + cos(gt * .25 + i * 1.7) * 30, H)
				var a := .25 + .35 * maxf(0, sin(gt * 1.6 + i * 2.3))
				glow(ci, Vector2(x, y), 10, Color(.85, 1, .4, a))
				ci.draw_circle(Vector2(x, y), 1.5, Color(1, 1, .7, a + .2))
		"lavender":
			for i in 6:
				var x := fmod(gt * 12 + i * 190, W + 300) - 150
				var y := 90 + i * 85 + sin(gt * .4 + i) * 20
				glow(ci, Vector2(x, y), 150, Color(230 / 255.0, 220 / 255.0, 1, .16))
			for i in 4:
				var x := fposmod(i * 251.0 + gt * 9, W)
				var y := fposmod(H - gt * 14 - i * 150, H)
				glow(ci, Vector2(x, y), 9, Color(.75, .6, 1, .45))
		"cave":
			for i in 12:
				var x := fposmod(i * 211.0 + 37, W)
				var y := fposmod(i * 131.0 + 53, H)
				var a := maxf(0, sin(gt * 2 + i * 1.9))
				if a > .6:
					var r := 4 * (a - .6) / .4 + 1
					ci.draw_line(Vector2(x - r * 2, y), Vector2(x + r * 2, y), Color(.8, .9, 1, a), 1.2, true)
					ci.draw_line(Vector2(x, y - r * 2), Vector2(x, y + r * 2), Color(.8, .9, 1, a), 1.2, true)


func _draw_bg() -> void:
	var ci := _bg_layer
	if game and game.map:
		Pen.draw_baked(ci, game.bg)
		Pen.draw_baked(ci, game.obs_bg)
		Pen.draw_baked(ci, game.top_bg)
	else:
		ci.draw_rect(Rect2(0, 0, W, H), Color("#0b0d20"))


func _show_range(ci: CanvasItem, x: float, y: float, r: float, valid: bool) -> void:
	ci.draw_circle(Vector2(x, y), r, Color(1, 1, 1, .12) if valid else Color(1, 80 / 255.0, 80 / 255.0, .18))
	dashed_circle(ci, Vector2(x, y), r, Color(1, 1, 1, .55) if valid else Color(1, 90 / 255.0, 90 / 255.0, .7), 1.5, 6, 6)


func _draw_bolt(ci: CanvasItem, pts: Array, col: Color, w: float) -> void:
	var line := PackedVector2Array([pts[0]])
	for i in range(1, pts.size()):
		var p0: Vector2 = pts[i - 1]
		var p1: Vector2 = pts[i]
		for k in range(1, 5):
			var q := p0.lerp(p1, k / 4.0)
			var j := 0.0 if k == 4 else 9.0
			line.append(q + Vector2((randf() - .5) * j, (randf() - .5) * j))
	var c1 := col
	c1.a = .35
	ci.draw_polyline(line, c1, w + 3, true)
	ci.draw_polyline(line, Color.WHITE, w * .6, true)
	ci.draw_polyline(line, col, w * .4, true)


func _draw_world() -> void:
	var ci := _fx_layer
	if not game or not game.map:
		return
	var g := game
	var gt := g.t
	if selected:
		_show_range(ci, selected.x, selected.y, selected.s.range, true)
	# Team Rocket start marker
	var sp := g.start_pt
	ci.draw_circle(sp, 15, Color("#1d1d24"))
	ci.draw_arc(sp, 15, 0, TAU, 40, Color("#e2262b"), 3, true)
	text(ci, "R", sp.x, sp.y + 1, 18, Color("#e2262b"), true)
	# Geodude's rocks on the path
	for rk in g.traps:
		var k := clampf(rk.uses / 6.0, .55, 1.0)
		var pts := PackedVector2Array()
		for i in 6:
			var a: float = rk.rot + i * TAU / 6
			pts.append(Vector2(rk.x + cos(a) * 6 * k * (1.0 if i % 2 else .8), rk.y + sin(a) * 5 * k))
		ci.draw_colored_polygon(pts, Color("#8c8476"))
		pts.append(pts[0])
		ci.draw_polyline(pts, Color("#3a342c"), 1.2, true)
	# balls
	for b in g.balls:
		var def: Dictionary = b.def
		var r: float = def.r
		fill_ell(ci, b.x, b.y + r * .85, r * .8, r * .28, Color(0, 0, 0, .22))
		# balls roll along the path; the balloon just sways
		var rot: float = sin(b.wob) * .06 if b.type == "rocket" else b.d / r
		var al := 1.0
		if def.get("hidden", false):
			al = .55 + .15 * sin(gt * 4 + b.id)
		Art.put_ball(ci, b.type, b.x, b.y, rot, 1.0, al)
		if b.sleep > 0:
			text(ci, "z", b.x + r * .6, b.y - r - fmod(gt * 20, 8) - 4, 11, Color.WHITE, true)
		if b.freeze > 0:
			ci.draw_circle(Vector2(b.x, b.y), r + 3, Color(.75, .95, 1, .5))
			ci.draw_arc(Vector2(b.x, b.y), r + 3, 0, TAU, 24, Color(.9, 1, 1, .9), 1.5, true)
			ci.draw_line(Vector2(b.x - r * .4, b.y - r * .5), Vector2(b.x - r * .1, b.y - r * .2), Color.WHITE, 1.5)
		if b.broken:
			ci.draw_polyline(PackedVector2Array([Vector2(b.x - 4, b.y - r + 2), Vector2(b.x, b.y - 4), Vector2(b.x - 2, b.y + 2), Vector2(b.x + 3, b.y + r - 3)]), Color("#16161a"), 1.4)
		if b.def.get("regen", false) and b.hp < b.max_hp:
			ci.draw_arc(Vector2(b.x, b.y), r + 4, -PI / 2, -PI / 2 + TAU * b.hp / b.max_hp, 24, Color("#ff8ab4"), 2, true)
		if b.burn and randf() < .5:
			g.parts.append({"x": b.x + (randf() - .5) * r, "y": b.y, "vx": 0.0, "vy": -40.0, "life": .25, "max": .25, "col": Color("#ff8a1f"), "size": 2.0})
		if def.get("boss", false):
			var w := 46.0
			ci.draw_rect(Rect2(b.x - w / 2, b.y - r - 12, w, 5), Color(0, 0, 0, .6))
			ci.draw_rect(Rect2(b.x - w / 2, b.y - r - 12, w * clampf(b.hp / b.max_hp, 0, 1), 5), Color("#e85aa8"))
		if b.slow < 1:
			ci.draw_arc(Vector2(b.x, b.y), r + 2, 0, TAU, 32, Color(176 / 255.0, 122 / 255.0, 1, .6), 2, true)
	# Ash's Pikachu at the end of the route
	var ep := g.end_pt
	var al2 := g.alarm > 0
	Art.put_mon(ci, "ashpika", ep.x + ((randf() - .5) * 4 if al2 else 0.0), ep.y, 1, ep.x > W / 2, gt)
	if al2:
		var bubble := StyleBoxFlat.new()
		bubble.bg_color = Color.WHITE
		bubble.border_color = Color("#e2262b")
		bubble.set_border_width_all(2)
		bubble.set_corner_radius_all(5)
		ci.draw_style_box(bubble, Rect2(ep.x + 10, ep.y - 48, 18, 22))
		text(ci, "!", ep.x + 19, ep.y - 37, 16, Color("#e2262b"))
	# wild Snorlax napping on the map
	for o in g.obs:
		if o.kind == "sleeper":
			fill_ell(ci, o.x + 3, o.y + 24, 34, 9, Color(0, 0, 0, .25))
			Art.put_mon(ci, "snorlax", o.x, o.y, 1.55, o.v < .5, 0.0)
			for i in 3:
				var zk := fmod(gt * .5 + i / 3.0, 1.0)
				var zc := Color(1, 1, 1, sin(zk * PI))
				text(ci, "z" if i % 2 else "Z", o.x + 18 + zk * 18, o.y - 30 - zk * 30, int(10 + zk * 8), zc, true, 3, Color(16 / 255.0, 18 / 255.0, 40 / 255.0, .7 * zc.a))
	if sel_obs != null and g.obs.has(sel_obs):
		dashed_circle(ci, Vector2(sel_obs.x, sel_obs.y), sel_obs.r + 8, Color("#ffd23f"), 2.5, 6, 5, -gt * 20)
	# Pokémon
	var ts: Array = g.towers.duplicate()
	ts.sort_custom(func(a, b): return a.y < b.y)
	for tw in ts:
		var spn := Data.sprite_for(tw.kind, tw.a)
		var ditto_copy: bool = tw.kind == "ditto" and tw.copy != ""
		if ditto_copy:
			spn = Data.sprite_for(tw.copy, tw.s.copyTier)
		if tw == selected:
			stroke_ell(ci, tw.x, tw.y + 15, 18, 6, Color("#ffd23f"), 2)
		var pop := minf(1, (gt - tw.born) * 5)
		var opt := {"shades": tw.kind == "squirtle" and tw.b >= 2, "conf": tw.conf, "amulet": tw.kind == "meowth" and tw.a >= 2}
		# a little hop forward each time it attacks
		var last: float = _last_cd.get(tw.id, 0.0)
		if tw.cd > last + .05:
			_kick[tw.id] = .16
		_last_cd[tw.id] = tw.cd
		var kick: float = _kick.get(tw.id, 0.0)
		if kick > 0:
			_kick[tw.id] = kick - get_process_delta_time() * g.speed
		var kk := sin(clampf(kick / .16, 0, 1) * PI)
		var px: float = tw.x + tw.face * 4 * kk
		var py: float = tw.y - 2 * kk
		if tw.rush > 0 or tw.outr > 0:
			glow(ci, Vector2(tw.x, tw.y - 4), 26, Color(1, .45, .25, .35) if tw.rush > 0 else Color(.7, .5, 1, .4))
		if tw.buffed:
			glow(ci, Vector2(tw.x, tw.y + 12), 14, Color(1, .55, .85, .35 + .1 * sin(gt * 3 + tw.id)))
		if ditto_copy:
			glow(ci, Vector2(tw.x, tw.y - 2), 24, Color(.75, .5, 1, .3 + .08 * sin(gt * 4 + tw.id)))
		if tw.s.safeguard and tw.timers.get("sg", 0.0) <= 0:
			ci.draw_arc(Vector2(tw.x, tw.y - 2), 22, 0, TAU, 32, Color(1, .7, .82, .5 + .2 * sin(gt * 4)), 2, true)
		if tw.kind == "snorlax" and tw.down > 0:
			Art.put_mon(ci, spn, px + 20, py + 4, .85, tw.face < 0, gt + tw.id, .75, opt)
			text(ci, "Z", px + 30, py - 24 - fmod(gt * 14, 10), 12, Color.WHITE, true, 3, Color(0, 0, 0, .5))
		else:
			var breath := 1 + .025 * sin(gt * 3 + tw.id)
			var sc := (.75 + .25 * pop) * (1 + .06 * kk)
			# breathing: stretch a touch taller, keeping the feet on the ground
			ci.draw_set_transform(Vector2(px, py + 18 * sc * (1 - breath)), 0, Vector2(-sc if tw.face < 0 else sc, sc * breath))
			Pen.draw_baked(ci, Art.mon(spn, gt + tw.id, opt))
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		if tw.kind == "snorlax" and tw.down <= 0 and tw.hold < tw.s.hold:
			var w := 30.0
			ci.draw_rect(Rect2(tw.x - w / 2, tw.y + 22, w, 4), Color(0, 0, 0, .55))
			ci.draw_rect(Rect2(tw.x - w / 2, tw.y + 22, w * clampf(tw.hold / tw.s.hold, 0, 1), 4), Color("#7be3a2"))
		if ditto_copy:
			# a little Ditto riding along, so a copy is easy to tell apart
			Art.put_mon(ci, "ditto", tw.x + 13, tw.y + 12, .42, false, gt + tw.id)
		# upgrade pips: gold for the first path, blue for the second
		for i in tw.a:
			ci.draw_circle(Vector2(tw.x - 12 + i * 5, tw.y + 21), 1.8, Color("#ffd23f"))
		for i in tw.b:
			ci.draw_circle(Vector2(tw.x + 2 + i * 5, tw.y + 21), 1.8, Color("#7fb6ff"))
		if tw.s.solar and tw.timers.get("b", 1.0) < 1 and g.running:
			var k := 1.0 - maxf(0, tw.timers.get("b", 1.0))
			glow(ci, Vector2(tw.x, tw.y - 10), 22 * k + 6, Color(1, 248 / 255.0, 200 / 255.0, .25 + .5 * k))
		if tw.kind == "pikachu" and tw.a == 2:
			var lx: float = tw.x + 12 * (-1 if tw.face < 0 else 1)
			glow(ci, Vector2(lx, tw.y + 8), 9, Color(1, 243 / 255.0, 138 / 255.0, .6))
			ci.draw_circle(Vector2(lx, tw.y + 8), 3.2, Color("#fff6a8"))
	# projectiles
	for p in g.proj:
		match p.kind:
			"leaf":
				ci.draw_set_transform(Vector2(p.x, p.y), p.rot, Vector2.ONE)
				fill_ell(ci, 0, 0, 6, 2.6, Color("#5cc24a"))
				stroke_ell(ci, 0, 0, 6, 2.6, Color("#1f6a2a"), 1)
				ci.draw_line(Vector2(-5, 0), Vector2(5, 0), Color("#1f6a2a"), 1, true)
				ci.draw_set_transform_matrix(Transform2D.IDENTITY)
			"water":
				var a := atan2(p.ty - p.y, p.tx - p.x)
				ci.draw_set_transform(Vector2(p.x, p.y), a, Vector2.ONE)
				ci.draw_rect(Rect2(-18, -2.5, 18, 5), Color(90 / 255.0, 170 / 255.0, 1, .45))
				fill_ell(ci, 0, 0, 5, 3.6, Color("#4aa3f0"))
				fill_ell(ci, 1, -1, 2, 1.2, Color("#e6f6ff"))
				ci.draw_set_transform_matrix(Transform2D.IDENTITY)
			"coin":
				Art.coin(ci, p.x, p.y, 5, p.ph)
			"egg":
				ci.draw_set_transform(Vector2(p.x, p.y), p.rot, Vector2.ONE)
				fill_ell(ci, 0, 0, 4, 5, Color("#fffaf0"))
				stroke_ell(ci, 0, 0, 4, 5, Color("#8a7a60"), 1)
				fill_ell(ci, -1, -1.5, 1.2, 1.6, Color("#ffffff"))
				ci.draw_set_transform_matrix(Transform2D.IDENTITY)
			"rock":
				var rp := PackedVector2Array([Vector2(-5, -3), Vector2(0, -6), Vector2(5, -2), Vector2(4, 4), Vector2(-3, 5)])
				ci.draw_set_transform(Vector2(p.x, p.y), p.rot, Vector2.ONE)
				ci.draw_colored_polygon(rp, Color("#8c8476"))
				rp.append(rp[0])
				ci.draw_polyline(rp, Color("#3a342c"), 1.2, true)
				ci.draw_set_transform_matrix(Transform2D.IDENTITY)
			_:
				var r := 8.0 if p.big else 6.0
				glow(ci, Vector2(p.x, p.y), r * 2.2, Color(176 / 255.0, 122 / 255.0, 1, .5))
				ci.draw_circle(Vector2(p.x, p.y), r, Color("#2a1050"))
				ci.draw_circle(Vector2(p.x - .6, p.y - .6), r * .72, Color("#7a4ad0"))
				ci.draw_circle(Vector2(p.x - 1.2, p.y - 1.2), r * .36, Color("#e7d4ff"))
	# effects
	for f in g.fx:
		var k: float = 1 - f.life / f.max
		match f.kind:
			"bolt":
				_draw_bolt(ci, f.pts, f.col, f.w)
			"ring":
				var r: float = f.r + (f.to - f.r) * k
				if f.has("fill"):
					var fc: Color = f.fill
					fc.a = .35 * (1 - k)
					ci.draw_circle(Vector2(f.x, f.y), r, fc)
				var col: Color = f.col
				col.a = 1 - k
				ci.draw_arc(Vector2(f.x, f.y), r, 0, TAU, 48, col, f.get("w", 3), true)
			"flash":
				var col: Color = f.col
				col.a = .5 * (1 - k)
				ci.draw_rect(Rect2(0, 0, W, H), col)
			"gust", "jet", "ice", "dragon":
				var col: Color = f.get("col", Color.WHITE)
				var w: float = f.get("w", 3.0)
				if f.kind == "ice":
					col = Color("#c8f4ff")
				elif f.kind == "dragon":
					col = Color("#a98aff")
					w = 4.0
				col.a = 1 - k
				var p1 := Vector2(f.x1, f.y1)
				var p2 := Vector2(f.x2, f.y2)
				if f.kind == "gust":
					var dir := (p2 - p1).normalized()
					var nrm := Vector2(-dir.y, dir.x)
					for o in [-1, 0, 1]:
						var line := PackedVector2Array()
						for i in 9:
							var q := p1.lerp(p2, i / 8.0)
							line.append(q + nrm * (o * 4 + sin(i * 1.3 + gt * 40) * 2))
						ci.draw_polyline(line, col, w * (1.0 if o == 0 else .5), true)
				else:
					var c1 := col
					c1.a *= .35
					ci.draw_line(p1, p2, c1, w + 4, true)
					ci.draw_line(p1, p2, col, w, true)
					ci.draw_line(p1, p2, Color(1, 1, 1, col.a), maxf(1, w * .35), true)
				if f.kind == "dragon":
					glow(ci, p2, 12 * (1 - k) + 4, Color(.66, .54, 1, .6 * (1 - k)))
			"punch":
				var col := Color(1, .6, .3, 1 - k)
				ci.draw_arc(Vector2(f.x, f.y), 6 + k * 12, 0, TAU, 20, col, 3, true)
				for i in 6:
					var a := i * TAU / 6
					ci.draw_line(Vector2(f.x, f.y) + Vector2.from_angle(a) * (8 + k * 8), Vector2(f.x, f.y) + Vector2.from_angle(a) * (12 + k * 12), col, 2, true)
			"beam":
				var a := 1 - k
				var p1 := Vector2(f.x1, f.y1)
				var p2 := Vector2(f.x2, f.y2)
				var tint: Color = f.get("tint", Color(1, 236 / 255.0, 120 / 255.0))
				for layer in [[40.0, Color(tint, .55)], [14.0, tint.lightened(.7)], [5.0, Color.WHITE]]:
					var w: float = layer[0] * (1 - k * .5)
					var col: Color = layer[1]
					col.a *= a
					var pts := PackedVector2Array()
					var idx := PackedInt32Array()
					Pen._capsule(p1, p2, w / 2, pts, idx)
					ci.draw_colored_polygon(pts, col)
			"swift":
				var col: Color = f.col
				col.a = 1 - k
				var p1 := Vector2(f.x1, f.y1)
				var p2 := Vector2(f.x2, f.y2)
				var head := p1.lerp(p2, minf(1, k * 2.5))
				var c1 := col
				c1.a *= .35
				ci.draw_line(p1.lerp(head, .4), head, c1, 3, true)
				_draw_star(ci, head, 4.5, col, gt * 12)
			"slash":
				var col := Color(1, 1, 1, 1 - k)
				for i in [-1, 0, 1]:
					ci.draw_line(Vector2(f.x - 8 + i * 5, f.y - 9), Vector2(f.x + 6 + i * 5, f.y + 9), col, 2, true)
			"psy":
				var col := Color(1, 122 / 255.0, 217 / 255.0, 1 - k)
				var line := PackedVector2Array()
				for i in 11:
					var x: float = f.x1 + (f.x2 - f.x1) * i / 10.0
					var y: float = f.y1 + (f.y2 - f.y1) * i / 10.0
					var o := sin(i * 1.6 + gt * 30) * 4
					line.append(Vector2(x, y) if i == 0 else Vector2(x + o, y - o))
				ci.draw_polyline(line, col, 3, true)
				ci.draw_arc(Vector2(f.x2, f.y2), 6 + k * 12, 0, TAU, 24, col, 3, true)
			"text":
				var col: Color = f.col
				col.a = minf(1, f.life / f.max * 2)
				var y: float = f.y - k * 22
				var x: float = clampf(f.x, 110, W - 110)
				text(ci, f.text, x, y - 4, 15 if f.get("big", false) else 12, col, false, 4, Color(16 / 255.0, 18 / 255.0, 40 / 255.0, .85 * col.a))
	for p in g.parts:
		var a: float = p.life / p.max
		var col: Color = p.col
		col.a = a
		var s: float = p.size * (1.6 - a) if p.get("grow", false) else p.size
		if p.get("shard", false):
			# a curved piece of a popped Pokéball's shell, tumbling as it flies
			var rot: float = (p.x + p.y) * .08 + a * 6
			ci.draw_arc(Vector2(p.x, p.y), s * 1.4, rot, rot + 2.2, 6, col, s * .9, true)
		else:
			ci.draw_rect(Rect2(p.x - s / 2, p.y - s / 2, s, s), col)
	for c in g.coins:
		Art.coin(ci, c.x, c.y, 5.5, c.ph, minf(1, c.life * 2))
	for m in g.marks:
		var mb = m.b
		if mb.dead:
			continue
		var k: float = 1 - m.life / m.max
		dashed_circle(ci, Vector2(mb.x, mb.y), mb.def.r + 12 - k * 6, Color("#ff7ad9"), 2.5, 4, 4, -gt * 30)
	# placement preview
	if placing != "" and ghost != null:
		var valid = g.can_place(placing, ghost.x, ghost.y) and g.money >= Data.TOWERS[placing].cost
		var gp: Vector2 = ghost
		if Data.TOWERS[placing].get("onPath", false) and valid:
			gp = MapArt.pos_at(g.path, g.path_d(ghost.x, ghost.y))
		_show_range(ci, gp.x, gp.y, Data.TOWERS[placing].base.range, valid)
		Art.put_mon(ci, Data.sprite_for(placing, 0), gp.x, gp.y, 1, false, gt, .7)
	_draw_ambience(ci, g.map.theme, gt)
	for f in g.fx:
		if f.kind == "leak":
			ci.draw_rect(Rect2(0, 0, W, H), Color(1, 40 / 255.0, 40 / 255.0, .25 * f.life / f.max))
	if g.paused:
		ci.draw_rect(Rect2(0, 0, W, H), Color(10 / 255.0, 12 / 255.0, 30 / 255.0, .5))


static func _draw_star(ci: CanvasItem, c: Vector2, r: float, col: Color, rot: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := rot - PI / 2 + i * PI / 5
		pts.append(c + Vector2.from_angle(a) * (r * .45 if i % 2 else r))
	ci.draw_colored_polygon(pts, col)
