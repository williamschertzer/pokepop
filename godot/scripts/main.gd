extends Control
## Builds the whole interface in code (header, game field, party shop, upgrade
## overlay, map picker and end screen) and connects it to the simulation.

const BG := Color("#181b38")
const PANEL := Color("#242a55")
const PANEL2 := Color("#2e3568")
const INSET := Color("#121530")
const LINE := Color("#3b4384")
const TEXT := Color("#f4f0e3")
const MUTED := Color("#a9aed6")
const RED := Color("#df3a3f")
const RED_DEEP := Color("#9c2329")
const GOLD := Color("#ffd23f")
const GREEN := Color("#5fd38a")
const BAD := Color("#ff6b6b")

const SAVE_PATH := "user://pokepop.cfg"

var game := Game.new()
var sfx: Sfx
var stage: Stage

var f_body: Font
var f_bold: Font
var f_light: Font
var f_disp: Font
var f_disp_b: Font
var f_caps: Font

var _lives_lbl: Label
var _money_lbl: Label
var _wave_lbl: Label
var _mapname_lbl: Label
var _mute_btn: Button
var _play_btn: Button
var _speed_btn: Button
var _pause_btn: Button
var _auto_chk: CheckBox
var _shop_grid: GridContainer
var _shop_buttons := {}
var _info_box: VBoxContainer
var _sheet: PanelContainer
var _sheet_box: VBoxContainer
var _sheet_pops: Label
var _cost_widgets: Array = []
var _toast: PanelContainer
var _toast_lbl: Label
var _toast_tween: Tween
var _menu: Control
var _maps_grid: GridContainer
var _end: Control
var _end_label: Label
var _end_title: Label
var _end_text: Label
var _end_primary: Button
var _hud_tick := 0.0
var _hud_key := ""
var _money_tween: Tween
var _title: Control
var _title_art: Control
var _continue_btn: Button
var _settings: Control
var _pause_menu: Control
var _next_box: HFlowContainer
var _next_key := ""
var _stat_labels: Array = []
var _drag_kind := ""
var _drag_on_field := false
var _drag_start := Vector2.ZERO
var _diff_box: HBoxContainer
var _items_box: HBoxContainer
var _item_buttons := {}
var _dex: Control
var _dex_box: VBoxContainer


# ---------- small widgets ----------
class MonIcon extends Control:
	var sp := "pikachu"
	var sc := 0.8
	var bg = null

	func _init(sprite: String, px: float, scale_: float, bgc = null) -> void:
		sp = sprite
		sc = scale_
		bg = bgc
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if bg != null:
			var sb := StyleBoxFlat.new()
			sb.bg_color = bg
			sb.set_corner_radius_all(10)
			draw_style_box(sb, Rect2(Vector2.ZERO, size))
		Art.put_mon(self, sp, size.x / 2, size.y / 2 - 2, sc, false, 1.2)


class BallIcon extends Control:
	var type := "poke"

	func _init(t: String) -> void:
		type = t
		custom_minimum_size = Vector2(28, 28)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r: float = Data.BALLS[type].r
		if type == "rocket":
			var k := 26.0 / (r * 2 + 44)
			Art.put_ball(self, type, 14, 14 - 14 * k, 0, k)
		else:
			Art.put_ball(self, type, 14, 14, 0, minf(1.0, 26.0 / ((r + 3) * 2)))


class MapPreview extends Control:
	var cmds: Array

	func _init(c: Array, w: float) -> void:
		cmds = c
		custom_minimum_size = Vector2(w, w * 10.0 / 16.0)
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * (size.x / Data.W))
		Pen.draw_baked(self, cmds)
		draw_set_transform_matrix(Transform2D.IDENTITY)


class Lens extends Control:
	var k := 1.0

	func _init(scale_ := 1.0) -> void:
		k = scale_
		custom_minimum_size = Vector2(30, 30) * k
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2
		draw_circle(c, 17 * k, Color("#9c2329"))
		draw_circle(c, 15 * k, Color.WHITE)
		draw_circle(c, 12 * k, Color("#1c6aa8"))
		draw_circle(c, 9.5 * k, Color("#3aa7e8"))
		draw_circle(c - Vector2(3, 3) * k, 3.5 * k, Color("#bfe9ff"))


## Animated backdrop for the title screen: a night sky, the party standing
## guard and Team Rocket's Pokéballs rolling along the route below them.
class TitleArt extends Control:
	const PARTY := ["pikachu", "charmander", "squirtle", "bulbasaur", "gastly", "meowth", "wobbuffet", "mewtwo"]
	const ROLL := ["poke", "great", "ultra", "poke", "quick", "great", "heavy", "poke", "dusk", "ultra"]
	var t := 0.0

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(dt: float) -> void:
		if is_visible_in_tree():
			t += dt
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var gy := h - 150
		draw_rect(Rect2(0, 0, w, gy), Color("#181b38"))
		for i in 70:
			var sx := fposmod(i * 137.5 + 40, w)
			var sy := fposmod(i * 71.3 + 12, gy - 30)
			var a := .25 + .25 * sin(t * 1.5 + i * 1.7)
			draw_circle(Vector2(sx, sy), 1.0 + (i % 3) * .5, Color(1, 1, 1, a))
		draw_circle(Vector2(w - 150, 92), 38, Color("#f6efc8"))
		draw_circle(Vector2(w - 136, 84), 34, Color("#181b38"))
		# Team Rocket's balloon drifting across the sky
		var bx := fposmod(t * 18 + 260, w + 300) - 150
		Art.put_ball(self, "rocket", bx, 330 + sin(t * .9) * 12, sin(t * .7) * .05, 1.1)
		# hills, grass and the route
		for i in 7:
			var hx := w * (i / 6.0) + 40
			draw_circle(Vector2(hx, gy + 70), 110 + (i % 3) * 30, Color("#1f2448") if i % 2 else Color("#262c56"))
		draw_rect(Rect2(0, gy, w, h - gy), Color("#3f7e3c"))
		draw_rect(Rect2(0, gy, w, 6), Color("#5aa650"))
		for i in 40:
			var tx := fposmod(i * 53.0, w)
			var ty := gy + 14 + (i * 37) % 40
			draw_line(Vector2(tx, ty), Vector2(tx - 3, ty - 7), Color("#5aa650"), 2)
			draw_line(Vector2(tx, ty), Vector2(tx + 3, ty - 7), Color("#5aa650"), 2)
		var py := gy + 88.0
		draw_rect(Rect2(0, py - 22, w, 44), Color("#d6b475"))
		draw_rect(Rect2(0, py - 22, w, 4), Color("#b8955a"))
		draw_rect(Rect2(0, py + 18, w, 4), Color("#b8955a"))
		var n := ROLL.size()
		for i in n:
			var x := fposmod(t * 60 + i * (w + 120) / n, w + 120) - 60
			var r: float = Data.BALLS[ROLL[i]].r
			draw_set_transform(Vector2(x, py + r * .85 - 4), 0, Vector2(1, .35))
			draw_circle(Vector2.ZERO, r * .8, Color(0, 0, 0, .22))
			draw_set_transform_matrix(Transform2D.IDENTITY)
			Art.put_ball(self, ROLL[i], x, py - 4, t * 3 + i, 1.3)
		for i in PARTY.size():
			var x := w * (i + .5) / PARTY.size()
			var hop := absf(sin(t * 2.2 + i * .8)) * 5
			Art.put_mon(self, PARTY[i], x, gy + 38 - hop, 1.45, i >= PARTY.size() / 2, t + i)


## A panel that behaves like a button, for cards with several lines of text.
class CardButton extends PanelContainer:
	signal pressed
	var normal: StyleBox
	var hover: StyleBox
	var disabled := false
	var _over := false

	func _init(n: StyleBox, h: StyleBox) -> void:
		normal = n
		hover = h
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_theme_stylebox_override("panel", n)
		mouse_entered.connect(func(): _over = true; _restyle())
		mouse_exited.connect(func(): _over = false; _restyle())

	func set_disabled(v: bool) -> void:
		disabled = v
		mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if v else Control.CURSOR_POINTING_HAND
		_restyle()

	func _restyle() -> void:
		add_theme_stylebox_override("panel", hover if _over and not disabled else normal)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not disabled:
			pressed.emit()
			accept_event()


