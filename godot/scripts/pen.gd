class_name Pen
extends RefCounted
## A small HTML-canvas-style drawing helper. The web version of PokéPop draws
## every Pokémon, ball and map with canvas paths; this mirrors that API
## (save/restore, translate/rotate/scale, paths, fill, stroke) so the art could
## be ported line by line. Output is recorded as a list of commands that can be
## replayed onto any CanvasItem, which also lets sprites be cached.

const OUT := Color("#2a1d18")

enum { TRI, LINE, TEXT }

var xf := Transform2D.IDENTITY
var alpha := 1.0
var clip_poly := PackedVector2Array()
var dash := PackedFloat32Array()
var dash_offset := 0.0
var cmds: Array = []

var _stack: Array = []
var _subs: Array = []
var _closed: Array = []
var _cur := PackedVector2Array()
var _cur_closed := false

static var font_display: Font
static var font_body: Font


func clear() -> void:
	cmds = []
	xf = Transform2D.IDENTITY
	alpha = 1.0
	clip_poly = PackedVector2Array()
	dash = PackedFloat32Array()
	_stack.clear()
	begin()


# ---------- state ----------
func save() -> void:
	_stack.push_back([xf, alpha, clip_poly, dash, dash_offset])


func restore() -> void:
	if _stack.is_empty():
		return
	var s: Array = _stack.pop_back()
	xf = s[0]; alpha = s[1]; clip_poly = s[2]; dash = s[3]; dash_offset = s[4]


func translate(x: float, y: float) -> void:
	xf = xf * Transform2D(0.0, Vector2(x, y))


func rotate(a: float) -> void:
	xf = xf * Transform2D(a, Vector2.ZERO)


func scale(sx: float, sy: float) -> void:
	xf = xf * Transform2D(Vector2(sx, 0), Vector2(0, sy), Vector2.ZERO)


func _xs() -> float:
	return sqrt(absf(xf.determinant()))


# ---------- paths ----------
func begin() -> void:
	_subs = []
	_closed = []
	_cur = PackedVector2Array()
	_cur_closed = false


func _flush() -> void:
	if _cur.size() > 0:
		_subs.append(_cur)
		_closed.append(_cur_closed)
	_cur = PackedVector2Array()
	_cur_closed = false


func move_to(x: float, y: float) -> void:
	_flush()
	_cur.append(xf * Vector2(x, y))


func line_to(x: float, y: float) -> void:
	_cur.append(xf * Vector2(x, y))


func close() -> void:
	if _cur.size() > 0:
		_cur_closed = true
		var first := _cur[0]
		_flush()
		# a fresh subpath starts at the closed one's first point, like canvas
		_cur = PackedVector2Array([first])


func quad_to(cx: float, cy: float, x: float, y: float) -> void:
	if _cur.is_empty():
		_cur.append(xf * Vector2(cx, cy))
	var p0 := _cur[_cur.size() - 1]
	var p1 := xf * Vector2(cx, cy)
	var p2 := xf * Vector2(x, y)
	var n := clampi(int((p0.distance_to(p1) + p1.distance_to(p2)) / 3.0), 4, 24)
	for i in range(1, n + 1):
		var t := float(i) / n
		var u := 1.0 - t
		_cur.append(p0 * (u * u) + p1 * (2.0 * u * t) + p2 * (t * t))


func bez_to(c1x: float, c1y: float, c2x: float, c2y: float, x: float, y: float) -> void:
	if _cur.is_empty():
		_cur.append(xf * Vector2(c1x, c1y))
	var p0 := _cur[_cur.size() - 1]
	var p1 := xf * Vector2(c1x, c1y)
	var p2 := xf * Vector2(c2x, c2y)
	var p3 := xf * Vector2(x, y)
	var n := clampi(int((p0.distance_to(p1) + p1.distance_to(p2) + p2.distance_to(p3)) / 3.0), 5, 28)
	for i in range(1, n + 1):
		var t := float(i) / n
		var u := 1.0 - t
		_cur.append(p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t))


