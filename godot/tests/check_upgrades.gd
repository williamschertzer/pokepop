extends SceneTree
## Headless checks run by CI: godot --headless -s tests/check_upgrades.gd
## - no upgrade ever lowers a stat, whichever path it's on or what's around it
## - unlock goals count Normal/Hard wins per map, never Easy

var fails := 0


func _init() -> void:
	_check_stats_never_drop()
	_check_preview_with_buffs()
	_check_unlocks()
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
	for k in Data.KINDS:
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