# ---------- setup ----------
func _ready() -> void:
	_load_fonts()
	_load_save()
	var th := Theme.new()
	th.default_font = f_body
	th.default_font_size = 14
	th.set_color("font_color", "Label", TEXT)
	theme = th
	sfx = Sfx.new()
	add_child(sfx)
	sfx.muted = _muted
	game.best = _best
	_seen_unlocked = _unlocked_now()
	game.toast.connect(_show_toast)
	game.sfx.connect(func(f, d, ty, v): sfx.blip(f, d, ty, v))
	game.ended.connect(_show_end)
	game.info_changed.connect(_render_info)
	game.money_bump.connect(_bump_money)
	game.wave_cleared.connect(_on_wave_cleared)
	game.info_changed.connect(_save_run)
	_build()
	_render_shop()
	_render_info()
	_show_title()
	get_viewport().size_changed.connect(_layout_check)


func _font(path: String, wght: int, spacing := 0) -> Font:
	var fv := FontVariation.new()
	fv.base_font = load(path)
	var ts := TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): wght}
	if spacing:
		fv.spacing_glyph = spacing
	return fv


func _load_fonts() -> void:
	f_body = _font("res://fonts/Nunito.ttf", 700)
	f_bold = _font("res://fonts/Nunito.ttf", 800)
	f_light = _font("res://fonts/Nunito.ttf", 600)
	f_caps = _font("res://fonts/Nunito.ttf", 800, 1)
	f_disp = _font("res://fonts/PixelifySans.ttf", 600)
	f_disp_b = _font("res://fonts/PixelifySans.ttf", 700)
	Pen.font_display = f_disp
	Pen.font_body = f_bold


var _best := {}
var _muted := false
var _volume := 0.8
var _confirm_release := true
var _run := {}  # the saved run for Continue, empty when there is none
var _diff := "normal"
var _unlock_all := false
var _seen_unlocked := []  # Pokémon already unlocked, to announce new ones


func _load_save() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		_best = cf.get_value("save", "best", {})
		_muted = cf.get_value("save", "muted", false)
		_volume = cf.get_value("save", "volume", 0.8)
		_confirm_release = cf.get_value("save", "confirm_release", true)
		_run = cf.get_value("save", "run", {})
		_diff = cf.get_value("save", "diff", "normal")
		_unlock_all = cf.get_value("save", "unlock_all", false)
	_apply_volume()


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("save", "best", game.best)
	cf.set_value("save", "muted", sfx.muted)
	cf.set_value("save", "volume", _volume)
	cf.set_value("save", "confirm_release", _confirm_release)
	cf.set_value("save", "run", _run)
	cf.set_value("save", "diff", _diff)
	cf.set_value("save", "unlock_all", _unlock_all)
	cf.save(SAVE_PATH)


func _unlocked(k: String) -> bool:
	return _unlock_all or Data.is_unlocked(k, game.best)


func _unlocked_now() -> Array:
	return Data.UNLOCK.keys().filter(func(k): return Data.is_unlocked(k, game.best))


## "Locked. Beat 2 different maps on Normal or Hard (1 so far)."
func _lock_text(k: String) -> String:
	var r := Data.unlock_req(k)
	var t := "Locked. %s to unlock %s." % [Data.unlock_text(k), Data.TOWERS[k].name]
	if r.maps > 1:
		t = t.trim_suffix(".") + " (%d so far)." % Data.unlock_progress(k, game.best)
	return t


func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(_volume, .001)))
	AudioServer.set_bus_mute(0, _volume <= 0.01)


## Saves the run so Continue can pick it up. Only between waves, so a run
## always resumes from a calm moment rather than halfway through a wave.
func _save_run() -> void:
	if game.map == null or game.over or game.running:
		return
	_run = game.snapshot()
	_save()


func _on_wave_cleared() -> void:
	_save_run()
	var now := _unlocked_now()
	for k in now:
		if not _unlock_all and not _seen_unlocked.has(k):
			_show_toast("New Pokémon unlocked: %s! Find it in your Party." % Data.TOWERS[k].name)
			_render_shop()
	_seen_unlocked = now


func _clear_run() -> void:
	_run = {}
	_save()


func _layout_check() -> void:
	pass


# ---------- builders ----------
func _sb(bg: Color, radius := 12, pad := 12, border := 0, border_col := LINE) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	if border:
		s.set_border_width_all(border)
		s.border_color = border_col
	s.anti_aliasing = true
	return s


func _lbl(text: String, size := 14.0, col := TEXT, font: Font = null, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(round(size)))
	l.add_theme_color_override("font_color", col)
	if font:
		l.add_theme_font_override("font", font)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _caps(text: String, col := MUTED, size := 10.0) -> Label:
	return _lbl(text.to_upper(), size, col, f_caps)


func _pill(text: String, bg: Color, fg := Color("#1a1530"), size := 10.0, radius := 99) -> Label:
	var l := _lbl(text.to_upper(), size, fg, f_caps)
	var s := _sb(bg, radius, 0)
	s.content_margin_left = 7
	s.content_margin_right = 7
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	l.add_theme_stylebox_override("normal", s)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _btn(text: String, bg := PANEL2, fg := TEXT, hover := Color("#3a4280"), radius := 10, pad := 10) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", f_bold)
	b.add_theme_font_size_override("font_size", 14)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, .45))
	var n := _sb(bg, radius, pad)
	var h := _sb(hover, radius, pad)
	var d := _sb(Color(bg, .45), radius, pad)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("hover_pressed", h)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


func _restyle_btn(b: Button, bg: Color, fg: Color, hover: Color) -> void:
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_stylebox_override("normal", _sb(bg, 10, 10))
	b.add_theme_stylebox_override("hover", _sb(hover, 10, 10))
	b.add_theme_stylebox_override("pressed", _sb(hover, 10, 10))
	b.add_theme_stylebox_override("hover_pressed", _sb(hover, 10, 10))


func _card() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(PANEL, 12, 12))
	return p


