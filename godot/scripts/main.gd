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
	func _init() -> void:
		custom_minimum_size = Vector2(30, 30)

	func _draw() -> void:
		var c := size / 2
		draw_circle(c, 17, Color("#9c2329"))
		draw_circle(c, 15, Color.WHITE)
		draw_circle(c, 12, Color("#1c6aa8"))
		draw_circle(c, 9.5, Color("#3aa7e8"))
		draw_circle(c - Vector2(3, 3), 3.5, Color("#bfe9ff"))


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
	game.toast.connect(_show_toast)
	game.sfx.connect(func(f, d, ty, v): sfx.blip(f, d, ty, v))
	game.ended.connect(_show_end)
	game.info_changed.connect(_render_info)
	game.money_bump.connect(_bump_money)
	_build()
	_render_shop()
	_render_info()
	_open_menu()
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


func _load_save() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		_best = cf.get_value("save", "best", {})
		_muted = cf.get_value("save", "muted", false)


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("save", "best", game.best)
	cf.set_value("save", "muted", sfx.muted)
	cf.save(SAVE_PATH)


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
	var maps_btn := _btn("Maps", INSET, TEXT, Color("#1c2045"), 9, 7)
	maps_btn.add_theme_font_size_override("font_size", 12)
	maps_btn.pressed.connect(_open_menu)
	hrow.add_child(maps_btn)

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

	_build_menu()
	_build_end()


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
	var help := _lbl("Keys: 1 to 8 pick a Pokémon, Space starts a wave, F changes speed, Esc cancels. On a touch screen, tap a spot to preview and tap it again to place.", 12.5, MUTED, f_light, true)
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


# ---------- menu ----------
func _open_menu() -> void:
	_clear(_maps_grid)
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
		var bw: int = game.best.get(m.id, 0)
		row.add_child(_lbl("Best: wave %d" % bw if bw else "%d lives" % m.lives, 12, MUTED, f_light))
		var rm := MarginContainer.new()
		rm.add_theme_constant_override("margin_top", 6)
		rm.add_child(row)
		info.add_child(rm)
		card.pressed.connect(_start_map.bind(m))
		_maps_grid.add_child(card)
	_menu.visible = true


func _start_map(m: Dictionary) -> void:
	game.new_game(m)
	stage.placing = ""
	stage.ghost = null
	stage.selected = null
	stage.refresh_bg()
	_mapname_lbl.text = ("%s · %s" % [m.name, m.diff]).to_upper()
	_menu.visible = false
	_end.visible = false
	_render_shop()
	_render_info()
	_update_hud(true)


# ---------- end screen ----------
func _show_end(win: bool) -> void:
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
		_start_map(game.map)


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
		b.disabled = poor or game.map == null
		b.modulate.a = .45 if b.disabled else 1.0
	for w in _cost_widgets:
		var card: CardButton = w[0]
		var poor: bool = game.money < w[1]
		card.set_disabled(poor)
		var cost_lbl: Label = w[2]
		cost_lbl.add_theme_color_override("font_color", BAD if poor else GOLD)


func _process(dt: float) -> void:
	if not _menu.visible:
		game.frame(dt)
	_hud_tick += dt
	if _hud_tick > .1:
		_hud_tick = 0
		_update_hud()


# ---------- shop ----------
func _render_shop() -> void:
	_clear(_shop_grid)
	_shop_buttons.clear()
	for i in Data.KINDS.size():
		var k: String = Data.KINDS[i]
		var d: Dictionary = Data.TOWERS[k]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 80)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "%s, %s type (key %d): %s" % [d.name, d.type, i + 1, d.blurb]
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
		var icon := MonIcon.new(Data.sprite_for(k, 0), 44, .8)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(icon)
		var nl := _lbl(d.name, 11, TEXT, f_bold)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(nl)
		var cl := _lbl("₽%d" % d.cost, 12.5, GOLD, f_bold)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(cl)
		b.add_child(v)
		b.pressed.connect(_select_kind.bind(k))
		_shop_grid.add_child(b)
		_shop_buttons[k] = b
	_update_hud(true)


