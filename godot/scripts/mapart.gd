class_name MapArt
extends RefCounted
## Route geometry, obstacle layout and the painted background for each map.
## Layouts use the same seeded random numbers as the web version, so trees,
## graves and rocks land in the same places.

const W := Data.W
const H := Data.H

const THEME := {
	"route": {"ground": "#7cc45c", "s1": "#6db14f", "s2": "#8fd16c", "path": "#e6cd94", "edge": "#c4a46a"},
	"forest": {"ground": "#3f8443", "s1": "#356f39", "s2": "#4c9550", "path": "#bf9b62", "edge": "#8a6a3c"},
	"lavender": {"ground": "#80779a", "s1": "#71698a", "s2": "#8e86a8", "path": "#c4bbd6", "edge": "#8f86a8"},
	"cave": {"ground": "#6e5f51", "s1": "#625446", "s2": "#7c6c5d", "path": "#a8977f", "edge": "#55473b"},
	"coast": {"ground": "#7cc45c", "s1": "#6db14f", "s2": "#8fd16c", "path": "#c99a5e", "edge": "#7a5530", "water": "#3b8fd4", "shore": "#ead9a2"},
	"tunnel": {"ground": "#54493f", "s1": "#4a4037", "s2": "#5f5247", "path": "#8f806b", "edge": "#3a3029"},
	"ice": {"ground": "#cfe4ee", "s1": "#bdd7e4", "s2": "#e2f2f8", "path": "#9fc4d8", "edge": "#6f9ab3", "water": "#2f6fa8", "shore": "#f4fbff"},
	"victory": {"ground": "#8f6d52", "s1": "#815f46", "s2": "#9c7b5f", "path": "#c6aa86", "edge": "#5e4535"},
}

const GRASSY := ["route", "forest", "coast"]
const ROCKY := ["cave", "tunnel", "victory"]

const LABELS := {
	"route1": [["PALLET TOWN", 225, 578], ["VIRIDIAN CITY", 575, 22]],
	"forest": [["ROUTE 2", 60, 72], ["PEWTER CITY", 755, 22]],
	"lavender": [["ROUTE 8", 480, 25], ["TO ROUTE 12", 890, 314]],
	"mtmoon": [["MT. MOON 1F", 70, 262], ["ROUTE 4", 900, 514]],
	"route12": [["LAVENDER TOWN", 95, 556], ["ROUTE 13", 890, 124]],
	"rocktunnel": [["ROUTE 10", 70, 44], ["LAVENDER TOWN", 95, 576]],
	"seafoam": [["ROUTE 20", 75, 112], ["SEAFOAM B4F", 890, 94]],
	"victory": [["ROUTE 23", 80, 424], ["INDIGO PLATEAU", 880, 104]],
}


## True if the point is in one of the map's lakes or seas.
static func in_water(map: Dictionary, x: float, y: float) -> bool:
	for w in map.get("water", []):
		if w[0] == "rect":
			if x >= w[1] and x <= w[1] + w[3] and y >= w[2] and y <= w[2] + w[4]:
				return true
		elif pow((x - w[1]) / w[3], 2) + pow((y - w[2]) / w[4], 2) <= 1:
			return true
	return false


# ---------- path ----------
static func build_path(pts: Array) -> Dictionary:
	var segs: Array = []
	var total := 0.0
	for i in pts.size() - 1:
		var a := Vector2(pts[i][0], pts[i][1])
		var b := Vector2(pts[i + 1][0], pts[i + 1][1])
		var len := a.distance_to(b)
		segs.append({"a": a, "b": b, "len": len, "start": total})
		total += len
	return {"pts": pts, "segs": segs, "total": total}


static func pos_at(p: Dictionary, d: float) -> Vector2:
	var segs: Array = p.segs
	if d <= 0:
		return segs[0].a
	for s in segs:
		if d <= s.start + s.len:
			return s.a.lerp(s.b, (d - s.start) / s.len)
	return segs[segs.size() - 1].b