func _vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func _hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# header
	var head := PanelContainer.new()
	var hs := _sb(RED, 14, 10)
	hs.border_width_bottom = 4
	hs.border_color = RED_DEEP
	hs.content_margin_left = 14
	hs.content_margin_right = 14
	hs.content_margin_top = 7
	hs.content_margin_bottom = 9
	head.add_theme_stylebox_override("panel", hs)
	head.position = Vector2(12, 8)
	head.size = Vector2(1256, 52)
	add_child(head)
	var hrow := _hbox(16)
	head.add_child(hrow)
	hrow.add_child(Lens.new())
	var brand := _vbox(0)
	var title := _lbl("PokéPop Defense", 22, Color.WHITE, f_disp_b)
	title.add_theme_color_override("font_shadow_color", RED_DEEP)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.add_theme_constant_override("shadow_offset_x", 0)
	brand.add_child(title)
	_mapname_lbl = _caps("Choose a route", Color("#ffd9d9"), 11)
	brand.add_child(_mapname_lbl)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(brand)
	var stat := func(label: String, col: Color) -> Label:
		var p := PanelContainer.new()
		var s := _sb(INSET, 9, 0)
		s.content_margin_left = 11; s.content_margin_right = 11; s.content_margin_top = 3; s.content_margin_bottom = 3
		p.add_theme_stylebox_override("panel", s)
		var r := _hbox(6)
		var sl := _caps(label, MUTED, 10)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(sl)
		var v := _lbl("0", 18, col, f_bold)
		r.add_child(v)
		p.add_child(r)
		hrow.add_child(p)
		return v
	_lives_lbl = stat.call("Pikachu HP", Color("#ff8c8c"))
	_money_lbl = stat.call("Pokédollars", GOLD)
	_wave_lbl = stat.call("Wave", TEXT)
	_money_lbl.pivot_offset = Vector2(20, 12)
	_mute_btn = _btn("Sound on", INSET, TEXT, Color("#1c2045"), 9, 7)
	_mute_btn.add_theme_font_size_override("font_size", 12)
	_mute_btn.pressed.connect(_toggle_mute)
	hrow.add_child(_mute_btn)
	_mute_btn.text = "Sound off" if sfx.muted else "Sound on"
	var menu_btn := _btn("Menu", INSET, TEXT, Color("#1c2045"), 9, 7)
	menu_btn.add_theme_font_size_override("font_size", 12)
	menu_btn.tooltip_text = "Pause and open the menu (Esc)"
	menu_btn.pressed.connect(_open_pause_menu)
	hrow.add_child(menu_btn)

	# game field
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", _sb(Color("#0b0d20"), 12, 0, 2, LINE))
	frame.position = Vector2(12, 68)
	frame.size = Vector2(966, 606)
	add_child(frame)
	stage = Stage.new()
	stage.game = game
	stage.position = Vector2(15, 71)
	add_child(stage)
	stage.tower_clicked.connect(_on_tower_clicked)
	stage.place_requested.connect(_try_place)
	stage.touch_preview.connect(func(x, y): _show_toast("Tap again to place" if game.can_place(stage.placing, x, y) else "Can't place there"))

	# upgrade overlay on the field
	_sheet = PanelContainer.new()
	_sheet.add_theme_stylebox_override("panel", _sb(Color(22 / 255.0, 25 / 255.0, 54 / 255.0, .96), 14, 12, 2, LINE))
	_sheet.size = Vector2(340, 580)
	_sheet.position = Vector2(10, 10)
	_sheet.visible = false
	stage.add_child(_sheet)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sheet.add_child(sc)
	_sheet_box = _vbox(10)
	_sheet_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_sheet_box)

	# toast
	_toast = PanelContainer.new()
	var ts := _sb(Color(10 / 255.0, 12 / 255.0, 30 / 255.0, .86), 99, 0)
	ts.content_margin_left = 14; ts.content_margin_right = 14; ts.content_margin_top = 6; ts.content_margin_bottom = 7
	_toast.add_theme_stylebox_override("panel", ts)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_lbl = _lbl("", 13, Color.WHITE, f_body)
	_toast.add_child(_toast_lbl)
	_toast.modulate.a = 0
	stage.add_child(_toast)

	# side panel
	var side := _vbox(10)
	side.position = Vector2(990, 68)
	side.size = Vector2(278, 606)
	add_child(side)
	var c1 := _card()
	side.add_child(c1)
	var c1v := _vbox(8)
	c1.add_child(c1v)
	var ctr := _hbox(8)
	c1v.add_child(ctr)
	_play_btn = _btn("Start wave 1", GREEN, Color("#0d2a18"), Color("#7be3a2"))
	_play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_btn.pressed.connect(func(): game.start_wave(); _update_hud(true))
	ctr.add_child(_play_btn)
	_speed_btn = _btn("1×")
	_speed_btn.tooltip_text = "Game speed (F)"
	_speed_btn.pressed.connect(_cycle_speed)
	ctr.add_child(_speed_btn)
	_pause_btn = _btn("Pause")
	_pause_btn.tooltip_text = "Pause (P)"
	_pause_btn.pressed.connect(_toggle_pause)
	ctr.add_child(_pause_btn)
	_auto_chk = CheckBox.new()
	_auto_chk.text = "Start next wave automatically"
	_auto_chk.focus_mode = Control.FOCUS_NONE
	_auto_chk.add_theme_font_size_override("font_size", 12)
	_auto_chk.add_theme_color_override("font_color", MUTED)
	_auto_chk.add_theme_color_override("font_hover_color", TEXT)
	_auto_chk.add_theme_color_override("font_pressed_color", MUTED)
	_auto_chk.add_theme_color_override("font_hover_pressed_color", TEXT)
	_auto_chk.toggled.connect(func(on): game.auto = on; game.auto_timer = .5)
	c1v.add_child(_auto_chk)
	_items_box = _hbox(5)
	c1v.add_child(_items_box)
	for id in ["potion", "repel", "candy"]:
		var it: Dictionary = Data.ITEMS[id]
		var ib := _btn(it.name, INSET, TEXT, Color("#1c2045"), 8, 5)
		ib.add_theme_font_size_override("font_size", 11)
		ib.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ib.pressed.connect(_use_item.bind(id))
		_items_box.add_child(ib)
		_item_buttons[id] = ib
	_next_box = HFlowContainer.new()
	_next_box.add_theme_constant_override("h_separation", 4)
	_next_box.add_theme_constant_override("v_separation", 2)
	c1v.add_child(_next_box)

	var c2 := _card()
	side.add_child(c2)
	var c2v := _vbox(10)
	c2.add_child(c2v)
	c2v.add_child(_lbl("Party", 15, Color.WHITE, f_disp))
	_shop_grid = GridContainer.new()
	_shop_grid.columns = 4
	_shop_grid.add_theme_constant_override("h_separation", 6)
	_shop_grid.add_theme_constant_override("v_separation", 6)
	c2v.add_child(_shop_grid)

	var c3 := _card()
	c3.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(c3)
	var sc3 := ScrollContainer.new()
	sc3.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c3.add_child(sc3)
	_info_box = _vbox(8)
	_info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc3.add_child(_info_box)

	_build_pause_menu()
	_build_menu()
	_build_end()
	_build_title()
	_build_dex()
	_build_settings()


func _build_menu() -> void:
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_menu)
	var dim := ColorRect.new()
	dim.color = Color(10 / 255.0, 12 / 255.0, 32 / 255.0, .94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(dim)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_menu.add_child(sc)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_left", 150)
	m.add_theme_constant_override("margin_right", 150)
	m.add_theme_constant_override("margin_top", 28)
	m.add_theme_constant_override("margin_bottom", 28)
	sc.add_child(m)
	var v := _vbox(18)
	m.add_child(v)
	var back := _btn("‹ Back", PANEL2, TEXT, Color("#3a4280"), 10, 8)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_menu_back)
	v.add_child(back)
	var top := _vbox(4)
	top.add_child(_caps("Prepare for trouble", GOLD, 10))
	var h := RichTextLabel.new()
	h.bbcode_enabled = true
	h.fit_content = true
	h.scroll_active = false
	h.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_theme_font_override("normal_font", f_disp_b)
	h.add_theme_font_size_override("normal_font_size", 34)
	h.add_theme_color_override("default_color", TEXT)
	h.text = "Team Rocket wants Ash's [color=#ffd23f]Pikachu[/color]."
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(h)
	v.add_child(top)
	var lead := _lbl("Jessie, James and Meowth are firing Pokéballs down the route at Ash's Pikachu. Line the path with Pokémon and pop every ball before it reaches him. Each hit knocks a ball down one catch-rate tier, from Master Ball down to a plain Poké Ball. Evolve your team or teach them new moves, and hold out for 40 waves, when Team Rocket's Meowth balloon shows up.", 15, MUTED, f_light, true)
	lead.custom_minimum_size.x = 640
	lead.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(lead)
	_diff_box = _hbox(6)
	v.add_child(_diff_box)
	_maps_grid = GridContainer.new()
	_maps_grid.columns = 4
	_maps_grid.add_theme_constant_override("h_separation", 12)
	_maps_grid.add_theme_constant_override("v_separation", 12)
	v.add_child(_maps_grid)
	var how := GridContainer.new()
	how.columns = 4
	how.add_theme_constant_override("h_separation", 12)
	how.add_theme_constant_override("v_separation", 12)
	v.add_child(how)
	var tips := [
		["Pikachu", "Fast Thunder Shocks that chain between balls. Heavy Balls are insulated."],
		["Charmander", "Flame bursts that hit a whole cluster. Charizard can see Dusk Balls."],
		["Squirtle", "Water Gun knocks balls back down the path. Bubble Beam slows them."],
		["Bulbasaur", "Razor Leaf slices through lines of balls. Leech Seed earns money."],
		["Gastly", "Exploding Shadow Balls and a ghost's eye for hidden Dusk Balls."],
		["Meowth", "Quit Team Rocket. Pay Day earns Pokédollars every wave."],
		["Wobbuffet", "Never attacks. Hurts itself in confusion, which its upgrades weaponize."],
		["Mewtwo", "Costs ₽3000. Worth it."],
	]
	for tip in tips:
		var p := PanelContainer.new()
		var s := _sb(PANEL, 12, 12)
		s.content_margin_left = 14
		s.content_margin_right = 14
		p.add_theme_stylebox_override("panel", s)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pv := _vbox(3)
		pv.add_child(_lbl(tip[0], 14, TEXT, f_bold))
		var tl := _lbl(tip[1], 13, MUTED, f_light, true)
		tl.custom_minimum_size.x = 210
		pv.add_child(tl)
		p.add_child(pv)
		how.add_child(p)
	var help := _lbl("Drag a Pokémon from your Party onto the map, or click it and then click the map. Keys: 1 to 9 and 0 pick a Pokémon, Space starts a wave, F changes speed, P pauses, Esc cancels or opens the menu. On a touch screen you can also tap a spot to preview and tap it again to place.", 12.5, MUTED, f_light, true)
	v.add_child(help)


