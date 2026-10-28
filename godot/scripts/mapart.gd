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
}

const LABELS := {
	"route1": [["PALLET TOWN", 225, 578], ["VIRIDIAN CITY", 575, 22]],
	"forest": [["ROUTE 2", 60, 72], ["PEWTER CITY", 755, 22]],
	"lavender": [["ROUTE 8", 480, 25], ["TO ROUTE 12", 890, 314]],
	"mtmoon": [["MT. MOON 1F", 70, 262], ["ROUTE 4", 900, 514]],
}


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
	return {"obs": obs, "deco": deco}


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


static func render_bg(map: Dictionary, path: Dictionary, obs: Array, deco: Array) -> Array:
	var c := Pen.new()
	var th: Dictionary = THEME[map.theme]
	var rng := Data.Rng.new(Data.hash_str(map.id))
	var theme: String = map.theme
	c.fill_rect(0, 0, W, H, Color(th.ground))
	# ground specks, batched into two colours
	var batch := {th.s1: [PackedVector2Array(), PackedInt32Array()], th.s2: [PackedVector2Array(), PackedInt32Array()]}
	var grassy := theme == "route" or theme == "forest"
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
	if theme == "cave":
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
	if grassy or theme == "cave":
		var n := 160 if theme == "cave" else 220
		var col := Color(60 / 255.0, 45 / 255.0, 30 / 255.0, .35) if theme == "cave" else Color(120 / 255.0, 90 / 255.0, 50 / 255.0, .35)
		var rx := 1.8 if theme == "cave" else 1.4
		var ry := 1.3 if theme == "cave" else 1.0
		for i in n:
			var pp := pos_at(path, rng.next() * path.total)
			var ox := (rng.next() - .5) * 30
			var oy := (rng.next() - .5) * 30
			c.ell(pp.x + ox, pp.y + oy, rx, ry); c.fill(col)
	for d in deco:
		if d.kind == "crystal":
			c.glow(d.x, d.y - 2, 14, Color("#d6c8ff"))
			c.poly([[d.x, d.y - 9], [d.x + 4, d.y], [d.x, d.y + 4], [d.x - 4, d.y]]); c.fill("#cfc2ff")
			c.poly([[d.x, d.y - 9], [d.x + 4, d.y], [d.x, d.y + 4]]); c.fill(Color(1, 1, 1, .4))
	var sorted := Data.stable_sort(obs, func(a, b): return a.y < b.y)
	for o in sorted:
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
	if theme == "forest":
		c.radial(W / 2, H / 2, [[H * .3, Color(0, 30 / 255.0, 0, 0)], [H * .9, Color(0, 25 / 255.0, 5 / 255.0, .35)], [800.0, Color(0, 25 / 255.0, 5 / 255.0, .35)]], 48)
	if theme == "cave":
		c.radial(W / 2, H / 2, [[H * .25, Color(0, 0, 0, 0)], [H * .85, Color(10 / 255.0, 6 / 255.0, 2 / 255.0, .5)], [800.0, Color(10 / 255.0, 6 / 255.0, 2 / 255.0, .5)]], 48)
	return Pen.bake(c.cmds)
