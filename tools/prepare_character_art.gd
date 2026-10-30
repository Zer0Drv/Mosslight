extends SceneTree
## Offline, deterministic atlas preparation using Godot's image API only.
## Source sheets stay untouched. Run with --headless --path . --script this file.

const SOURCE_DIR := "res://assets/art/source/"
const OUTPUT_DIR := "res://assets/art/runtime/"
const FRAME_SIZE := Vector2i(32, 40)
const FOOT_ANCHOR := Vector2i(16, 36)
const GRID := Vector2i(4, 4)
const ROWS := ["down", "right", "left", "up"]
const PACKS := [
	{"name": "keeper_moss", "source": "keeper_moss_v1.png", "height": 26},
	{"name": "keeper_star", "source": "keeper_star_v1.png", "height": 30},
]


func _initialize() -> void:
	var result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if result != OK:
		_fail("Cannot create runtime art directory: %s" % error_string(result))
		return
	var records: Array[Dictionary] = []
	for pack: Dictionary in PACKS:
		var record := _prepare(pack)
		if record.is_empty():
			return
		records.append(record)
	var report := {
		"generator": "tools/prepare_character_art.gd",
		"method": "Godot Image crop + nearest-neighbor resize; source RGBA preserved",
		"frame_size": [FRAME_SIZE.x, FRAME_SIZE.y],
		"foot_anchor": [FOOT_ANCHOR.x, FOOT_ANCHOR.y],
		"rows": ROWS,
		"columns": ["idle_or_contact", "walk_1", "walk_2", "walk_3"],
		"packs": records,
	}
	var file := FileAccess.open(OUTPUT_DIR + "character_atlas_manifest.json", FileAccess.WRITE)
	if file == null:
		_fail("Cannot write character atlas manifest.")
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	print("CHARACTER ART PASS: 2 RGBA atlases, 16 frames each, 32x40 cells, foot anchor (16,36).")
	quit(0)


func _prepare(pack: Dictionary) -> Dictionary:
	var source := Image.load_from_file(SOURCE_DIR + String(pack.source))
	if source == null or source.is_empty():
		_fail("Cannot read source: " + String(pack.source))
		return {}
	source.convert(Image.FORMAT_RGBA8)
	print("Source %s: %dx%d" % [pack.source, source.get_width(), source.get_height()])
	var atlas := Image.create(FRAME_SIZE.x * GRID.x, FRAME_SIZE.y * GRID.y, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var frames: Array[Dictionary] = []
	for row in GRID.y:
		for column in GRID.x:
			# Image generation may emit a canvas a few pixels beyond the requested grid.
			# Partition by fractional cell boundaries, keeping all source pixels.
			var start := Vector2i(roundi(float(column) * source.get_width() / GRID.x), roundi(float(row) * source.get_height() / GRID.y))
			var end := Vector2i(roundi(float(column + 1) * source.get_width() / GRID.x), roundi(float(row + 1) * source.get_height() / GRID.y))
			var cell_rect := Rect2i(start, end - start)
			var cell := source.get_region(cell_rect)
			# Ignore only sub-visible alpha when finding bounds; copy original RGBA.
			var bounds := _opaque_bounds(cell, Rect2i(Vector2i.ZERO, cell_rect.size))
			if bounds.size.x == 0 or bounds.size.y == 0:
				_fail("Empty frame %s [%d,%d]" % [pack.name, column, row])
				return {}
			# The lower boot area centers the body, avoiding lantern/hat asymmetry.
			# Use only the lowest 10%; the star costume's lantern reaches below
			# the hem and must not pull the body anchor toward the lamp.
			var feet_height := maxi(2, roundi(bounds.size.y * 0.10))
			var feet := _opaque_bounds(cell, Rect2i(bounds.position.x, bounds.end.y - feet_height, bounds.size.x, feet_height))
			var foot_x := (float(feet.position.x + feet.end.x) * 0.5) - bounds.position.x
			var sprite := cell.get_region(bounds)
			var target_height := int(pack.height)
			var scale := float(target_height) / bounds.size.y
			var target_width := maxi(1, roundi(bounds.size.x * scale))
			if target_width > FRAME_SIZE.x - 2:
				_fail("Frame exceeds atlas width: " + String(pack.name))
				return {}
			sprite.resize(target_width, target_height, Image.INTERPOLATE_NEAREST)
			var offset := Vector2i(FOOT_ANCHOR.x - roundi(foot_x * float(target_width) / bounds.size.x), FOOT_ANCHOR.y - target_height)
			if offset.x < 0 or offset.x + target_width > FRAME_SIZE.x:
				_fail("Frame anchor would crop pixels: " + String(pack.name))
				return {}
			atlas.blit_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), Vector2i(column, row) * FRAME_SIZE + offset)
			frames.append({
				"column": column, "row": row, "direction": ROWS[row],
				"source_bounds": [cell_rect.position.x + bounds.position.x, cell_rect.position.y + bounds.position.y, bounds.size.x, bounds.size.y],
				"runtime_rect": [offset.x, offset.y, target_width, target_height],
			})
	var output_path := OUTPUT_DIR + String(pack.name) + ".png"
	var save_error := atlas.save_png(output_path)
	if save_error != OK:
		_fail("Cannot save " + output_path + ": " + error_string(save_error))
		return {}
	print("Prepared %s: %dx%d source -> %dx%d RGBA atlas." % [pack.name, source.get_width(), source.get_height(), atlas.get_width(), atlas.get_height()])
	return {"name": pack.name, "source": SOURCE_DIR + String(pack.source), "output": output_path, "source_size": [source.get_width(), source.get_height()], "frames": frames}


func _opaque_bounds(image: Image, area: Rect2i) -> Rect2i:
	var minimum := area.end
	var maximum := area.position - Vector2i.ONE
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if image.get_pixel(x, y).a > 0.08:
				minimum.x = mini(minimum.x, x)
				minimum.y = mini(minimum.y, y)
				maximum.x = maxi(maximum.x, x)
				maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _fail(message: String) -> void:
	printerr("CHARACTER ART FAIL: " + message)
	quit(1)