func _build_end() -> void:
	_end = Control.new()
	_end.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end.mouse_filter = Control.MOUSE_FILTER_STOP
	_end.visible = false
	add_child(_end)
	var dim := ColorRect.new()
	dim.color = Color(10 / 255.0, 12 / 255.0, 32 / 255.0, .9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end.add_child(dim)
	var v := _vbox(18)
	v.position = Vector2(380, 110)
	v.size = Vector2(520, 0)
	_end.add_child(v)
	_end_label = _caps("Game over", MUTED, 10)
	v.add_child(_end_label)
	_end_title = _lbl("", 34, TEXT, f_disp_b, true)
	_end_title.custom_minimum_size.x = 520
	v.add_child(_end_title)
	_end_text = _lbl("", 15, MUTED, f_light, true)
	_end_text.custom_minimum_size.x = 520
	v.add_child(_end_text)
	var row := _hbox(10)
	v.add_child(row)
	_end_primary = _btn("Try again", GREEN, Color("#0d2a18"), Color("#7be3a2"))
	_end_primary.pressed.connect(_end_primary_pressed)
	row.add_child(_end_primary)
	var maps := _btn("Pick another map")
	maps.pressed.connect(func(): _end.visible = false; _open_menu())
	row.add_child(maps)


func _overlay(parent: Node, dim_alpha: float) -> Control:
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	o.visible = false
	parent.add_child(o)
	var dim := ColorRect.new()
	dim.color = Color(10 / 255.0, 12 / 255.0, 32 / 255.0, dim_alpha)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	return o


func _menu_btn(text: String, primary := false) -> Button:
	var b := _btn(text, GREEN, Color("#0d2a18"), Color("#7be3a2"), 12, 12) if primary else _btn(text, PANEL2, TEXT, Color("#3a4280"), 12, 12)
	b.add_theme_font_size_override("font_size", 17)
	b.custom_minimum_size = Vector2(300, 50)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b


## Makes a button ask "Tap again" first, for things that can't be undone.
func _two_tap(b: Button, confirm_text: String, action: Callable) -> void:
	var normal_text := b.text
	b.pressed.connect(func():
		if b.has_meta("armed"):
			b.remove_meta("armed")
			b.text = normal_text
			action.call()
			return
		b.set_meta("armed", true)
		b.text = confirm_text
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(b) and b.has_meta("armed"):
				b.remove_meta("armed")
				b.text = normal_text))


# ---------- title screen ----------
func _build_title() -> void:
	_title = Control.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_title)
	_title_art = TitleArt.new()
	_title.add_child(_title_art)
	var v := _vbox(12)
	v.position = Vector2(290, 96)
	v.size = Vector2(700, 0)
	_title.add_child(v)
	var logo := _hbox(16)
	logo.alignment = BoxContainer.ALIGNMENT_CENTER
	var lens := Lens.new(2.2)
	lens.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	logo.add_child(lens)
	var name_lbl := _lbl("PokéPop Defense", 58, Color.WHITE, f_disp_b)
	name_lbl.add_theme_color_override("font_shadow_color", RED_DEEP)
	name_lbl.add_theme_constant_override("shadow_offset_y", 4)
	name_lbl.add_theme_constant_override("shadow_offset_x", 0)
	name_lbl.add_theme_color_override("font_outline_color", RED)
	name_lbl.add_theme_constant_override("outline_size", 10)
	logo.add_child(name_lbl)
	v.add_child(logo)
	var sub := _lbl("Team Rocket wants Ash's Pikachu. Pop every Pokéball before it reaches him.", 16, MUTED, f_light, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.custom_minimum_size.x = 700
	v.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 14
	v.add_child(gap)
	_continue_btn = _menu_btn("Continue", true)
	_continue_btn.pressed.connect(_continue)
	v.add_child(_continue_btn)
	var play := _menu_btn("New game")
	play.pressed.connect(_open_menu)
	v.add_child(play)
	var dex := _menu_btn("Pokédex")
	dex.pressed.connect(_open_dex)
	v.add_child(dex)
	var settings := _menu_btn("Settings")
	settings.pressed.connect(func(): _settings.visible = true)
	v.add_child(settings)


func _has_live_run() -> bool:
	return game.map != null and not game.over and not (game.won and not game.freeplay)


func _show_title() -> void:
	var info := {}
	if _has_live_run():
		info = {"map": game.map.id, "wave": game.wave, "running": game.running}
	elif not _run.is_empty():
		info = _run
	_continue_btn.visible = not info.is_empty()
	if not info.is_empty():
		var map_name := ""
		for m in Data.MAPS:
			if m.id == info.map:
				map_name = m.name
		var n: int = info.wave if info.get("running", false) else info.wave + 1
		_continue_btn.text = "Continue: %s, wave %d" % [map_name, n]
	_menu.visible = false
	_end.visible = false
	_title.visible = true


func _continue() -> void:
	_title.visible = false
	if _has_live_run():
		game.paused = false
	elif game.restore(_run):
		_after_map_loaded()
		_show_toast("Welcome back! Wave %d is next." % (game.wave + 1))
	_update_hud(true)


# ---------- Pokédex ----------
func _build_dex() -> void:
	_dex = _overlay(self, .96)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dex.add_child(sc)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 90)
	m.add_theme_constant_override("margin_top", 24)
	m.add_theme_constant_override("margin_bottom", 28)
	sc.add_child(m)
	_dex_box = _vbox(12)
	m.add_child(_dex_box)


func _open_dex() -> void:
	_clear(_dex_box)
	var top := _hbox(12)
	var back := _btn("‹ Back", PANEL2, TEXT, Color("#3a4280"), 10, 8)
	back.pressed.connect(func(): _dex.visible = false)
	top.add_child(back)
	var tl := _lbl("Pokédex", 30, TEXT, f_disp_b)
	top.add_child(tl)
	_dex_box.add_child(top)
	_dex_box.add_child(_lbl("Every Pokémon you can bring and every ball Team Rocket throws. New Pokémon unlock as you beat later waves and more maps on Normal or Hard.", 14, MUTED, f_light, true))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_dex_box.add_child(grid)
	for k in Data.KINDS:
		grid.add_child(_dex_card(k))
	_dex_box.add_child(_lbl("Pokéballs", 22, TEXT, f_disp_b))
	var bg := GridContainer.new()
	bg.columns = 3
	bg.add_theme_constant_override("h_separation", 12)
	bg.add_theme_constant_override("v_separation", 8)
	_dex_box.add_child(bg)
	for t in Data.ORDER:
		var b: Dictionary = Data.BALLS[t]
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _sb(PANEL, 10, 10))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := _hbox(8)
		row.add_child(BallIcon.new(t))
		var tv := _vbox(0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(_lbl(b.name, 13, TEXT, f_bold))
		var nl := _lbl(b.note, 11.5, MUTED, f_light, true)
		nl.custom_minimum_size.x = 260
		tv.add_child(nl)
		row.add_child(tv)
		p.add_child(row)
		bg.add_child(p)
	_dex_box.add_child(_lbl("Type matchups", 22, TEXT, f_disp_b))
	var lines: Array = []
	for ty in Data.TYPE_EFFECT:
		for ball in Data.TYPE_EFFECT[ty]:
			var mul: float = Data.TYPE_EFFECT[ty][ball]
			lines.append("%s attacks do %s damage to %ss." % [ty, ("double" if mul == 2 else ("half" if mul == .5 else "%s×" % _num(mul))), Data.BALLS[ball].name])
	_dex_box.add_child(_lbl("\n".join(lines), 13.5, MUTED, f_light, true))
	_dex.visible = true


func _dex_card(k: String) -> Control:
	var d: Dictionary = Data.TOWERS[k]
	var locked := not _unlocked(k)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(PANEL, 12, 12))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := _vbox(6)
	p.add_child(v)
	var head := _hbox(10)
	var icon := MonIcon.new(Data.sprite_for(k, 0), 56, .9, INSET)
	if locked:
		icon.modulate = Color(.15, .15, .2)
	head.add_child(icon)
	var hv := _vbox(3)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(_lbl(d.name, 18, TEXT, f_disp))
	var meta := _hbox(6)
	meta.add_child(_pill(d.type, Color(Data.TYPE_COLORS[d.type])))
	meta.add_child(_lbl("₽%d · %s" % [d.cost, d.role], 12, MUTED, f_light))
	hv.add_child(meta)
	head.add_child(hv)
	v.add_child(head)
	if locked:
		v.add_child(_lbl(_lock_text(k), 12.5, GOLD, f_light, true))
	var bl := _lbl(d.blurb, 12.5, MUTED, f_light, true)
	bl.custom_minimum_size.x = 480
	v.add_child(bl)
	var names := Data.path_names(k)
	var cols := _hbox(10)
	for pi in 2:
		var list: Array = d.A if pi == 0 else d.B
		var col := _vbox(3)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(_caps(names[pi]))
		for u in list:
			var ul := _lbl("%s (₽%d): %s" % [u.name.replace("Evolve: ", ""), u.cost, u.desc], 11.5, TEXT if not locked else MUTED, f_light, true)
			ul.custom_minimum_size.x = 230
			col.add_child(ul)
		cols.add_child(col)
	v.add_child(cols)
	return p