func ellipse(x: float, y: float, rx: float, ry: float, rot := 0.0, a0 := 0.0, a1 := TAU, ccw := false) -> void:
	var sweep: float
	if not ccw:
		sweep = a1 - a0
		sweep = TAU if sweep >= TAU else fposmod(sweep, TAU)
	else:
		sweep = a0 - a1
		sweep = -(TAU if sweep >= TAU else fposmod(sweep, TAU))
	var rs := maxf(rx, ry) * _xs()
	var n := clampi(int(absf(sweep) / TAU * (10.0 + rs * 1.1)), 3, 72)
	var cr := cos(rot)
	var sr := sin(rot)
	for i in range(n + 1):
		var a := a0 + sweep * i / n
		var ex := cos(a) * rx
		var ey := sin(a) * ry
		_cur.append(xf * Vector2(x + ex * cr - ey * sr, y + ex * sr + ey * cr))


func arc(x: float, y: float, r: float, a0 := 0.0, a1 := TAU, ccw := false) -> void:
	ellipse(x, y, r, r, 0.0, a0, a1, ccw)


func rect(x: float, y: float, w: float, h: float) -> void:
	move_to(x, y)
	line_to(x + w, y)
	line_to(x + w, y + h)
	line_to(x, y + h)
	close()


func round_rect(x: float, y: float, w: float, h: float, r) -> void:
	var rr: Array = r if r is Array else [r, r, r, r]
	move_to(x + rr[0], y)
	line_to(x + w - rr[1], y)
	if rr[1] > 0: arc(x + w - rr[1], y + rr[1], rr[1], -PI / 2, 0)
	line_to(x + w, y + h - rr[2])
	if rr[2] > 0: arc(x + w - rr[2], y + h - rr[2], rr[2], 0, PI / 2)
	line_to(x + rr[3], y + h)
	if rr[3] > 0: arc(x + rr[3], y + h - rr[3], rr[3], PI / 2, PI)
	line_to(x, y + rr[0])
	if rr[0] > 0: arc(x + rr[0], y + rr[0], rr[0], PI, PI * 1.5)
	close()


func clip() -> void:
	_flush()
	for s in _subs:
		if s.size() >= 3:
			clip_poly = _clean(s)
			break