static func seg_dist(pt: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	var k := 0.0 if l2 == 0 else clampf((pt - a).dot(ab) / l2, 0, 1)
	return pt.distance_to(a + ab * k)


static func dist_to_path(p: Dictionary, x: float, y: float) -> float:
	var m := 1e9
	var pt := Vector2(x, y)
	for s in p.segs:
		m = minf(m, seg_dist(pt, s.a, s.b))
	return m


# ---------- obstacles ----------
static func gen_obstacles(map: Dictionary, path: Dictionary) -> Dictionary:
	var rng := Data.Rng.new(Data.hash_str(map.id + "obs"))
	var obs: Array = []
	var deco: Array = []
	var ok := func(x: float, y: float, r: float, gap: float) -> bool:
		if not (x > r - 6 and x < W - r + 6 and y > r - 6 and y < H - r + 6):
			return false
		if dist_to_path(path, x, y) <= r + gap:
			return false
		if in_water(map, x, y):
			return false
		for o in obs:
			if Vector2(o.x - x, o.y - y).length() <= o.r + r - 4:
				return false
		return true
	var add := func(x: float, y: float, r: float, kind: String, gap: float) -> void:
		if ok.call(x, y, r, gap):
			obs.append({"x": x, "y": y, "r": r, "kind": kind, "v": rng.next()})
	match map.theme:
		"route":
			var x := 18.0
			while x < W:
				add.call(x, 16, 17, "tree", 24); add.call(x + 8, 586, 17, "tree", 24)
				x += 34
			var y := 50.0
			while y < H - 30:
				add.call(16, y, 17, "tree", 24); add.call(944, y, 17, "tree", 24)
				y += 34
			for cc in [[470, 380], [740, 460], [880, 90]]:
				for i in 5:
					var ax: float = cc[0] + (rng.next() - .5) * 70
					var ay: float = cc[1] + (rng.next() - .5) * 50
					add.call(ax, ay, 17, "tree", 24)
			for i in 7:
				var gx := 60 + rng.next() * 840
				var gy := 40 + rng.next() * 520
				if dist_to_path(path, gx, gy) > 60:
					var gw := 70 + rng.next() * 50
					var gh := 40 + rng.next() * 26
					deco.append({"kind": "grass", "x": gx, "y": gy, "w": gw, "h": gh})
			for i in 14:
				var fx := rng.next() * W
				var fy := rng.next() * H
				deco.append({"kind": "flower", "x": fx, "y": fy, "c": "#ff6f7d" if rng.next() < .5 else "#fff4c8"})
			deco.append({"kind": "ledge", "x": 400, "y": 375, "w": 180})
			deco.append({"kind": "ledge", "x": 690, "y": 250, "w": 100})
			deco.append({"kind": "ledge", "x": 120, "y": 220, "w": 140})
		"forest":
			var gx := 20.0
			while gx < W:
				var gy := 20.0
				while gy < H:
					if rng.next() < .52:
						var px := gx + (rng.next() - .5) * 36
						var py := gy + (rng.next() - .5) * 36
						add.call(px, py, 20 + rng.next() * 7, "pine", 22)
					gy += 64
				gx += 64
			for i in 22:
				var kind := "shroom" if rng.next() < .5 else "flower"
				var fx := rng.next() * W
				var fy := rng.next() * H
				deco.append({"kind": kind, "x": fx, "y": fy, "c": "#ffe28a"})
		"lavender":
			add.call(870, 70, 64, "ptower", 10)
			add.call(880, 170, 40, "ptower", 10)
			var gx := 40.0
			while gx < W:
				var gy := 40.0
				while gy < H:
					if rng.next() < .34:
						var px := gx + (rng.next() - .5) * 20
						var py := gy + (rng.next() - .5) * 20
						add.call(px, py, 13, "grave", 20)
					gy += 58
				gx += 58
			for i in 5:
				var px := rng.next() * W
				var py := rng.next() * H
				add.call(px, py, 18, "deadtree", 24)
		"coast":
			add.call(330, 168, 34, "sleeper", 8)
			var x := 18.0
			while x < 760:
				add.call(x, 16, 17, "tree", 24)
				x += 34
			var y := 50.0
			while y < H - 70:
				add.call(16, y, 17, "tree", 24)
				y += 34
			for cc in [[640, 290], [390, 300], [170, 420], [620, 540], [700, 60]]:
				for i in 4:
					var ax: float = cc[0] + (rng.next() - .5) * 80
					var ay: float = cc[1] + (rng.next() - .5) * 60
					add.call(ax, ay, 17, "tree", 24)
			for i in 8:
				var rx := 60 + rng.next() * 700
				var ry := 40 + rng.next() * 520
				add.call(rx, ry, 12 + rng.next() * 6, "rock", 22)
			for i in 12:
				var fx := rng.next() * 760
				var fy := rng.next() * H
				if not in_water(map, fx, fy):
					deco.append({"kind": "flower", "x": fx, "y": fy, "c": "#ff6f7d" if rng.next() < .5 else "#fff4c8"})
		"tunnel":
			for ly in [160, 320, 470]:
				var bx := 190.0
				while bx < 820:
					if rng.next() < .8:
						add.call(bx + (rng.next() - .5) * 30, ly + (rng.next() - .5) * 16, 24 + rng.next() * 5, "boulder", 12)
					bx += 100
			_scatter(rng, add, 44, .8, 11, 6, "rock", 14)
			for i in 8:
				var px := rng.next() * W
				var py := rng.next() * H
				if dist_to_path(path, px, py) > 40:
					deco.append({"kind": "crystal", "x": px, "y": py})
		"ice":
			for bp in [[405, 400], [565, 205], [235, 260], [730, 250], [880, 230]]:
				add.call(bp[0], bp[1], 26, "boulder", 12)
			_scatter(rng, add, 60, .5, 15, 5, "ice", 16)
			for i in 10:
				var px := rng.next() * W
				var py := rng.next() * H
				if dist_to_path(path, px, py) > 40 and not in_water(map, px, py):
					deco.append({"kind": "crystal", "x": px, "y": py, "c": "#e6fbff", "g": "#ffffff"})
		"victory":
			_scatter(rng, add, 78, .6, 22, 6, "boulder", 12)
			_scatter(rng, add, 48, .5, 11, 5, "rock", 16)
			for i in 10:
				var px := rng.next() * W
				var py := rng.next() * H
				deco.append({"kind": "crater", "x": px, "y": py, "r": 10 + rng.next() * 16})
		_:
			var gx := 30.0
			while gx < W:
				var gy := 30.0
				while gy < H:
					if rng.next() < .42:
						var px := gx + (rng.next() - .5) * 30
						var py := gy + (rng.next() - .5) * 30
						add.call(px, py, 14 + rng.next() * 12, "rock", 22)
					gy += 70
				gx += 70
			for i in 10:
				var px := rng.next() * W
				var py := rng.next() * H
				if dist_to_path(path, px, py) > 40:
					deco.append({"kind": "crystal", "x": px, "y": py})
			for i in 8:
				var px := rng.next() * W
				var py := rng.next() * H
				deco.append({"kind": "crater", "x": px, "y": py, "r": 10 + rng.next() * 16})
	for i in obs.size():
		obs[i].id = i
	return {"obs": obs, "deco": deco}


## Sprinkles obstacles over a jittered grid.
static func _scatter(rng: Data.Rng, add: Callable, step: float, chance: float, r0: float, rr: float, kind: String, gap: float) -> void:
	var gx := step / 2
	while gx < W:
		var gy := step / 2
		while gy < H:
			if rng.next() < chance:
				var px := gx + (rng.next() - .5) * step * .45
				var py := gy + (rng.next() - .5) * step * .45
				add.call(px, py, r0 + rng.next() * rr, kind, gap)
			gy += step
		gx += step


# ---------- background ----------
static func stroke_path(c: Pen, pts: Array, w: float, col) -> void:
	c.begin()
	c.move_to(pts[0][0], pts[0][1])
	for i in range(1, pts.size()):
		c.line_to(pts[i][0], pts[i][1])
	c.stroke(col, w, true)


static func draw_tree(c: Pen, x: float, y: float, r: float, v: float, pine: bool) -> void:
	c.ell(x + 3, y + r * .55, r * .9, r * .35); c.fill(Color(0, 0, 0, .22))
	c.fill_rect(x - r * .16, y, r * .32, r * .6, Color("#6b4a2b"))
	var base := ("#1d5a2c" if v < .5 else "#236432") if pine else "#2f8a3c"
	var hi := "#2f7a3c" if pine else "#4fae52"
	if pine:
		for i in 3:
			var yy := y - r * .15 - i * r * .42
			var ww := r * (1 - i * .24)
			c.poly([[x - ww, yy + r * .3], [x + ww, yy + r * .3], [x, yy - r * .6]])
			c.fill(hi if i == 2 else base); c.stroke("#123d1e", 1)
	else:
		c.ell(x, y - r * .3, r, r * .85); c.fill(base); c.stroke("#1b5a26", 1.4)
		c.ell(x - r * .3, y - r * .55, r * .45, r * .32); c.fill(hi)


## The whole picture in one mesh, for the map previews in the menu.
static func render_bg(map: Dictionary, path: Dictionary, obs: Array, deco: Array) -> Array:
	var c := Pen.new()
	_paint_base(c, map, path, obs, deco)
	paint_obstacles(c, obs, true)
	_paint_top(c, map)
	return Pen.bake(c.cmds)


## The picture split in three so clearable obstacles can be redrawn on their own:
## "base" (ground, path, fixed obstacles), "obs" (clearable ones) and "top" (signs, shading).
static func render_layers(map: Dictionary, path: Dictionary, obs: Array, deco: Array) -> Dictionary:
	var b := Pen.new()
	_paint_base(b, map, path, obs, deco)
	var t := Pen.new()
	_paint_top(t, map)
	return {"base": Pen.bake(b.cmds), "obs": render_obstacles(obs), "top": Pen.bake(t.cmds)}


static func render_obstacles(obs: Array) -> Array:
	var c := Pen.new()
	paint_obstacles(c, obs, true)
	return Pen.bake(c.cmds)


static func _water_shape(c: Pen, w: Array, grow: float) -> void:
	c.begin()
	if w[0] == "rect":
		c.rect(w[1] - grow, w[2] - grow, w[3] + grow * 2, w[4] + grow * 2)
	else:
		c.ellipse(w[1], w[2], w[3] + grow, w[4] + grow)


static func _paint_water(c: Pen, map: Dictionary, th: Dictionary, rng: Data.Rng) -> void:
	var water: Array = map.get("water", [])
	if water.is_empty():
		return
	for w in water:
		_water_shape(c, w, 7); c.fill(th.shore)
	for w in water:
		_water_shape(c, w, 0); c.fill(th.water)
		_water_shape(c, w, -10); c.fill(Color(th.water).lightened(.12))
	# little wave marks
	for i in 220:
		var x := rng.next() * W
		var y := rng.next() * H
		if in_water(map, x, y) and in_water(map, x - 8, y) and in_water(map, x + 8, y):
			c.begin(); c.move_to(x - 6, y); c.quad_to(x - 3, y - 3, x, y); c.quad_to(x + 3, y - 3, x + 6, y)
			c.stroke(Color(1, 1, 1, .35), 1.2, true)


static func _paint_base(c: Pen, map: Dictionary, path: Dictionary, obs: Array, deco: Array) -> void:
	var th: Dictionary = THEME[map.theme]
	var rng := Data.Rng.new(Data.hash_str(map.id))
	var theme: String = map.theme
	c.fill_rect(0, 0, W, H, Color(th.ground))
	# ground specks, batched into two colours
	var batch := {th.s1: [PackedVector2Array(), PackedInt32Array()], th.s2: [PackedVector2Array(), PackedInt32Array()]}
	var grassy := GRASSY.has(theme)
	for i in 1600:
		var col: String = th.s1 if rng.next() < .5 else th.s2
		var x := rng.next() * W
		var y := rng.next() * H
		var w := 1.6 if grassy else 3.0
		var h := 4.0 if grassy else 3.0
		var b: Array = batch[col]
		var n: int = b[0].size()
		b[0].append_array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
		b[1].append_array([n, n + 1, n + 2, n, n + 2, n + 3])
	for col in batch:
		var cols := PackedColorArray()
		cols.resize(batch[col][0].size())
		cols.fill(Color(col))
		c.add_tris(batch[col][0], batch[col][1], cols)
	if ROCKY.has(theme):
		for i in 40:
			var x := rng.next() * W
			var y := rng.next() * H
			var rx := 30 + rng.next() * 60
			var ry := 20 + rng.next() * 40
			c.ell(x, y, rx, ry); c.fill(Color(40 / 255.0, 30 / 255.0, 22 / 255.0, .12))
	if theme == "lavender":
		for i in 30:
			var x := rng.next() * W
			var y := rng.next() * H
			var rx := 40 + rng.next() * 60
			var ry := 20 + rng.next() * 30
			c.ell(x, y, rx, ry); c.fill(Color(60 / 255.0, 40 / 255.0, 90 / 255.0, .12))
	if theme == "ice":
		for i in 26:
			var x := rng.next() * W
			var y := rng.next() * H
			c.begin(); c.move_to(x, y)
			for k in 3:
				x += (rng.next() - .5) * 40
				y += (rng.next() - .5) * 26
				c.line_to(x, y)
			c.stroke(Color(1, 1, 1, .5), 1.2, true)
	_paint_water(c, map, th, rng)
	for d in deco:
		match d.kind:
			"grass":
				c.save()
				c.begin(); c.rect(d.x - d.w / 2, d.y - d.h / 2, d.w, d.h); c.clip()
				var gx: float = d.x - d.w / 2
				while gx < d.x + d.w / 2:
					var gy: float = d.y - d.h / 2
					while gy < d.y + d.h / 2:
						if dist_to_path(path, gx, gy) >= 30:
							c.begin(); c.move_to(gx, gy + 6); c.line_to(gx + 2, gy); c.line_to(gx + 4.5, gy + 5); c.line_to(gx + 7, gy); c.line_to(gx + 9, gy + 6); c.close()
							c.fill("#3f9a3c" if fmod(gx + gy, 2.0) != 0.0 else "#358a34")
						gy += 8
					gx += 9
				c.restore()
			"flower":
				if dist_to_path(path, d.x, d.y) >= 28:
					for k in 4:
						c.ell(d.x + cos(k * 1.57) * 2.4, d.y + sin(k * 1.57) * 2.4, 1.8, 1.8); c.fill(d.c)
					c.ell(d.x, d.y, 1.2, 1.2); c.fill("#f6b51e")
			"shroom":
				if dist_to_path(path, d.x, d.y) >= 28:
					c.fill_rect(d.x - 1.2, d.y, 2.4, 4, Color("#efe6d2"))
					c.ell(d.x, d.y, 4, 2.6); c.fill("#d8433a")
			"ledge":
				c.fill_rect(d.x - d.w / 2, d.y, d.w, 8, Color("#8a6a3c"))
				c.fill_rect(d.x - d.w / 2, d.y, d.w, 3, Color("#b48c52"))
			"crater":
				if dist_to_path(path, d.x, d.y) >= d.r + 24:
					c.ell(d.x, d.y, d.r, d.r * .6); c.fill(Color(30 / 255.0, 22 / 255.0, 16 / 255.0, .3))
					c.ell(d.x, d.y - 1.5, d.r * .8, d.r * .42); c.fill(Color(30 / 255.0, 22 / 255.0, 16 / 255.0, .25))
	stroke_path(c, map.path, 48, th.edge)
	stroke_path(c, map.path, 40, th.path)
	if theme == "lavender":
		stroke_path(c, map.path, 40, Color(th.path).lerp(Color(120 / 255.0, 110 / 255.0, 150 / 255.0), .3))
	if theme == "coast":
		# boardwalk planks, with posts where it crosses the water
		var d := 0.0
		while d < path.total:
			var p := pos_at(path, d)
			var q := pos_at(path, d + 1)
			var dir := (q - p).normalized()
			var nrm := Vector2(-dir.y, dir.x)
			var a := p + nrm * 19
			var b := p - nrm * 19
			c.begin(); c.move_to(a.x, a.y); c.line_to(b.x, b.y); c.stroke(Color("#8a6236"), 1.4)
			if in_water(map, p.x, p.y) and fmod(d, 60.0) < 9:
				for e in [p + nrm * 23, p - nrm * 23]:
					c.ell(e.x, e.y + 3, 4, 4); c.fill("#5e3f22")
			d += 9
	elif grassy or ROCKY.has(theme):
		var n := 160 if ROCKY.has(theme) else 220
		var col := Color(60 / 255.0, 45 / 255.0, 30 / 255.0, .35) if ROCKY.has(theme) else Color(120 / 255.0, 90 / 255.0, 50 / 255.0, .35)
		var rx := 1.8 if ROCKY.has(theme) else 1.4
		var ry := 1.3 if ROCKY.has(theme) else 1.0
		for i in n:
			var pp := pos_at(path, rng.next() * path.total)
			var ox := (rng.next() - .5) * 30
			var oy := (rng.next() - .5) * 30
			c.ell(pp.x + ox, pp.y + oy, rx, ry); c.fill(col)
	for d in deco:
		if d.kind == "crystal":
			c.glow(d.x, d.y - 2, 14, Color(d.get("g", "#d6c8ff")))
			c.poly([[d.x, d.y - 9], [d.x + 4, d.y], [d.x, d.y + 4], [d.x - 4, d.y]]); c.fill(d.get("c", "#cfc2ff"))
			c.poly([[d.x, d.y - 9], [d.x + 4, d.y], [d.x, d.y + 4]]); c.fill(Color(1, 1, 1, .4))
	paint_obstacles(c, obs, false)


static func paint_obstacles(c: Pen, obs: Array, clearable: bool) -> void:
	var sorted := Data.stable_sort(obs, func(a, b): return a.y < b.y)
	for o in sorted:
		if Data.OBSTACLES.has(o.kind) == clearable:
			draw_obstacle(c, o)


static func draw_obstacle(c: Pen, o: Dictionary) -> void:
	match o.kind:
		"tree": draw_tree(c, o.x, o.y, o.r, o.v, false)
		"pine": draw_tree(c, o.x, o.y, o.r, o.v, true)
		"grave":
			c.ell(o.x + 2, o.y + 11, 11, 3.5); c.fill(Color(0, 0, 0, .25))
			c.begin(); c.round_rect(o.x - 8, o.y - 12, 16, 22, [8, 8, 2, 2]); c.fill("#cfc9dc"); c.stroke("#5d5574", 1.4)
			c.fill_rect(o.x - 4, o.y - 4, 8, 1.6, Color("#8f86a8")); c.fill_rect(o.x - 4, o.y, 8, 1.6, Color("#8f86a8"))
		"deadtree":
			c.begin(); c.move_to(o.x, o.y + 12); c.line_to(o.x, o.y - 10)
			c.move_to(o.x, o.y - 2); c.line_to(o.x - 10, o.y - 12)
			c.move_to(o.x, o.y - 6); c.line_to(o.x + 9, o.y - 16)
			c.stroke("#3b2f45", 4, true)
		"rock":
			var r: float = o.r
			c.ell(o.x + 3, o.y + r * .5, r, r * .4); c.fill(Color(0, 0, 0, .25))
			c.poly([[o.x - r, o.y + r * .3], [o.x - r * .7, o.y - r * .5], [o.x - r * .1, o.y - r * .8], [o.x + r * .7, o.y - r * .45], [o.x + r, o.y + r * .25], [o.x + r * .4, o.y + r * .6], [o.x - r * .5, o.y + r * .6]])
			c.fill("#8a7b6b" if o.v < .5 else "#93836f"); c.stroke("#3f342a", 1.4)
			c.poly([[o.x - r * .6, o.y - r * .4], [o.x - r * .1, o.y - r * .7], [o.x + r * .4, o.y - r * .4], [o.x - r * .1, o.y - r * .2]]); c.fill(Color(1, 1, 1, .14))
		"boulder":
			var r: float = o.r
			c.ell(o.x + 4, o.y + r * .62, r * 1.05, r * .38); c.fill(Color(0, 0, 0, .28))
			c.ell(o.x, o.y, r, r * .9); c.fill("#7d6f62" if o.v < .5 else "#857565"); c.stroke("#2f2720", 1.8)
			c.ell(o.x - r * .3, o.y - r * .35, r * .45, r * .3); c.fill(Color(1, 1, 1, .16))
			c.begin(); c.move_to(o.x + r * .1, o.y - r * .2); c.line_to(o.x + r * .35, o.y + r * .1); c.line_to(o.x + r * .2, o.y + r * .45)
			c.stroke("#3f342a", 1.6, true)
		"ice":
			var r: float = o.r
			c.ell(o.x + 3, o.y + r * .7, r, r * .3); c.fill(Color(20 / 255.0, 60 / 255.0, 90 / 255.0, .25))
			c.poly([[o.x - r, o.y - r * .2], [o.x - r * .4, o.y - r * .9], [o.x + r * .6, o.y - r * .8], [o.x + r, o.y - r * .1], [o.x + r * .7, o.y + r * .7], [o.x - r * .6, o.y + r * .7]])
			c.fill(Color(190 / 255.0, 235 / 255.0, 1, .92)); c.stroke("#5f9fc4", 1.4)
			c.poly([[o.x - r * .7, o.y - r * .25], [o.x - r * .3, o.y - r * .75], [o.x + r * .1, o.y - r * .7], [o.x - r * .35, o.y - r * .1]]); c.fill(Color(1, 1, 1, .6))


static func _paint_top(c: Pen, map: Dictionary) -> void:
	var theme: String = map.theme
	if theme == "lavender":
		var x := 820.0
		var y := 8.0
		c.fill_rect(x + 6, y + 196, 104, 10, Color(0, 0, 0, .25))
		for tier in [[0, 150, 110], [10, 110, 90], [20, 70, 70], [30, 30, 50]]:
			var yy: float = tier[1]
			var w: float = tier[2]
			c.fill_rect(x + (110 - w) / 2, y + yy, w, 46, Color("#5b3f7d"))
			c.fill_rect(x + (110 - w) / 2 - 5, y + yy, w + 10, 7, Color("#3f2a5a"))
			for k in int(floor(w / 22)):
				c.fill_rect(x + (110 - w) / 2 + 8 + k * 22, y + yy + 18, 8, 12, Color("#ffd77a"))
		c.poly([[x + 40, y + 30], [x + 70, y + 30], [x + 55, y + 4]]); c.fill("#3f2a5a")
		c.fill_rect(x + 45, y + 176, 20, 20, Color("#2a1c3c"))
	for lab in LABELS[map.id]:
		var txt: String = lab[0]
		var w := Pen.font_display.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14
		c.begin(); c.round_rect(lab[1] - w / 2, lab[2] - 11, w, 22, 6); c.fill(Color(18 / 255.0, 20 / 255.0, 44 / 255.0, .78))
		c.text(txt, lab[1], lab[2] + 1, 13, Color.WHITE, true, 1)
	match theme:
		"forest":
			c.radial(W / 2, H / 2, [[H * .3, Color(0, 30 / 255.0, 0, 0)], [H * .9, Color(0, 25 / 255.0, 5 / 255.0, .35)], [800.0, Color(0, 25 / 255.0, 5 / 255.0, .35)]], 48)
		"cave", "victory":
			c.radial(W / 2, H / 2, [[H * .25, Color(0, 0, 0, 0)], [H * .85, Color(10 / 255.0, 6 / 255.0, 2 / 255.0, .5)], [800.0, Color(10 / 255.0, 6 / 255.0, 2 / 255.0, .5)]], 48)
		"tunnel":
			c.radial(W / 2, H / 2, [[H * .15, Color(0, 0, 0, 0)], [H * .7, Color(6 / 255.0, 4 / 255.0, 2 / 255.0, .62)], [800.0, Color(6 / 255.0, 4 / 255.0, 2 / 255.0, .7)]], 48)
		"ice":
			c.radial(W / 2, H / 2, [[H * .3, Color(1, 1, 1, 0)], [H * .95, Color(200 / 255.0, 230 / 255.0, 1, .35)], [800.0, Color(200 / 255.0, 230 / 255.0, 1, .35)]], 48)