# ---------- settings ----------
func _build_settings() -> void:
	_settings = _overlay(self, .8)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings.add_child(cc)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _sb(PANEL, 16, 24, 2, LINE))
	cc.add_child(card)
	var v := _vbox(16)
	v.custom_minimum_size.x = 380
	card.add_child(v)
	v.add_child(_lbl("Settings", 26, TEXT, f_disp_b))

	var vol := _vbox(6)
	var vh := _hbox(8)
	var vcap := _caps("Sound volume", MUTED, 11)
	vcap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vh.add_child(vcap)
	var vval := _lbl("%d%%" % int(round(_volume * 100)), 13, TEXT, f_bold)
	vh.add_child(vval)
	vol.add_child(vh)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = round(_volume * 100)
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size.y = 24
	var track := _sb(INSET, 4, 0)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", _sb(GOLD, 4, 0))
	slider.add_theme_stylebox_override("grabber_area_highlight", _sb(GOLD, 4, 0))
	slider.value_changed.connect(func(val: float):
		_volume = val / 100.0
		_apply_volume()
		vval.text = "%d%%" % int(val)
		sfx.blip(880, .05, "square", .03))
	slider.drag_ended.connect(func(_c): _save())
	vol.add_child(slider)
	v.add_child(vol)

	var chk := CheckBox.new()
	chk.text = "Ask before releasing a Pokémon"
	chk.focus_mode = Control.FOCUS_NONE
	chk.button_pressed = _confirm_release
	chk.add_theme_font_size_override("font_size", 14)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		chk.add_theme_color_override(st, TEXT)
	chk.toggled.connect(func(on): _confirm_release = on; _save())
	v.add_child(chk)
	var ua := CheckBox.new()
	ua.text = "Unlock every Pokémon right away"
	ua.focus_mode = Control.FOCUS_NONE
	ua.button_pressed = _unlock_all
	ua.add_theme_font_size_override("font_size", 14)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		ua.add_theme_color_override(st, TEXT)
	ua.toggled.connect(func(on): _unlock_all = on; _save(); _render_shop())
	v.add_child(ua)

	var reset := _btn("Reset best waves and saved game", Color(0, 0, 0, 0), Color("#ffb3b3"), Color(0, 0, 0, 0), 10, 10)
	reset.add_theme_stylebox_override("normal", _sb(Color(0, 0, 0, 0), 10, 10, 2, LINE))
	reset.add_theme_stylebox_override("hover", _sb(Color(0, 0, 0, 0), 10, 10, 2, BAD))
	_two_tap(reset, "Tap again to erase your progress", func():
		game.best = {}
		_seen_unlocked = []
		_run = {}
		_save()
		if _title.visible:
			_show_title()
		_show_toast("Progress reset."))
	v.add_child(reset)

	var done := _btn("Done", GREEN, Color("#0d2a18"), Color("#7be3a2"), 10, 10)
	done.pressed.connect(func(): _settings.visible = false)
	v.add_child(done)


# ---------- pause menu ----------
func _build_pause_menu() -> void:
	_pause_menu = Control.new()
	_pause_menu.position = Vector2(12, 68)
	_pause_menu.size = Vector2(966, 606)
	_pause_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_menu.visible = false
	add_child(_pause_menu)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_menu.add_child(cc)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _sb(Color(22 / 255.0, 25 / 255.0, 54 / 255.0, .97), 16, 22, 2, LINE))
	cc.add_child(card)
	var v := _vbox(10)
	card.add_child(v)
	var t := _lbl("Paused", 32, TEXT, f_disp_b)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var resume := _menu_btn("Resume", true)
	resume.pressed.connect(_toggle_pause)
	v.add_child(resume)
	var restart := _menu_btn("Restart this map")
	_two_tap(restart, "Tap again to restart", func(): _start_map(game.map, game.diff))
	v.add_child(restart)
	var maps := _menu_btn("Change map")
	maps.pressed.connect(_open_menu)
	v.add_child(maps)
	var dex := _menu_btn("Pokédex")
	dex.pressed.connect(_open_dex)
	v.add_child(dex)
	var settings := _menu_btn("Settings")
	settings.pressed.connect(func(): _settings.visible = true)
	v.add_child(settings)
	var home := _menu_btn("Main menu")
	home.pressed.connect(_show_title)
	v.add_child(home)


func _open_pause_menu() -> void:
	if game.map and not game.over and not game.paused:
		_toggle_pause()


# ---------- menu ----------
func _open_menu() -> void:
	_title.visible = false
	_clear(_maps_grid)
	_clear(_diff_box)
	var dl := _caps("Difficulty", MUTED, 11)
	dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_diff_box.add_child(dl)
	for dk in ["easy", "normal", "hard"]:
		var on: bool = _diff == dk
		var db := _btn(Data.DIFFS[dk].name, GOLD if on else PANEL2, Color("#2b2200") if on else TEXT, GOLD if on else Color("#3a4280"), 9, 7)
		db.custom_minimum_size.x = 90
		db.pressed.connect(func(): _diff = dk; _save(); _open_menu())
		_diff_box.add_child(db)
	var dh := {"easy": "More money and HP, slower balls.", "normal": "The standard game.", "hard": "Less money and HP, faster balls."}
	var dhl := _lbl(dh[_diff], 12.5, MUTED, f_light)
	dhl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_diff_box.add_child(dhl)
	for m in Data.MAPS:
		var path := MapArt.build_path(m.path)
		var o := MapArt.gen_obstacles(m, path)
		var cmds := MapArt.render_bg(m, path, o.obs, o.deco)
		var n := _sb(PANEL, 14, 0, 2, LINE)
		var hv := _sb(PANEL, 14, 0, 2, GOLD)
		var card := CardButton.new(n, hv)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := _vbox(0)
		card.add_child(cv)
		var prev := MapPreview.new(cmds, 233)
		cv.add_child(prev)
		var mc := MarginContainer.new()
		for side in ["left", "right"]:
			mc.add_theme_constant_override("margin_" + side, 12)
		mc.add_theme_constant_override("margin_top", 10)
		mc.add_theme_constant_override("margin_bottom", 12)
		cv.add_child(mc)
		var info := _vbox(2)
		mc.add_child(info)
		info.add_child(_lbl(m.name, 18, TEXT, f_disp))
		info.add_child(_lbl(m.sub, 12, MUTED, f_light))
		var row := _hbox(6)
		var pill := _pill(m.diff, Color(Data.DIFF_COLORS[m.diff]), Color("#141630"), 10)
		row.add_child(pill)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)
		var bw: int = game.best.get(Data.best_key(m.id, _diff), 0)
		if bw >= 40:
			row.add_child(_pill("Cleared", GOLD, Color("#2b2200"), 10))
		row.add_child(_lbl("Best: wave %d" % bw if bw else "%d HP" % int(round(m.lives * Data.DIFFS[_diff].lives)), 12, MUTED, f_light))
		var rm := MarginContainer.new()
		rm.add_theme_constant_override("margin_top", 6)
		rm.add_child(row)
		info.add_child(rm)
		card.pressed.connect(_start_map.bind(m))
		_maps_grid.add_child(card)
	_menu.visible = true


func _menu_back() -> void:
	if _has_live_run():
		_menu.visible = false
	else:
		_show_title()


func _start_map(m: Dictionary, diff := "") -> void:
	game.new_game(m, diff if diff != "" else _diff)
	_after_map_loaded()
	_save_run()


func _after_map_loaded() -> void:
	var m: Dictionary = game.map
	stage.placing = ""
	stage.ghost = null
	stage.selected = null
	stage.refresh_bg()
	var mode := "" if game.diff == "normal" else " · %s mode" % Data.DIFFS[game.diff].name
	_mapname_lbl.text = ("%s · %s%s" % [m.name, m.diff, mode]).to_upper()
	_menu.visible = false
	_end.visible = false
	_render_shop()
	_render_info()
	_update_hud(true)