# ---------- output ----------
static func _clean(p: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in p:
		if out.is_empty() or out[out.size() - 1].distance_squared_to(v) > 0.0004:
			out.append(v)
	while out.size() > 2 and out[0].distance_squared_to(out[out.size() - 1]) < 0.0004:
		out.remove_at(out.size() - 1)
	return out


func _tri(p: PackedVector2Array, col: Color) -> void:
	var idx := Geometry2D.triangulate_polygon(p)
	if idx.is_empty():
		var hull := Geometry2D.convex_hull(p)
		if hull.size() < 4:
			return
		hull.remove_at(hull.size() - 1)
		p = hull
		idx = Geometry2D.triangulate_polygon(p)
		if idx.is_empty():
			return
	var cols := PackedColorArray()
	cols.resize(p.size())
	cols.fill(col)
	cmds.append([TRI, p, idx, cols])


func fill(colv) -> void:
	_flush()
	var col: Color = colv if colv is Color else Color(colv)
	col.a *= alpha
	if col.a <= 0.0:
		return
	for s in _subs:
		if s.size() < 3:
			continue
		var p := _clean(s)
		if p.size() < 3:
			continue
		if clip_poly.size() >= 3:
			for q in Geometry2D.intersect_polygons(p, clip_poly):
				_tri(q, col)
		else:
			_tri(p, col)


func stroke(colv, width := 1.4, round_caps := false) -> void:
	_flush()
	var col: Color = colv if colv is Color else Color(colv)
	col.a *= alpha
	if col.a <= 0.0:
		return
	var w := width * _xs()
	for i in _subs.size():
		var s: PackedVector2Array = _subs[i]
		if s.size() < 2:
			continue
		var p := s.duplicate()
		if _closed[i] and p[0].distance_squared_to(p[p.size() - 1]) > 0.0004:
			p.append(p[0])
		if dash.size() >= 2:
			for seg in _dashed(p, dash, dash_offset * _xs()):
				_line(seg, col, w, false)
		else:
			_line(p, col, w, round_caps and not _closed[i])


func _line(p: PackedVector2Array, col: Color, w: float, round_caps: bool) -> void:
	if round_caps and w >= 2.5:
		if col.a < 0.99:
			# translucent: one merged outline so overlaps don't darken
			for poly in Geometry2D.offset_polyline(p, w * 0.5, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
				_tri(poly, col)
			return
		# opaque: a capsule per segment is much cheaper and looks the same
		var pts := PackedVector2Array()
		var idx := PackedInt32Array()
		for i in range(1, p.size()):
			_capsule(p[i - 1], p[i], w * 0.5, pts, idx)
		if pts.size():
			var cols := PackedColorArray()
			cols.resize(pts.size())
			cols.fill(col)
			cmds.append([TRI, pts, idx, cols])
		return
	cmds.append([LINE, p, col, w])


## Appends a convex capsule (segment with round ends) as a triangle fan.
static func _capsule(a: Vector2, b: Vector2, r: float, pts: PackedVector2Array, idx: PackedInt32Array) -> void:
	var d := b - a
	var ang := d.angle() if d.length_squared() > 0.000001 else 0.0
	var n := clampi(int(r * 1.5) + 4, 4, 14)
	var base := pts.size()
	for i in n + 1:
		var t := ang + PI / 2 + PI * i / n
		pts.append(a + Vector2(cos(t), sin(t)) * r)
	for i in n + 1:
		var t := ang - PI / 2 + PI * i / n
		pts.append(b + Vector2(cos(t), sin(t)) * r)
	var cnt := (n + 1) * 2
	for i in range(1, cnt - 1):
		idx.append_array([base, base + i, base + i + 1])


static func _dashed(p: PackedVector2Array, pattern: PackedFloat32Array, offset: float) -> Array:
	var out: Array = []
	var total := 0.0
	for v in pattern:
		total += v
	var pos := fposmod(offset, total)
	var idx := 0
	var left := pattern[0]
	while pos > 0.0:
		if pos >= left:
			pos -= left
			idx = (idx + 1) % pattern.size()
			left = pattern[idx]
		else:
			left -= pos
			pos = 0.0
	var on := idx % 2 == 0
	var cur := PackedVector2Array()
	if on:
		cur.append(p[0])
	for i in range(1, p.size()):
		var a := p[i - 1]
		var b := p[i]
		var seg := a.distance_to(b)
		var done := 0.0
		while seg - done > left:
			done += left
			var q := a.lerp(b, done / seg)
			if on:
				cur.append(q)
				out.append(cur)
				cur = PackedVector2Array()
			else:
				cur = PackedVector2Array([q])
			on = not on
			idx = (idx + 1) % pattern.size()
			left = pattern[idx]
		left -= seg - done
		if on:
			cur.append(b)
	if on and cur.size() >= 2:
		out.append(cur)
	return out


# ---------- gradients ----------
## Radial gradient disc: stops are [radius, Color] pairs, smallest first.
func radial(cx: float, cy: float, stops: Array, segs := 40) -> void:
	var c := xf * Vector2(cx, cy)
	var xs := _xs()
	var ring := func(r: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in segs:
			var a := TAU * i / segs
			out.append(c + Vector2(cos(a), sin(a)) * r * xs)
		return out
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	pts.append(c)
	var c0: Color = stops[0][1]
	c0.a *= alpha
	cols.append(c0)
	var prev_base := -1
	for si in stops.size():
		var r: float = stops[si][0]
		var col: Color = stops[si][1]
		col.a *= alpha
		var base := pts.size()
		pts.append_array(ring.call(maxf(r, 0.01)))
		for i in segs:
			cols.append(col)
		for i in segs:
			var j := (i + 1) % segs
			if prev_base < 0:
				idx.append_array([0, base + i, base + j])
			else:
				idx.append_array([prev_base + i, base + i, base + j, prev_base + i, base + j, prev_base + j])
		prev_base = base
	cmds.append([TRI, pts, idx, cols])


func glow(x: float, y: float, r: float, col: Color) -> void:
	var c2 := col
	c2.a = 0.0
	var c1 := col
	c1.a *= 0.55
	radial(x, y, [[0.0, c1], [r * 0.35, c1 * Color(1, 1, 1, 0.9)], [r, c2]], 24)


## Appends raw triangles (no clipping); used for big batches like grass specks.
func add_tris(pts: PackedVector2Array, idx: PackedInt32Array, cols: PackedColorArray) -> void:
	cmds.append([TRI, pts, idx, cols])


# ---------- text ----------
func text(s: String, x: float, y: float, size: float, col: Color, display := true, align := 0, outline := 0.0, outline_col := Color.BLACK) -> void:
	col.a *= alpha
	outline_col.a *= alpha
	var pos := xf * Vector2(x, y)
	cmds.append([TEXT, pos, s, int(round(size * _xs())), col, display, align, int(round(outline * _xs())), outline_col])


# ---------- shortcuts used by the art ----------
func ell(x: float, y: float, rx: float, ry: float, rot := 0.0) -> void:
	begin()
	ellipse(x, y, rx, ry, rot)


func fs(f, s = OUT, w := 1.4) -> void:
	fill(f)
	if s != null:
		stroke(s, w)


## Fills the strip of the current path that would be uncovered if the path
## moved by (dx, dy) on screen: a crescent along the opposite edge.
func rim(colv, dx: float, dy: float) -> void:
	_flush()
	var col: Color = colv if colv is Color else Color(colv)
	col.a *= alpha
	if col.a <= 0.0:
		return
	var off := Vector2(dx, dy) * _xs()
	for s in _subs:
		if s.size() < 3:
			continue
		var p := _clean(s)
		if p.size() < 3:
			continue
		var moved := Transform2D(0.0, off) * p
		for q in Geometry2D.clip_polygons(p, moved):
			if clip_poly.size() >= 3:
				for r in Geometry2D.intersect_polygons(q, clip_poly):
					_tri(r, col)
			else:
				_tri(q, col)


## Shaded fill: base colour, a shadow along the lower right, a soft light along
## the upper left, then the outline.
func sh(f, s = OUT, w := 1.4, depth := 1.0) -> void:
	var col: Color = f if f is Color else Color(f)
	fill(col)
	rim(col.darkened(.2), -1.6 * depth, -2.0 * depth)
	var hl := col.lightened(.32)
	hl.a = .8
	rim(hl, 1.0 * depth, 1.2 * depth)
	if s != null:
		stroke(s, w)


## Fills the current (convex) path with a two-colour radial gradient centred at (cx, cy).
func fill_fan(cx: float, cy: float, r: float, c0: Color, c1: Color) -> void:
	_flush()
	if _subs.is_empty():
		return
	var ring := _clean(_subs[0])
	if ring.size() < 3:
		return
	var c := xf * Vector2(cx, cy)
	var rs := r * _xs()
	var pts := PackedVector2Array([c])
	var cols := PackedColorArray()
	var a0 := c0
	a0.a *= alpha
	cols.append(a0)
	var idx := PackedInt32Array()
	for i in ring.size():
		pts.append(ring[i])
		var k := clampf(ring[i].distance_to(c) / rs, 0.0, 1.0)
		var col := c0.lerp(c1, k)
		col.a *= alpha
		cols.append(col)
		idx.append_array([0, 1 + i, 1 + (i + 1) % ring.size()])
	cmds.append([TRI, pts, idx, cols])


func poly(pts: Array) -> void:
	begin()
	move_to(pts[0][0], pts[0][1])
	for i in range(1, pts.size()):
		line_to(pts[i][0], pts[i][1])
	close()


func fill_rect(x: float, y: float, w: float, h: float, col: Color) -> void:
	begin()
	rect(x, y, w, h)
	fill(col)


# ---------- replay ----------
static func replay(ci: CanvasItem, list: Array, mod_alpha := 1.0) -> void:
	var rid := ci.get_canvas_item()
	for c in list:
		match c[0]:
			TRI:
				var cols: PackedColorArray = c[3]
				if mod_alpha < 0.999:
					cols = cols.duplicate()
					for i in cols.size():
						cols[i].a *= mod_alpha
				RenderingServer.canvas_item_add_triangle_array(rid, c[2], c[1], cols)
			LINE:
				var col: Color = c[2]
				if mod_alpha < 0.999:
					col.a *= mod_alpha
				ci.draw_polyline(c[1], col, c[3], true)
			TEXT:
				var f: Font = font_display if c[5] else font_body
				var col: Color = c[4]
				var oc: Color = c[8]
				if mod_alpha < 0.999:
					col.a *= mod_alpha
					oc.a *= mod_alpha
				var size: int = maxi(1, c[3])
				var pos: Vector2 = c[1]
				var w := f.get_string_size(c[2], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				var asc := f.get_ascent(size)
				var desc := f.get_descent(size)
				# canvas text: x by align (0 left, 1 center, 2 right), y is the middle line
				var ox := 0.0 if c[6] == 0 else (-w * 0.5 if c[6] == 1 else -w)
				var p2 := Vector2(pos.x + ox, pos.y + (asc - desc) * 0.5)
				if c[7] > 0:
					ci.draw_string_outline(f, p2, c[2], HORIZONTAL_ALIGNMENT_LEFT, -1, size, c[7], oc)
				ci.draw_string(f, p2, c[2], HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

# ---------- baking ----------
## Merges a command list into one triangle mesh (lines become feathered quads),
## so a whole sprite draws with a single call.
static func bake(list: Array, mod_alpha := 1.0) -> Array:
	var pts := PackedVector2Array()
	var idx := PackedInt32Array()
	var cols := PackedColorArray()
	var texts: Array = []
	for c in list:
		match c[0]:
			TRI:
				var base := pts.size()
				pts.append_array(c[1])
				var cc: PackedColorArray = c[3]
				if mod_alpha < 0.999:
					cc = cc.duplicate()
					for i in cc.size():
						cc[i].a *= mod_alpha
				cols.append_array(cc)
				var ii: PackedInt32Array = c[2]
				for i in ii:
					idx.append(i + base)
			LINE:
				var col: Color = c[2]
				col.a *= mod_alpha
				_line_tris(c[1], col, c[3], pts, idx, cols)
			TEXT:
				var tc: Array = c.duplicate()
				tc[4] = Color(tc[4], tc[4].a * mod_alpha)
				tc[8] = Color(tc[8], tc[8].a * mod_alpha)
				texts.append(tc)
	return [pts, idx, cols, texts]


static func _line_tris(p: PackedVector2Array, col: Color, w: float, pts: PackedVector2Array, idx: PackedInt32Array, cols: PackedColorArray) -> void:
	if w < 1.0:
		col.a *= w
		w = 1.0
	var half := w * 0.5
	var aa := 0.75
	var clear := Color(col, 0.0)
	for i in range(1, p.size()):
		var a := p[i - 1]
		var b := p[i]
		var d := b - a
		var len := d.length()
		if len < 0.0001:
			continue
		var dir := d / len
		var ext := minf(half, 0.5)
		a -= dir * ext
		b += dir * ext
		var n := Vector2(-dir.y, dir.x)
		var base := pts.size()
		pts.append_array([a + n * (half + aa), a + n * half, a - n * half, a - n * (half + aa),
			b + n * (half + aa), b + n * half, b - n * half, b - n * (half + aa)])
		cols.append_array([clear, col, col, clear, clear, col, col, clear])
		for q in 3:
			var i0 := base + q
			var i1 := base + q + 1
			var j0 := base + 4 + q
			var j1 := base + 4 + q + 1
			idx.append_array([i0, i1, j1, i0, j1, j0])


static func draw_baked(ci: CanvasItem, baked: Array) -> void:
	var idx: PackedInt32Array = baked[1]
	if idx.size():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, baked[0], baked[2])
	for c in baked[3]:
		_text_cmd(ci, c)


static func _text_cmd(ci: CanvasItem, c: Array) -> void:
	var f: Font = font_display if c[5] else font_body
	var size: int = maxi(1, c[3])
	var pos: Vector2 = c[1]
	var w := f.get_string_size(c[2], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var asc := f.get_ascent(size)
	var desc := f.get_descent(size)
	var ox := 0.0 if c[6] == 0 else (-w * 0.5 if c[6] == 1 else -w)
	var p2 := Vector2(pos.x + ox, pos.y + (asc - desc) * 0.5)
	if c[7] > 0:
		ci.draw_string_outline(f, p2, c[2], HORIZONTAL_ALIGNMENT_LEFT, -1, size, c[7], c[8])
	ci.draw_string(f, p2, c[2], HORIZONTAL_ALIGNMENT_LEFT, -1, size, c[4])
