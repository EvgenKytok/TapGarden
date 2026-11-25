extends Control

const TILE_PATH := "res://assets/tile_%04d.png"
const PLOT_TILE := 13
const SCALE := 8.0 # было 4.0 -> стало в 2 раза больше

const PLANTS := {
	"Морква": {"tile": 6, "time": 6.0, "price": 5, "sell": 7},
	"Томат": {"tile": 42, "time": 9.0, "price": 25, "sell": 35},
	"Соняшник": {"tile": 83, "time": 13.0, "price": 50, "sell": 70},
}

var coins := 10
var speed_level := 1
var upgrade_price := 15
var selected := "Морква"
var plots: Array = []

var coins_label: Label
var selected_label: Label
var upgrade_btn: Button
var rhythm_bar: ProgressBar
var rhythm_value := 0.0
var rhythm_dir := 1.0
const RHYTHM_SPEED := 1.2

var goal_money: int = 2000
var win_done := false
var win_label: Label

var _tile_cache: Dictionary = {}


func _ready():
	_build_background()

	var plots_node := get_node_or_null("Plots")
	if plots_node:
		for marker in plots_node.get_children():
			_create_plot(marker.position)

	if plots.is_empty():
		_create_plot(Vector2(300, 250))
		_create_plot(Vector2(576, 350))
		_create_plot(Vector2(850, 250))

	_build_ui()
	_update_ui()


func _tex(n: int) -> Texture2D:
	if _tile_cache.has(n):
		return _tile_cache[n]

	var path := TILE_PATH % n
	var tex := load(path) if ResourceLoader.exists(path) else null

	if tex == null:
		push_warning("Немає тайла: " + path)
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.5, 0.3, 0.1))
		tex = ImageTexture.create_from_image(img)

	_tile_cache[n] = tex
	return tex


func _build_background():
	var tex := load("res://assets/background.png")
	if tex == null:
		push_error("Не загрузилась background.png по пути res://assets/background.png")
		return

	var bg := TextureRect.new()
	bg.texture = tex

	# на весь экран
	bg.anchor_left = 0.0
	bg.anchor_right = 1.0
	bg.anchor_top = 0.0
	bg.anchor_bottom = 1.0
	bg.offset_left = 0.0
	bg.offset_top = 0.0
	bg.offset_right = 0.0
	bg.offset_bottom = 0.0

	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.z_index = -1
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(bg)




func _create_plot(pos: Vector2):
	var plot := {}

	# Размер одной грядки (в 2 раза больше чем раньше)
	var cell_size := Vector2(16, 16) * SCALE
	var half := cell_size / 2.0

	# Грядка
	var bed := TextureRect.new()
	bed.texture = _tex(PLOT_TILE)
	bed.position = pos - half
	bed.size = cell_size
	bed.custom_minimum_size = cell_size
	bed.stretch_mode = TextureRect.STRETCH_SCALE
	bed.expand = true
	bed.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bed.z_index = 0
	add_child(bed)

	# Урожай
	var plant := TextureRect.new()
	plant.texture = null
	plant.position = pos - half
	plant.size = cell_size
	plant.custom_minimum_size = cell_size
	plant.stretch_mode = TextureRect.STRETCH_SCALE
	plant.expand = true
	plant.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plant.visible = false
	plant.z_index = 1
	plant.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plant)

	# Прогресс-бар
	var scale_ui := SCALE / 4.0

	var bar := ProgressBar.new()
	bar.size = Vector2(64, 12) * scale_ui
	bar.position = pos + Vector2(-(bar.size.x / 2.0), (cell_size.y / 2.0) - 2.0)
	bar.show_percentage = false
	bar.visible = false
	bar.z_index = 2
	add_child(bar)

	var pct := Label.new()
	pct.position = pos + Vector2(-20, (cell_size.y / 2.0) + 8.0)
	pct.visible = false
	pct.z_index = 3
	add_child(pct)

	# Кнопка
	var btn := Button.new()
	btn.flat = true
	btn.size = Vector2(64, 64) * scale_ui
	btn.position = pos - btn.size / 2.0
	btn.pressed.connect(_on_plot_pressed.bind(plot))
	btn.z_index = 10
	add_child(btn)

	plot["plant"] = plant
	plot["bar"] = bar
	plot["pct"] = pct
	plot["state"] = "empty"
	plot["progress"] = 0.0
	plot["time"] = 1.0
	plot["name"] = ""
	plots.append(plot)


func _on_plot_pressed(plot: Dictionary):
	if win_done:
		return

	match plot["state"]:
		"empty":
			_plant_seed(plot)
		"growing":
			var bonus := 0.4
			if _rhythm_hit():
				bonus = 1.2
			plot["progress"] += bonus
		"ready":
			_harvest(plot)

	_update_ui()