# ---------- end screen ----------
func _show_end(win: bool) -> void:
	if not win:
		_run = {}
	_save()
	_end.visible = true
	if win:
		_end_label.text = "MAP CLEARED"
		_end_title.text = "Team Rocket's blasting off again!"
		_end_text.text = "Ash's Pikachu is safe. You stopped all 40 waves on %s with %d HP left. Keep going in freeplay, where Team Rocket keeps sending tougher balls, or try a harder map." % [game.map.name, game.lives]
		_end_primary.text = "Keep playing (freeplay)"
	else:
		_end_label.text = "GAME OVER"
		_end_title.text = "Team Rocket caught Pikachu!"
		_end_text.text = "Jessie, James and Meowth got away at wave %d on %s. Spread your team along the path, evolve earlier, and bring something that can see Dusk Balls." % [game.wave, game.map.name]
		_end_primary.text = "Try again"
	_update_hud(true)


func _end_primary_pressed() -> void:
	if game.won and not game.freeplay:
		game.freeplay = true
		_end.visible = false
		_update_hud(true)
		_show_toast("Freeplay. The balls get tougher every wave.")
	else:
		_start_map(game.map, game.diff)


# ---------- toast / hud ----------
func _show_toast(msg: String) -> void:
	_toast_lbl.text = msg
	_toast.reset_size()
	await get_tree().process_frame
	_toast.reset_size()
	_toast.position = Vector2((Data.W - _toast.size.x) / 2, 12)
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, .15)
	_toast_tween.tween_interval(2.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, .25)


func _bump_money() -> void:
	if _money_tween:
		_money_tween.kill()
	_money_lbl.scale = Vector2.ONE
	_money_tween = create_tween()
	_money_tween.tween_property(_money_lbl, "scale", Vector2(1.3, 1.3), .16)
	_money_tween.tween_property(_money_lbl, "scale", Vector2.ONE, .39)


func _update_hud(force := false) -> void:
	if _sheet_pops and stage.selected:
		_sheet_pops.text = "%d pops" % stage.selected.pops
	var key := "%d|%d|%d|%s|%d|%s|%s" % [game.lives, game.money, game.wave, game.running, game.speed, game.paused, game.over]
	if not force and key == _hud_key:
		return
	_hud_key = key
	_lives_lbl.text = str(game.lives)
	_money_lbl.text = "₽%d" % game.money
	_wave_lbl.text = "%d/40" % game.wave
	_pause_menu.visible = game.paused and game.map != null and not game.over
	var nk := "%d|%s|%s|%s" % [game.wave, game.running, game.freeplay, game.map != null]
	if nk != _next_key:
		_next_key = nk
		_render_next()
	if game.running:
		_play_btn.text = "Wave %d in progress" % game.wave
		_play_btn.disabled = true
	elif game.wave == 40 and not game.freeplay:
		_play_btn.text = "Map cleared"
		_play_btn.disabled = true
	else:
		_play_btn.text = "Start wave %d" % (game.wave + 1)
		_play_btn.disabled = game.map == null or game.over
	_speed_btn.text = "%d×" % game.speed
	if game.speed > 1:
		_restyle_btn(_speed_btn, GOLD, Color("#2b2200"), GOLD)
	else:
		_restyle_btn(_speed_btn, PANEL2, TEXT, Color("#3a4280"))
	_pause_btn.text = "Resume" if game.paused else "Pause"
	if game.paused:
		_restyle_btn(_pause_btn, GOLD, Color("#2b2200"), GOLD)
	else:
		_restyle_btn(_pause_btn, PANEL2, TEXT, Color("#3a4280"))
	for k in _shop_buttons:
		var b: Button = _shop_buttons[k]
		var poor: bool = game.money < Data.TOWERS[k].cost
		b.disabled = poor or game.map == null or not _unlocked(k)
		b.modulate.a = .45 if b.disabled else 1.0
	for id in _item_buttons:
		var ib: Button = _item_buttons[id]
		var cost := game.item_cost(id)
		ib.text = "%s ₽%d" % [Data.ITEMS[id].short, cost]
		ib.tooltip_text = "%s: %s" % [Data.ITEMS[id].name, Data.ITEMS[id].desc]
		if id == "candy" and game.candy:
			ib.text = "Candy ready"
		ib.disabled = game.map == null or game.money < cost
	for w in _cost_widgets:
		var card: CardButton = w[0]
		var poor: bool = game.money < w[1]
		card.set_disabled(poor)
		var cost_lbl: Label = w[2]
		cost_lbl.add_theme_color_override("font_color", BAD if poor else GOLD)


func _process(dt: float) -> void:
	if not _menu.visible and not _title.visible and not _dex.visible:
		game.frame(dt)
	_hud_tick += dt
	if _hud_tick > .1:
		_hud_tick = 0
		_update_hud()


## Shows which balls the next wave (or the current one) brings.
func _render_next() -> void:
	_clear(_next_box)
	if game.map == null:
		return
	if game.wave == 40 and not game.freeplay and not game.running:
		_next_box.add_child(_caps("All 40 waves cleared", GOLD, 10))
		return
	var n := game.wave if game.running else game.wave + 1
	var cap := _caps(("Wave %d:" if game.running else "Next, wave %d:") % n, MUTED, 10)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_next_box.add_child(cap)
	var counts := {}
	var order: Array = []
	for g in Data.wave_groups(n):
		if not counts.has(g[0]):
			counts[g[0]] = 0
			order.append(g[0])
		counts[g[0]] += g[1]
	for t in order:
		var cell := _hbox(1)
		cell.tooltip_text = Data.BALLS[t].name
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.add_child(BallIcon.new(t))
		var cl := _lbl("×%d" % counts[t], 12, TEXT, f_bold)
		cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(cl)
		_next_box.add_child(cell)


func _use_item(id: String) -> void:
	var err := game.use_item(id)
	if err != "":
		_show_toast(err)
		return
	match id:
		"potion": _show_toast("Potion used. Pikachu feels better!")
		"repel": _show_toast("Max Repel! Every ball slows down for 5 seconds.")
		"candy": _show_toast("Rare Candy ready: your next upgrade is 30% off.")
	_render_sheet()
	_update_hud(true)


# ---------- shop ----------
func _render_shop() -> void:
	_clear(_shop_grid)
	_shop_buttons.clear()
	for i in Data.KINDS.size():
		var k: String = Data.KINDS[i]
		var d: Dictionary = Data.TOWERS[k]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 62)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var locked := not _unlocked(k)
		var key_txt := " (key %d)" % ((i + 1) % 10) if i < 10 else ""
		b.tooltip_text = "%s, %s type%s. %s: %s" % [d.name, d.type, key_txt, d.role, d.blurb]
		if locked:
			b.tooltip_text = _lock_text(k)
		var sel := stage.placing == k
		var n := _sb(PANEL2, 11, 0, 2, GOLD if sel else Color(0, 0, 0, 0))
		var h := _sb(Color("#363e78"), 11, 0, 2, GOLD if sel else Color(0, 0, 0, 0))
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", h)
		b.add_theme_stylebox_override("pressed", h)
		b.add_theme_stylebox_override("disabled", n)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var v := _vbox(0)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := MonIcon.new(Data.sprite_for(k, 0), 34, .62)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if locked:
			icon.modulate = Color(0, 0, 0, .55)
		v.add_child(icon)
		var nl := _lbl(d.name if not locked else "???", 10, TEXT, f_bold)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(nl)
		var cl := _lbl("₽%d" % d.cost if not locked else Data.unlock_short(k), 11, GOLD if not locked else MUTED, f_bold)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(cl)
		b.add_child(v)
		b.pressed.connect(_select_kind.bind(k))
		b.button_down.connect(_begin_drag.bind(k))
		_shop_grid.add_child(b)
		_shop_buttons[k] = b
	_update_hud(true)


func _select_kind(k: String) -> void:
	if game.map == null:
		return
	if not _unlocked(k):
		_show_toast(_lock_text(k).trim_prefix("Locked. "))
		return
	stage.placing = "" if stage.placing == k else k
	stage.selected = null
	stage.ghost = null
	stage.ghost_touch = false
	_render_shop()
	_render_info()
	if stage.placing != "":
		_show_toast("Place %s next to the path" % Data.TOWERS[k].name)


## Dragging a Pokémon from the Party onto the field places it where it's dropped.
func _begin_drag(k: String) -> void:
	if game.map == null or game.money < Data.TOWERS[k].cost or not _unlocked(k):
		return
	_drag_kind = k
	_drag_on_field = false
	_drag_start = get_global_mouse_position()


