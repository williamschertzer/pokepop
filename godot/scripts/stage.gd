class_name Stage
extends Control
## The game field. Draws the map, balls, Pokémon and effects, and turns clicks
## and taps into placing or selecting Pokémon.

signal tower_clicked(tw)  # Game.Tower or null
signal place_requested(x: float, y: float, keep: bool)
signal touch_preview(x: float, y: float)

const W := Data.W
const H := Data.H

var game: Game
var placing := ""
var ghost = null  # Vector2 or null
var ghost_touch := false
var selected = null  # Game.Tower or null

var _bg_layer: Control
var _fx_layer: Control
var _last_touch := -10000


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
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if over_tower else Control.CURSOR_CROSS
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == -1:
			touch = true
		if game.over:
			return
		var p: Vector2 = event.position
		if placing != "":
			if touch:
				if ghost != null and ghost_touch and ghost.distance_to(p) < 30:
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
			if Vector2(tw.x, tw.y).distance_to(p) < 22:
				hit = tw
				break
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
func _draw_bg() -> void:
	var ci := _bg_layer
	if game and game.map:
		Pen.draw_baked(ci, game.bg)
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
	# balls
	for b in g.balls:
		var def: Dictionary = b.def
		var r: float = def.r
		fill_ell(ci, b.x, b.y + r * .85, r * .8, r * .28, Color(0, 0, 0, .22))
		var rot: float = sin(b.wob) * (.05 if b.sleep > 0 else (.06 if b.type == "rocket" else .28))
		var al := 1.0
		if def.get("hidden", false):
			al = .55 + .15 * sin(gt * 4 + b.id)
		Art.put_ball(ci, b.type, b.x, b.y, rot, 1.0, al)
		if b.sleep > 0:
			text(ci, "z", b.x + r * .6, b.y - r - fmod(gt * 20, 8) - 4, 11, Color.WHITE, true)
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
	# Pokémon
	var ts: Array = g.towers.duplicate()
	ts.sort_custom(func(a, b): return a.y < b.y)
	for tw in ts:
		var spn := Data.sprite_for(tw.kind, tw.a)
		if tw == selected:
			stroke_ell(ci, tw.x, tw.y + 15, 18, 6, Color("#ffd23f"), 2)
		var pop := minf(1, (gt - tw.born) * 5)
		var opt := {"shades": tw.kind == "squirtle" and tw.b >= 2, "conf": tw.conf, "amulet": tw.kind == "meowth" and tw.a >= 2}
		Art.put_mon(ci, spn, tw.x, tw.y, .75 + .25 * pop, tw.face < 0, gt + tw.id, 1, opt)
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
			"beam":
				var a := 1 - k
				var p1 := Vector2(f.x1, f.y1)
				var p2 := Vector2(f.x2, f.y2)
				for layer in [[40.0, Color(1, 236 / 255.0, 120 / 255.0, .55)], [14.0, Color("#fffbe0")], [5.0, Color.WHITE]]:
					var w: float = layer[0] * (1 - k * .5)
					var col: Color = layer[1]
					col.a *= a
					var pts := PackedVector2Array()
					var idx := PackedInt32Array()
					Pen._capsule(p1, p2, w / 2, pts, idx)
					ci.draw_colored_polygon(pts, col)
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
		_show_range(ci, ghost.x, ghost.y, Data.TOWERS[placing].base.range, valid)
		Art.put_mon(ci, Data.sprite_for(placing, 0), ghost.x, ghost.y, 1, false, gt, .7)
	if g.map.theme == "lavender":
		for i in 6:
			var x := fmod(gt * 12 + i * 190, W + 300) - 150
			var y := 90 + i * 85 + sin(gt * .4 + i) * 20
			glow(ci, Vector2(x, y), 150, Color(230 / 255.0, 220 / 255.0, 1, .16))
	for f in g.fx:
		if f.kind == "leak":
			ci.draw_rect(Rect2(0, 0, W, H), Color(1, 40 / 255.0, 40 / 255.0, .25 * f.life / f.max))
	if g.paused:
		ci.draw_rect(Rect2(0, 0, W, H), Color(10 / 255.0, 12 / 255.0, 30 / 255.0, .5))