func _plant_seed(plot: Dictionary):
	var data = PLANTS[selected]
	if coins < data["price"]:
		return

	coins -= data["price"]
	plot["name"] = selected
	plot["time"] = data["time"]
	plot["progress"] = 0.0
	plot["state"] = "growing"

	plot["plant"].texture = _tex(data["tile"])
	plot["plant"].modulate = Color(1, 1, 1, 0.5)
	plot["plant"].visible = true

	plot["bar"].max_value = data["time"]
	plot["bar"].value = 0
	plot["bar"].visible = true
	plot["pct"].visible = true


func _harvest(plot: Dictionary):
	coins += PLANTS[plot["name"]]["sell"]

	plot["state"] = "empty"
	plot["name"] = ""
	plot["plant"].visible = false
	plot["plant"].texture = null
	plot["bar"].visible = false
	plot["pct"].visible = false


func _rhythm_hit() -> bool:
	return rhythm_value > 0.4 and rhythm_value < 0.6


func _process(delta):
	if win_done:
		return

	rhythm_value += rhythm_dir * RHYTHM_SPEED * delta
	if rhythm_value >= 1.0:
		rhythm_value = 1.0
		rhythm_dir = -1.0
	elif rhythm_value <= 0.0:
		rhythm_value = 0.0
		rhythm_dir = 1.0

	if rhythm_bar:
		rhythm_bar.value = rhythm_value
		rhythm_bar.modulate = Color(0.4, 1, 0.4) if _rhythm_hit() else Color(1, 1, 1)

	for plot in plots:
		if plot["state"] == "growing":
			plot["progress"] += delta * (1.0 + 0.3 * (speed_level - 1))
			plot["bar"].value = plot["progress"]
			plot["pct"].text = "%d%%" % int(min(plot["progress"] / plot["time"], 1.0) * 100)

			if plot["progress"] >= plot["time"]:
				plot["state"] = "ready"
				plot["plant"].modulate = Color(1, 1, 1, 1)
				plot["pct"].text = "Збирай!"

	_update_win()


func _build_ui():
	var ui := get_node_or_null("UI")
	if ui == null:
		ui = CanvasLayer.new()
		add_child(ui)

	coins_label = Label.new()
	coins_label.position = Vector2(20, 10)
	coins_label.add_theme_font_size_override("font_size", 24)
	ui.add_child(coins_label)

	selected_label = Label.new()
	selected_label.position = Vector2(20, 45)
	ui.add_child(selected_label)

	rhythm_bar = ProgressBar.new()
	rhythm_bar.max_value = 1.0
	rhythm_bar.size = Vector2(300, 20)
	rhythm_bar.position = Vector2(426, 20)
	rhythm_bar.show_percentage = false
	ui.add_child(rhythm_bar)

	var hint := Label.new()
	hint.text = "Тапай, коли шкала посередині!"
	hint.position = Vector2(446, 45)
	ui.add_child(hint)

	var box := HBoxContainer.new()
	box.position = Vector2(20, 590)
	ui.add_child(box)
	for n in PLANTS:
		var b := Button.new()
		b.text = "%s (%d)" % [n, PLANTS[n]["price"]]
		b.pressed.connect(_select_plant.bind(n))
		box.add_child(b)

	upgrade_btn = Button.new()
	upgrade_btn.position = Vector2(850, 590)
	upgrade_btn.pressed.connect(_on_upgrade)
	ui.add_child(upgrade_btn)

	win_label = Label.new()
	win_label.position = Vector2(520, 520)
	win_label.add_theme_font_size_override("font_size", 28)
	win_label.visible = false
	ui.add_child(win_label)


func _select_plant(n: String):
	if win_done:
		return
	selected = n
	_update_ui()


func _on_upgrade():
	if win_done:
		return
	if coins < upgrade_price:
		return

	coins -= upgrade_price
	speed_level += 1
	upgrade_price = int(upgrade_price * 1.8)
	_update_ui()


func _update_win():
	if win_done:
		return
	if coins >= goal_money:
		win_done = true
		win_label.text = "ПОБЕДА! Монети: %d / %d" % [coins, goal_money]
		win_label.visible = true


func _update_ui():
	if coins_label:
		coins_label.text = "Монети: %d" % coins
	if selected_label:
		selected_label.text = "Обрано: %s" % selected
	if upgrade_btn:
		upgrade_btn.text = "Покращити ріст (рів. %d) - %d" % [speed_level, upgrade_price]
	_update_win()