func _input(e: InputEvent) -> void:
	if _drag_kind == "":
		return
	if e is InputEventMouseMotion:
		var p := stage.get_local_mouse_position()
		var inside := Rect2(Vector2.ZERO, stage.size).has_point(p)
		if not _drag_on_field and inside and get_global_mouse_position().distance_to(_drag_start) > 16:
			_drag_on_field = true
			stage.placing = _drag_kind
			stage.selected = null
			stage.ghost_touch = false
			_render_info()
		if _drag_on_field:
			# lift the preview above a finger so it stays visible
			var lift := Vector2(0, -44) if e.device == InputEvent.DEVICE_ID_EMULATION else Vector2.ZERO
			stage.ghost = p + lift if inside else null
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		_drag_kind = ""
		if not _drag_on_field:
			return
		_drag_on_field = false
		if stage.ghost != null:
			_try_place(stage.ghost.x, stage.ghost.y, false)
		else:
			stage.placing = ""
			_render_info()
		_render_shop()


func _try_place(x: float, y: float, keep: bool) -> void:
	var k := stage.placing
	var d: Dictionary = Data.TOWERS[k]
	if game.money < d.cost:
		_show_toast("Need ₽%d more for %s" % [d.cost - game.money, d.name])
		return
	if not game.can_place(k, x, y):
		_show_toast("Can't place there. Keep off the path and obstacles.")
		return
	var tw := game.place_tower(k, x, y)
	_save_run()
	stage.ghost_touch = false
	if not keep or game.money < d.cost:
		stage.placing = ""
		stage.ghost = null
		stage.selected = tw
		_render_shop()
	_render_info()


func _on_tower_clicked(tw) -> void:
	stage.selected = tw
	_render_info()


# ---------- side info + upgrade overlay ----------
func _render_info() -> void:
	if stage.selected and not game.towers.has(stage.selected):
		stage.selected = null
	_render_side()
	_render_sheet()
	_update_hud(true)


func _render_side() -> void:
	_clear(_info_box)
	if stage.placing != "":
		var k := stage.placing
		var d: Dictionary = Data.TOWERS[k]
		var head := _hbox(10)
		head.add_child(MonIcon.new(Data.sprite_for(k, 0), 56, .9, INSET))
		var hv := _vbox(3)
		hv.add_child(_lbl(d.name, 18, TEXT, f_disp))
		var meta := _hbox(6)
		meta.add_child(_pill(d.type, Color(Data.TYPE_COLORS[d.type])))
		meta.add_child(_lbl("₽%d" % d.cost, 12, MUTED, f_light))
		hv.add_child(meta)
		head.add_child(hv)
		_info_box.add_child(head)
		_info_box.add_child(_lbl(d.blurb, 12.5, MUTED, f_light, true))
		var names := Data.path_names(k)
		var a_names: Array = d.A.map(func(u): return u.name.replace("Evolve: ", ""))
		var b_names: Array = d.B.map(func(u): return u.name)
		_info_box.add_child(_lbl("%s: %s. %s: %s." % [names[0], ", ".join(a_names), names[1], ", ".join(b_names)], 12.5, MUTED, f_light, true))
		_info_box.add_child(_lbl("Click the map to place it, or drag it there from the Party. Esc cancels.", 12.5, MUTED, f_light, true))
	else:
		_info_box.add_child(_lbl("Team Rocket's Pokéballs", 15, Color.WHITE, f_disp))
		_info_box.add_child(_lbl("Stronger balls have higher catch rates. Each hit knocks a ball down a tier until it pops.", 12.5, MUTED, f_light, true))
		var order: Array = Data.ORDER.duplicate()
		order.reverse()
		for t in order:
			var b: Dictionary = Data.BALLS[t]
			var row := _hbox(8)
			row.add_child(BallIcon.new(t))
			var tv := _vbox(0)
			tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tv.add_child(_lbl(b.name, 12.5, TEXT, f_bold))
			tv.add_child(_lbl(b.note, 11.5, MUTED, f_light, true))
			row.add_child(tv)
			var rl := _lbl(b.rate, 12, GOLD, f_bold)
			rl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(rl)
			_info_box.add_child(row)


func _stats_for(kind: String, s: Dictionary) -> Array:
	var sp := "%.1f/s" % (1.0 / s.rate) if s.rate else "None"
	return _stats_main(kind, s, sp) + [[s.range, "Range"]]


func _stats_main(kind: String, s: Dictionary, sp: String) -> Array:
	match kind:
		"pikachu": return [[s.dmg, "Damage"], [sp, "Speed"], [s.chain, "Chain"]]
		"charmander": return [[s.dmg, "Damage"], [sp, "Speed"], [s.pierce, "Hits"]]
		"squirtle": return [[s.dmg, "Damage"], [sp, "Speed"], [s.jets, "Jets"]]
		"bulbasaur": return [[s.dmg, "Damage"], [sp, "Speed"], [s.leaves, "Leaves"]]
		"gastly": return [[s.dmg, "Damage"], [sp, "Speed"], [s.radius, "Blast"]]
		"meowth": return [[s.dmg, "Damage"], [sp, "Speed"], ["₽%d" % s.pay, "Pay Day"]]
		"wobbuffet": return [[s.counter, "Damage"], ["%ss" % _num(s.confuse), "Confused"], ["%d%%" % int(round((1 - s.shadowTag) * 100)) if s.shadowTag else "0%", "Slow"]]
		"mewtwo": return [[s.dmg, "Damage"], [sp, "Speed"], [s.targets, "Targets"]]
		"magikarp": return [[s.dmg, "Damage"], [sp, "Speed"], [s.area if s.area else "-", "Blast"]]
		"pidgey": return [[s.dmg, "Damage"], [sp, "Speed"], [s.pierce, "Hits"]]
		"geodude": return [[s.dmg, "Damage"], [s.rocks, "Rocks"], [s.rockUses, "Rock hits"]]
		"machop": return [[s.dmg, "Damage"], [sp, "Speed"], [s.targets, "Targets"]]
		"abra": return [["+%d%%" % int(round((s.auraRate - 1) * 100)), "Aura speed"], ["+%d" % s.auraDmg, "Aura dmg"], [sp, "Speed"]]
		"lapras": return [[s.dmg, "Damage"], [sp, "Speed"], ["%ss" % _num(s.freeze), "Freeze"]]
		"snorlax": return [[int(s.hold), "Hold"], ["%ss" % _num(s.recover), "Nap"], [int(s.slamDmg) if s.slam else 0, "Slam"]]
		"dratini": return [[s.dmg, "Damage"], [sp, "Speed"], ["×%d" % int(s.bossMul), "Vs bosses"]]
	return []


func _num(v) -> String:
	if v is String:
		return v
	if is_equal_approx(float(v), round(float(v))):
		return str(int(round(float(v))))
	return str(v)


