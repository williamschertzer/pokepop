extends SceneTree
## Headless checks run by CI: godot --headless -s tests/check_upgrades.gd
## - no upgrade ever lowers a stat, whichever path it's on or what's around it
## - unlock goals count Normal/Hard wins per map, never Easy
## - maps open in order; obstacles need a Pokémon in range that knows the move
## - dark caves shrink range unless lit; Chansey powers up Pikachu

var fails := 0


func _init() -> void:
	# map setup paints labels, which needs the fonts the game normally loads
	Pen.font_display = load("res://fonts/PixelifySans.ttf")
	Pen.font_body = load("res://fonts/Nunito.ttf")
	_check_stats_never_drop()
	_check_preview_with_buffs()
	_check_unlocks()
	_check_maps()
	_check_field_moves()
	_check_dark_and_help()
	print("check_upgrades: %s" % ("OK" if fails == 0 else "%d failures" % fails))
	quit(1 if fails else 0)


func _fail(msg: String) -> void:
	fails += 1
	printerr(msg)


static func _reachable(a: int, b: int) -> bool:
	return a <= 3 and b <= 3 and not (a > 2 and b > 2)


func _worse(st: String, before, after) -> bool:
	if before is bool or before == after:
		return false
	if st in Data.LOWER_BETTER:
		return after == 0 or (before != 0 and after > before)
	return after < before


func _compare(label: String, s0: Dictionary, s1: Dictionary) -> void:
	for st in s0:
		if st.begins_with("_"):
			continue
		if _worse(st, s0[st], s1[st]):
			_fail("%s: %s went from %s to %s" % [label, st, s0[st], s1[st]])


func _check_stats_never_drop() -> void:
	for k in Data.TOWERS:
		for a in 4:
			for b in 4:
				if not _reachable(a, b):
					continue
				var s0 := Data.compute_stats(k, a, b)
				for nx in [Vector2i(a + 1, b), Vector2i(a, b + 1)]:
					if _reachable(nx.x, nx.y):
						_compare("%s %d/%d -> %d/%d" % [k, a, b, nx.x, nx.y], s0, Data.compute_stats(k, nx.x, nx.y))


## The upgrade preview must include Abra auras and Dragon Dance, or hovering an
## evolution looks like it slows the Pokémon down.
func _check_preview_with_buffs() -> void:
	var g := Game.new()
	var abra := Game.Tower.new()
	abra.kind = "abra"; abra.a = 3; abra.x = 300; abra.y = 300
	var dra := Game.Tower.new()
	dra.kind = "dratini"; dra.b = 2; dra.x = 320; dra.y = 300; dra.danced = 6
	g.towers = [abra, dra]
	g.refresh_buffs()
	for a in 3:
		dra.a = a
		g.refresh_buffs()
		_compare("buffed dratini %d/2 -> %d/2" % [a, a + 1], dra.s, g.stats_with_buffs(dra, a + 1, 2))


func _check_unlocks() -> void:
	if Data.is_unlocked("magikarp", {}):
		_fail("magikarp unlocked with no progress")
	if Data.is_unlocked("magikarp", {"route1:easy": 40}):
		_fail("easy runs should not unlock anything")
	if not Data.is_unlocked("geodude", {"route1": 40}):
		_fail("beating a map on normal should unlock geodude")
	if Data.is_unlocked("machop", {"route1": 40, "route1:hard": 40}):
		_fail("machop needs two different maps")
	if not Data.is_unlocked("machop", {"route1": 40, "forest:hard": 40}):
		_fail("hard wins should count toward normal goals")
	if Data.is_unlocked("lapras", {"route1": 40}):
		_fail("lapras needs a hard win")
	if not Data.is_unlocked("mewtwo", {}):
		_fail("pokemon without an unlock goal should always be available")


func _check_maps() -> void:
	var ids := {}
	for m in Data.MAPS:
		ids[m.id] = true
	if ids.size() != Data.MAP_ORDER.size() or not Data.MAP_ORDER.all(func(i): return ids.has(i)):
		_fail("MAP_ORDER must list every map exactly once")
	if Data.map_needs("route1", {}) != "":
		_fail("the first map should always be open")
	if Data.map_needs("forest", {}) != "route1":
		_fail("forest should need route1 beaten")
	if Data.map_needs("forest", {"route1:easy": 40}) != "":
		_fail("beating a map on any difficulty opens the next")
	if Data.map_needs("forest", {"route1": 39}) == "":
		_fail("reaching wave 39 is not beating the map")
	if Data.map_needs("victory", {"victory:hard": 12}) != "":
		_fail("maps already played must stay open for old saves")


func _tower(g: Game, kind: String, x: float, y: float) -> Game.Tower:
	var tw := Game.Tower.new()
	tw.kind = kind; tw.x = x; tw.y = y
	g.towers.append(tw)
	g.refresh_buffs()
	return tw


func _check_field_moves() -> void:
	var g := Game.new()
	g.setup_map(Data.map_by_id("route1"))
	var tree = null
	for o in g.obs:
		if o.kind == "tree" and o.x > 100 and o.x < 860 and o.y > 100 and o.y < 500:
			tree = o
			break
	var near := _tower(g, "bulbasaur", tree.x + 40, tree.y)
	if not g.clearers(tree).is_empty():
		_fail("bulbasaur should need Cut before clearing a tree")
	near.hms.append("Cut")
	if not g.clearers(tree).has(near):
		_fail("bulbasaur with Cut next to a tree should be able to clear it")
	var far := _tower(g, "bulbasaur", tree.x + 400 if tree.x < 480 else tree.x - 400, tree.y)
	far.hms.append("Cut")
	if g.clearers(tree).has(far):
		_fail("a bulbasaur out of range must not clear the tree")
	var ch := _tower(g, "charmander", 0, 0)
	if not g.knows_move(ch, "Ember") or g.knows_move(ch, "Flamethrower"):
		_fail("charmander knows Ember, and Flamethrower only after buying it")
	ch.b = 1
	if not g.knows_move(ch, "Flamethrower"):
		_fail("the Flamethrower upgrade should count as knowing the move")


func _check_dark_and_help() -> void:
	var g := Game.new()
	g.setup_map(Data.map_by_id("diglett"))
	var bul := _tower(g, "bulbasaur", 300, 300)
	var base: float = Data.TOWERS.bulbasaur.base.range
	if not is_equal_approx(bul.s.range, base * Data.DARK_RANGE):
		_fail("unlit Pokémon in a dark cave should lose range (%s)" % bul.s.range)
	var pk := _tower(g, "pikachu", 360, 300)
	pk.hms.append("Flash")
	g.refresh_buffs()
	if not is_equal_approx(bul.s.range, base):
		_fail("Flash nearby should restore full range (%s)" % bul.s.range)
	var fire := _tower(g, "growlithe", 800, 500)
	if not fire.lit:
		_fail("fire Pokémon light themselves")
	var g2 := Game.new()
	g2.setup_map(Data.map_by_id("route1"))
	var pika := _tower(g2, "pikachu", 300, 300)
	var d0: float = pika.s.dmg
	_tower(g2, "chansey", 340, 300)
	if pika.s.dmg != d0 + 1 or not pika.buffed:
		_fail("chansey's Helping Hand should give pikachu +1 damage")