func _select_kind(k: String) -> void:
	if game.map == null:
		return
	stage.placing = "" if stage.placing == k else k
	stage.selected = null
	stage.ghost = null
	stage.ghost_touch = false
	_render_shop()
	_render_info()
	if stage.placing != "":
		_show_toast("Place %s next to the path" % Data.TOWERS[k].name)


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
		_info_box.add_child(_lbl("Click the map to place it. Esc cancels.", 12.5, MUTED, f_light, true))
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


func _stats_for(tw) -> Array:
	var s: Dictionary = tw.s
	var sp := "%.1f/s" % (1.0 / s.rate) if s.rate else "None"
	match tw.kind:
		"pikachu": return [[s.dmg, "Damage"], [sp, "Speed"], [s.chain, "Chain"]]
		"charmander": return [[s.dmg, "Damage"], [sp, "Speed"], [s.pierce, "Hits"]]
		"squirtle": return [[s.dmg, "Damage"], [sp, "Speed"], [s.jets, "Jets"]]
		"bulbasaur": return [[s.dmg, "Damage"], [sp, "Speed"], [s.leaves, "Leaves"]]
		"gastly": return [[s.dmg, "Damage"], [sp, "Speed"], [s.radius, "Blast"]]
		"meowth": return [[s.dmg, "Damage"], [sp, "Speed"], ["₽%d" % s.pay, "Pay Day"]]
		"wobbuffet": return [[s.counter, "Damage"], ["%ss" % _num(s.confuse), "Confused"], ["%d%%" % int(round((1 - s.shadowTag) * 100)) if s.shadowTag else "0%", "Slow"]]
		"mewtwo": return [[s.dmg, "Damage"], [sp, "Speed"], [s.targets, "Targets"]]
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
	for st in _stats_for(tw):
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _sb(INSET, 8, 5))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pv := _vbox(0)
		var vl := _lbl(_num(st[0]), 14, TEXT, f_bold)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pv.add_child(vl)
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
			cost_lbl = _lbl("₽%d" % u.cost, 14, GOLD, f_bold)
		cv.add_child(cost_lbl)
		if state != "open":
			card.set_disabled(true)
			card.modulate.a = .7
			card_n.border_color = Color(LINE, .7)
		else:
			card.pressed.connect(func(): game.upgrade(tw, pkey))
			_cost_widgets.append([card, list[tier].cost, cost_lbl])
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
	sell.pressed.connect(func(): stage.selected = null; game.sell(tw))
	_sheet_box.add_child(sell)
	_update_hud(true)


# ---------- controls ----------
func _cycle_speed() -> void:
	game.speed = 2 if game.speed == 1 else (3 if game.speed == 2 else 1)
	_update_hud(true)


func _toggle_pause() -> void:
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
	if _menu.visible or _end.visible:
		if key == KEY_ESCAPE and game.map and _menu.visible:
			_menu.visible = false
		return
	match key:
		KEY_ESCAPE:
			stage.placing = ""
			stage.ghost = null
			stage.selected = null
			_render_shop()
			_render_info()
		KEY_SPACE:
			game.start_wave()
			_update_hud(true)
		KEY_F:
			_cycle_speed()
		KEY_P:
			_toggle_pause()
		_:
			if key >= KEY_1 and key <= KEY_8:
				_select_kind(Data.KINDS[key - KEY_1])
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		# phone app sent to the background: save and pause the wave
		_save()
		if game.map and not game.over:
			game.paused = true
			_update_hud(true)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android back button: close what's open, otherwise show the map picker
		if _end.visible:
			return
		if stage.placing != "" or stage.selected:
			stage.placing = ""
			stage.ghost = null
			stage.selected = null
			_render_shop()
			_render_info()
		elif _menu.visible:
			if game.map:
				_menu.visible = false
		else:
			_open_menu()