func _render_sheet() -> void:
	_cost_widgets.clear()
	_sheet_pops = null
	_clear(_sheet_box)
	var tw = stage.selected
	if not tw:
		_sheet.visible = false
		return
	var d: Dictionary = Data.TOWERS[tw.kind]
	var sp := Data.sprite_for(tw.kind, tw.a)
	var s: Dictionary = tw.s
	var names := Data.path_names(tw.kind)
	_sheet.position = Vector2(Data.W - 10 - 340 if tw.x < Data.W / 2 else 10.0, 10)
	_sheet.visible = true

	var head := _hbox(10)
	head.add_child(MonIcon.new(sp, 56, .9, INSET))
	var hv := _vbox(3)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(_lbl(Art.SPRITE_INFO[sp].name, 18, TEXT, f_disp, true))
	var meta := HFlowContainer.new()
	meta.add_theme_constant_override("h_separation", 6)
	meta.add_child(_pill(d.type, Color(Data.TYPE_COLORS[d.type])))
	_sheet_pops = _lbl("%d pops" % tw.pops, 12, MUTED, f_light)
	meta.add_child(_sheet_pops)
	if s.detect:
		meta.add_child(_lbl("· Sees Dusk Balls", 12, MUTED, f_light))
	hv.add_child(meta)
	head.add_child(hv)
	var x := _btn("×", PANEL2, TEXT, Color("#3a4280"), 8, 0)
	x.custom_minimum_size = Vector2(32, 32)
	x.add_theme_font_size_override("font_size", 20)
	x.tooltip_text = "Close"
	x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	x.pressed.connect(func(): stage.selected = null; _render_info())
	head.add_child(x)
	_sheet_box.add_child(head)

	var stats := _hbox(6)
	_stat_labels.clear()
	for st in _stats_for(tw.kind, tw.s):
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _sb(INSET, 8, 5))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pv := _vbox(0)
		var vl := _lbl(_num(st[0]), 14, TEXT, f_bold)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pv.add_child(vl)
		_stat_labels.append(vl)
		var ll := _caps(st[1], MUTED, 9)
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pv.add_child(ll)
		p.add_child(pv)
		stats.add_child(p)
	_sheet_box.add_child(stats)

	var up := _vbox(5)
	up.add_child(_caps("Next upgrades"))
	var cols := _hbox(8)
	for pi in 2:
		var pkey := "a" if pi == 0 else "b"
		var list: Array = d.A if pi == 0 else d.B
		var tier: int = tw.a if pi == 0 else tw.b
		var col := _vbox(6)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.custom_minimum_size.x = 140
		var ph := _hbox(4)
		var pn := _caps(names[pi])
		pn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ph.add_child(pn)
		for i in 3:
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(9, 9)
			pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pip.add_theme_stylebox_override("panel", _sb(GOLD if i < tier else INSET, 3, 0))
			pip.tooltip_text = list[i].name
			ph.add_child(pip)
		col.add_child(ph)
		var state: String = game.upgrade_state(tw, pkey)
		var card_n := _sb(PANEL2, 10, 8, 2, LINE)
		var card_h := _sb(PANEL2, 10, 8, 2, GREEN)
		var card := CardButton.new(card_n, card_h)
		card.custom_minimum_size.y = 96
		var cv := _vbox(3)
		card.add_child(cv)
		var cost_lbl: Label
		if state == "max":
			cv.add_child(_lbl("All learned", 13, TEXT, f_bold, true))
			cv.add_child(_lbl("This path is maxed out.", 11.5, MUTED, f_light, true))
			cost_lbl = _lbl("Max", 14, GOLD, f_bold)
		elif state == "locked":
			cv.add_child(_lbl(list[tier].name, 13, TEXT, f_bold, true))
			cv.add_child(_lbl("Locked. Only one path can reach tier 3.", 11.5, MUTED, f_light, true))
			cost_lbl = _lbl("Locked", 14, GOLD, f_bold)
		else:
			var u: Dictionary = list[tier]
			cv.add_child(_lbl(u.name, 13, TEXT, f_bold, true))
			var dl := _lbl(u.desc, 11.5, MUTED, f_light, true)
			dl.size_flags_vertical = Control.SIZE_EXPAND_FILL
			cv.add_child(dl)
			var uc := game.upgrade_cost(u.cost)
			cost_lbl = _lbl("₽%d%s" % [uc, "  (Rare Candy)" if uc != u.cost else ""], 14, GOLD, f_bold)
		cv.add_child(cost_lbl)
		if state != "open":
			card.set_disabled(true)
			card.modulate.a = .7
			card_n.border_color = Color(LINE, .7)
		else:
			card.pressed.connect(func(): game.upgrade(tw, pkey))
			card.mouse_entered.connect(_preview_upgrade.bind(tw, pkey))
			card.mouse_exited.connect(_preview_upgrade.bind(tw, ""))
			_cost_widgets.append([card, game.upgrade_cost(list[tier].cost), cost_lbl])
		col.add_child(card)
		cols.add_child(col)
	up.add_child(cols)
	_sheet_box.add_child(up)

	var learned := _vbox(6)
	learned.add_child(_caps("Learned"))
	var items: Array = []
	for i in tw.a:
		items.append([0, d.A[i]])
	for i in tw.b:
		items.append([1, d.B[i]])
	if items.is_empty():
		learned.add_child(_lbl("Nothing learned yet. Pick an upgrade below.", 12.5, MUTED, f_light, true))
	for it in items:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _sb(INSET, 8, 6))
		var rh := _hbox(8)
		var tag := _pill(names[it[0]], GOLD if it[0] == 0 else Color("#7fb6ff"), Color("#2b2200") if it[0] == 0 else Color("#0e2240"), 9, 5)
		tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		rh.add_child(tag)
		var rv := _vbox(1)
		rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rv.add_child(_lbl(it[1].name.replace("Evolve: ", ""), 12.5, TEXT, f_bold, true))
		rv.add_child(_lbl(it[1].desc, 11.5, MUTED, f_light, true))
		rh.add_child(rv)
		row.add_child(rh)
		learned.add_child(row)
	_sheet_box.add_child(learned)

	if tw.kind != "wobbuffet":
		var tg := _vbox(5)
		tg.add_child(_caps("Target"))
		var seg := PanelContainer.new()
		seg.add_theme_stylebox_override("panel", _sb(INSET, 9, 3))
		var sh := _hbox(3)
		for mode in ["first", "last", "strong", "close"]:
			var on: bool = tw.mode == mode
			var mb := _btn(mode.capitalize(), PANEL2 if on else Color(0, 0, 0, 0), Color.WHITE if on else MUTED, PANEL2, 7, 5)
			mb.add_theme_font_size_override("font_size", 12)
			mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mb.pressed.connect(func(): tw.mode = mode; _render_sheet())
			sh.add_child(mb)
		seg.add_child(sh)
		tg.add_child(seg)
		_sheet_box.add_child(tg)

	var sell := _btn("Release for ₽%d" % game.sell_value(tw), Color(0, 0, 0, 0), Color("#ffb3b3"), Color(0, 0, 0, 0), 10, 8)
	sell.add_theme_stylebox_override("normal", _sb(Color(0, 0, 0, 0), 10, 8, 2, LINE))
	sell.add_theme_stylebox_override("hover", _sb(Color(0, 0, 0, 0), 10, 8, 2, BAD))
	var release := func(): stage.selected = null; game.sell(tw)
	if _confirm_release:
		_two_tap(sell, "Tap again to release", release)
	else:
		sell.pressed.connect(release)
	_sheet_box.add_child(sell)
	_update_hud(true)


## While hovering an upgrade, the stat boxes show what it changes ("2 › 3").
func _preview_upgrade(tw, p: String) -> void:
	var cur := _stats_for(tw.kind, tw.s)
	var nxt := cur
	if p != "":
		nxt = _stats_for(tw.kind, game.stats_with_buffs(tw, tw.a + int(p == "a"), tw.b + int(p == "b")))
	for i in mini(_stat_labels.size(), cur.size()):
		var l: Label = _stat_labels[i]
		if not is_instance_valid(l):
			continue
		var before := _num(cur[i][0])
		var after := _num(nxt[i][0])
		if before == after:
			l.text = before
			l.add_theme_color_override("font_color", TEXT)
			l.add_theme_font_size_override("font_size", 14)
		else:
			l.text = "%s › %s" % [before, after]
			l.add_theme_color_override("font_color", GREEN)
			l.add_theme_font_size_override("font_size", 13)


# ---------- controls ----------
func _cycle_speed() -> void:
	game.speed = 2 if game.speed == 1 else (3 if game.speed == 2 else 1)
	_update_hud(true)


func _toggle_pause() -> void:
	if game.map == null or game.over:
		return
	game.paused = not game.paused
	_update_hud(true)


func _toggle_mute() -> void:
	sfx.muted = not sfx.muted
	_mute_btn.text = "Sound off" if sfx.muted else "Sound on"
	_save()


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var key: int = e.keycode
	if key == KEY_ESCAPE:
		_back()
		get_viewport().set_input_as_handled()
		return
	if _title.visible or _menu.visible or _end.visible or _settings.visible or _dex.visible:
		return
	match key:
		KEY_SPACE:
			game.start_wave()
			_update_hud(true)
		KEY_F:
			_cycle_speed()
		KEY_P:
			_toggle_pause()
		_:
			if key >= KEY_1 and key <= KEY_9:
				_select_kind(Data.KINDS[key - KEY_1])
			elif key == KEY_0:
				_select_kind(Data.KINDS[9])
	get_viewport().set_input_as_handled()


## Esc and the Android back button: close whatever is on top, otherwise pause.
func _back() -> void:
	if _settings.visible:
		_settings.visible = false
	elif _dex.visible:
		_dex.visible = false
	elif _title.visible or _end.visible:
		pass
	elif _menu.visible:
		_menu_back()
	elif stage.placing != "" or stage.selected:
		stage.placing = ""
		stage.ghost = null
		stage.selected = null
		_render_shop()
		_render_info()
	else:
		_toggle_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		# phone app sent to the background: save and pause the wave
		_save()
		if game.map and not game.over and not _title.visible:
			game.paused = true
			_update_hud(true)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
