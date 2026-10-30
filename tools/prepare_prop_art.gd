extends SceneTree
## Deterministic engine import preparation: crop reviewed sprite regions, fit with
## nearest-neighbor sampling, and align the original alpha into runtime canvases.
const ROOT := "res://assets/art/"
var records: Array[Dictionary] = []


func _initialize() -> void:
	var garden := Image.load_from_file(ROOT + "source/garden_v1.png")
	var woodland := Image.load_from_file(ROOT + "source/woodland_v1.png")
	if garden == null or woodland == null:
		printerr("Missing source artwork.")
		quit(1)
		return
	var moss_rects := [Rect2i(88,192,112,81), Rect2i(318,158,212,124), Rect2i(582,114,311,176), Rect2i(918,88,321,216)]
	var moss_sizes := [Vector2i(4,3), Vector2i(7,4), Vector2i(11,6), Vector2i(14,8)]
	var bell_rects := [Rect2i(88,542,121,80), Rect2i(336,447,169,175), Rect2i(594,389,262,241), Rect2i(913,358,314,281)]
	var bell_sizes := [Vector2i(5,4), Vector2i(7,8), Vector2i(11,12), Vector2i(14,14)]
	for i in 4:
		_prepare(garden, "garden_v1.png", "moon_moss_%d" % i, moss_rects[i], Vector2i(16,16), moss_sizes[i], Vector2i(8,12))
		_prepare(garden, "garden_v1.png", "glow_bell_%d" % i, bell_rects[i], Vector2i(16,16), bell_sizes[i], Vector2i(8,14))
	var lamp_rects := [Rect2i(41,653,247,319), Rect2i(349,652,248,320), Rect2i(656,652,251,320)]
	var lamp_names := ["broken", "off", "on"]
	for i in 3:
		_prepare(garden, "garden_v1.png", "lantern_" + lamp_names[i], lamp_rects[i], Vector2i(32,48), Vector2i(28,38), Vector2i(16,42))
	_prepare(garden, "garden_v1.png", "spore_pouch", Rect2i(983,786,232,190), Vector2i(24,24), Vector2i(22,20), Vector2i(12,22))
	var icon_rects := [Rect2i(99,1059,129,127),Rect2i(380,1043,172,148),Rect2i(664,1004,215,211),Rect2i(995,1004,212,219)]
	var icon_names := ["dew","spores","seed_moon","seed_bell"]
	for i in 4:
		_prepare(garden, "garden_v1.png", "icon_" + icon_names[i], icon_rects[i], Vector2i(16,16), Vector2i(14,14), Vector2i(8,15))
	_prepare(woodland, "woodland_v1.png", "cottage", Rect2i(34,157,652,577), Vector2i(128,112), Vector2i(122,108), Vector2i(64,110))
	_prepare(woodland, "woodland_v1.png", "tree", Rect2i(685,123,555,632), Vector2i(112,128), Vector2i(100,114), Vector2i(56,120))
	_prepare(woodland, "woodland_v1.png", "stump", Rect2i(73,875,536,302), Vector2i(40,32), Vector2i(34,24), Vector2i(20,28))
	_prepare(woodland, "woodland_v1.png", "mushroom_fern", Rect2i(730,851,449,330), Vector2i(32,28), Vector2i(28,22), Vector2i(16,25))
	var file := FileAccess.open(ROOT + "runtime/prop_manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"generator":"tools/prepare_prop_art.gd","method":"Reviewed crop rectangles, aspect-preserving nearest-neighbor fit, original RGBA","assets":records}, "  ") + "\n")
	print("PROP ART PASS: %d RGBA runtime sprites." % records.size())
	quit(0)


func _prepare(source: Image, source_name: String, name: String, region: Rect2i, canvas_size: Vector2i, maximum: Vector2i, anchor: Vector2i) -> void:
	var sprite := source.get_region(region)
	var factor := minf(float(maximum.x) / region.size.x, float(maximum.y) / region.size.y)
	var size := Vector2i(maxi(1,roundi(region.size.x*factor)),maxi(1,roundi(region.size.y*factor)))
	sprite.resize(size.x,size.y,Image.INTERPOLATE_NEAREST)
	var canvas := Image.create(canvas_size.x,canvas_size.y,false,Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	var offset := Vector2i(anchor.x - size.x / 2,anchor.y - size.y)
	canvas.blit_rect(sprite,Rect2i(Vector2i.ZERO,size),offset)
	var path := ROOT + "runtime/" + name + ".png"
	var error := canvas.save_png(path)
	if error != OK:
		printerr("Could not save " + path)
		quit(1)
		return
	records.append({"id":name,"source":source_name,"source_region":[region.position.x,region.position.y,region.size.x,region.size.y],"file":name+".png","size":[canvas_size.x,canvas_size.y],"anchor":[anchor.x,anchor.y],"content_rect":[offset.x,offset.y,size.x,size.y]})
