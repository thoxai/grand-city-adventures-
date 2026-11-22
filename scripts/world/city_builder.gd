class_name CityBuilder
extends Node3D
## Erzeugt das komplette Stadtviertel prozedural (deterministisch per Seed).
##
## Mobile-Optimierung: Alle Gebaeude teilen sich EINE MultiMesh (ein Draw-Call),
## ebenso Requisiten, Baeume und Laternen. Kollisionen liegen gesammelt in
## einem einzigen StaticBody3D.

const SEED := 20261122
const BUILDING_SHADER := preload("res://shaders/building.gdshader")
const GROUND_SHADER := preload("res://shaders/ground.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")
const PAVING_SHADER := preload("res://shaders/paving.gdshader")

const RESIDENTIAL_COLORS := [
	Color(0.78, 0.70, 0.58), Color(0.66, 0.42, 0.33), Color(0.72, 0.74, 0.72),
	Color(0.85, 0.80, 0.68), Color(0.55, 0.58, 0.62), Color(0.62, 0.50, 0.40),
	Color(0.80, 0.62, 0.48), Color(0.58, 0.64, 0.58),
]
const DOWNTOWN_COLORS := [
	Color(0.42, 0.50, 0.58), Color(0.30, 0.33, 0.37), Color(0.70, 0.68, 0.62),
	Color(0.48, 0.55, 0.60), Color(0.60, 0.62, 0.66),
]
const INDUSTRIAL_COLORS := [
	Color(0.45, 0.50, 0.48), Color(0.38, 0.45, 0.55), Color(0.55, 0.52, 0.46), Color(0.62, 0.62, 0.60),
]
const CONTAINER_COLORS := [
	Color(0.65, 0.18, 0.12), Color(0.12, 0.32, 0.55), Color(0.85, 0.55, 0.10),
	Color(0.20, 0.45, 0.30), Color(0.55, 0.55, 0.58),
]

var rng := RandomNumberGenerator.new()
var building_material: ShaderMaterial
var ground_material: ShaderMaterial
var lamp_material: StandardMaterial3D
var beacon_material: StandardMaterial3D

## Gesammelte Daten (auch fuer Tests und Minikarte)
var solid_boxes: Array = []          # Array[AABB] aller begehbaren Hindernisse
var solid_cylinders: Array = []      # Array[Vector4(x, z, radius, height)]
var minimap_rects: Array = []        # Array[[Rect2, Color]]
var lamp_positions: Array = []       # Array[Vector3] Leuchtenkopf-Positionen
var building_count := 0

var _buildings: Array = []           # [Transform3D, Color]
var _props: Array = []               # [Transform3D, Color]
var _trees: Array = []               # [Vector3, float scale, Color]
var _collision_body: StaticBody3D
var _built := false


func build() -> void:
	if _built:
		return
	_built = true
	rng.seed = SEED
	_collision_body = StaticBody3D.new()
	_collision_body.name = "WorldCollision"
	_collision_body.collision_layer = 1
	_collision_body.collision_mask = 0
	add_child(_collision_body)
	_create_materials()
	_build_ground()
	for iz in CityLayout.block_count():
		for ix in CityLayout.block_count():
			_build_block(ix, iz)
	_build_street_furniture()
	_build_mission_props()
	_build_boundary()
	_build_skyline()
	_commit_multimeshes()
	building_count = _buildings.size()


# ------------------------------------------------------------------ Materialien

func _create_materials() -> void:
	building_material = ShaderMaterial.new()
	building_material.shader = BUILDING_SHADER
	ground_material = ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER
	lamp_material = StandardMaterial3D.new()
	lamp_material.albedo_color = Color(1.0, 0.92, 0.75)
	lamp_material.emission_enabled = true
	lamp_material.emission = Color(1.0, 0.82, 0.55)
	lamp_material.emission_energy_multiplier = 0.2
	beacon_material = StandardMaterial3D.new()
	beacon_material.albedo_color = Color(0.9, 0.1, 0.1)
	beacon_material.emission_enabled = true
	beacon_material.emission = Color(1.0, 0.1, 0.05)
	beacon_material.emission_energy_multiplier = 3.0


func _paving(color: Color, tile: float, rough: float = 0.85) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PAVING_SHADER
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("tile_size", tile)
	m.set_shader_parameter("roughness_value", rough)
	return m


func _vertex_color_material(roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = roughness
	m.metallic = metallic
	return m


# ------------------------------------------------------------------ Boden

func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var pm := PlaneMesh.new()
	pm.size = Vector2(1200, 1200)
	ground.mesh = pm
	ground.material_override = ground_material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	var shape := CollisionShape3D.new()
	var ws := WorldBoundaryShape3D.new()
	shape.shape = ws
	_collision_body.add_child(shape)


# ------------------------------------------------------------------ Bausteine

func add_building(rect: Rect2, height: float, color: Color, solid: bool = true) -> void:
	var center := Vector3(rect.get_center().x, height * 0.5, rect.get_center().y)
	var basis := Basis.from_scale(Vector3(rect.size.x, height, rect.size.y))
	var c := color
	c.a = rng.randf()
	_buildings.append([Transform3D(basis, center), c])
	if solid:
		_add_solid_box(center, Vector3(rect.size.x, height, rect.size.y))
		minimap_rects.append([rect, color.darkened(0.35)])
	# Dachaufbauten (Technik, Treppenhaus) – rein optisch
	if solid and height > 9.0 and rect.size.x > 8.0 and rect.size.y > 8.0:
		var n := rng.randi_range(1, 3)
		for i in n:
			var s := Vector3(rng.randf_range(2.0, 4.5), rng.randf_range(1.2, 3.0), rng.randf_range(2.0, 4.5))
			var px := rng.randf_range(rect.position.x + s.x, rect.end.x - s.x)
			var pz := rng.randf_range(rect.position.y + s.z, rect.end.y - s.z)
			add_prop(Vector3(px, height + s.y * 0.5, pz), s, Color(0.5, 0.5, 0.52), false)


func add_prop(center: Vector3, size: Vector3, color: Color, solid: bool, rot_y: float = 0.0) -> void:
	var basis := Basis(Vector3.UP, rot_y) * Basis.from_scale(size)
	_props.append([Transform3D(basis, center), color])
	if solid:
		_add_solid_box(center, size, rot_y)


func add_tree(pos: Vector3, scale: float = 1.0) -> void:
	var hue := rng.randf_range(0.22, 0.32)
	var col := Color.from_hsv(hue, rng.randf_range(0.45, 0.65), rng.randf_range(0.28, 0.42))
	_trees.append([pos, scale, col])
	_add_solid_cylinder(pos, 0.28 * scale, 3.0)


func _add_solid_box(center: Vector3, size: Vector3, rot_y: float = 0.0) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = Transform3D(Basis(Vector3.UP, rot_y), center)
	_collision_body.add_child(cs)
	if is_zero_approx(rot_y):
		solid_boxes.append(AABB(center - size * 0.5, size))
	else:
		var r := maxf(size.x, size.z) * 0.5
		solid_boxes.append(AABB(center - Vector3(r, size.y * 0.5, r), Vector3(r * 2, size.y, r * 2)))


func _add_solid_cylinder(pos: Vector3, radius: float, height: float) -> void:
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	cs.shape = cyl
	cs.position = pos + Vector3(0, height * 0.5, 0)
	_collision_body.add_child(cs)
	solid_cylinders.append(Vector4(pos.x, pos.z, radius, height))


func _label(text: String, pos: Vector3, rot_y: float, size: int = 96, color: Color = Color.WHITE) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = color
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.position = pos
	l.rotation.y = rot_y
	l.shaded = false
	add_child(l)


## Prueft, ob ein Punkt (XZ) frei von Hindernissen ist.
func is_point_free(p: Vector3, margin: float = 0.5) -> bool:
	for box in solid_boxes:
		var b: AABB = box
		if p.x > b.position.x - margin and p.x < b.end.x + margin and p.z > b.position.z - margin and p.z < b.end.z + margin:
			return false
	for c in solid_cylinders:
		if Vector2(p.x, p.z).distance_to(Vector2(c.x, c.y)) < c.z + margin:
			return false
	return true


# ------------------------------------------------------------------ Bloecke

func _build_block(ix: int, iz: int) -> void:
	var lot := CityLayout.lot_rect(ix, iz)
	match CityLayout.block_type(ix, iz):
		"residential":
			_gen_residential(lot)
		"downtown":
			_gen_downtown(lot)
		"industrial":
			if ix == 0 and iz == 0:
				_gen_radio_compound(lot)
			else:
				_gen_industrial(lot)
		"park":
			_gen_park(lot)
		"workshop":
			_gen_workshop(lot)
		"plaza":
			_gen_plaza(lot)
		"harbor":
			_gen_harbor(lot)


func _gen_residential(lot: Rect2) -> void:
	var cells := 3
	var cell := lot.size / cells
	var gap := 3.2
	for cz in cells:
		for cx in cells:
			if cx == 1 and cz == 1:
				continue  # Innenhof
			var r := Rect2(lot.position + Vector2(cx, cz) * cell, cell).grow(-gap * 0.5)
			var h := snappedf(rng.randf_range(10.0, 24.0), 3.2) + 0.6
			add_building(r, h, RESIDENTIAL_COLORS[rng.randi() % RESIDENTIAL_COLORS.size()])
	# Innenhof mit Baeumen und Baenken
	var c := lot.get_center()
	for i in 4:
		var ang := TAU * i / 4.0 + PI / 4.0
		add_tree(Vector3(c.x + cos(ang) * 6.5, 0, c.y + sin(ang) * 6.5), rng.randf_range(0.9, 1.2))
	add_prop(Vector3(c.x, 0.25, c.y - 3.0), Vector3(1.8, 0.5, 0.5), Color(0.35, 0.25, 0.18), false)
	add_prop(Vector3(c.x, 0.25, c.y + 3.0), Vector3(1.8, 0.5, 0.5), Color(0.35, 0.25, 0.18), false)
	minimap_rects.append([Rect2(c - Vector2(9, 9), Vector2(18, 18)), Color(0.25, 0.36, 0.24)])


func _gen_downtown(lot: Rect2) -> void:
	var cell := lot.size / 2.0
	for cz in 2:
		for cx in 2:
			var r := Rect2(lot.position + Vector2(cx, cz) * cell, cell).grow(-3.0)
			var h := snappedf(rng.randf_range(32.0, 72.0), 3.2) + 0.6
			var col: Color = DOWNTOWN_COLORS[rng.randi() % DOWNTOWN_COLORS.size()]
			# Sockelgeschoss + Turm
			add_building(r, 7.0, col.darkened(0.15))
			var tower := r.grow(-rng.randf_range(1.5, 4.0))
			add_building(tower, h, col)


func _gen_industrial(lot: Rect2) -> void:
	var half_w := (lot.size.x - 6.0) * 0.5
	for i in 2:
		var r := Rect2(lot.position.x + i * (half_w + 6.0), lot.position.y + 2.0, half_w, lot.size.y - 18.0)
		add_building(r, rng.randf_range(8.0, 12.0), INDUSTRIAL_COLORS[rng.randi() % INDUSTRIAL_COLORS.size()])
	# Paletten und Kisten im Hof
	for i in 8:
		var p := Vector3(rng.randf_range(lot.position.x + 3, lot.end.x - 3), 0, lot.end.y - rng.randf_range(3.0, 10.0))
		if absf(p.x - lot.get_center().x) < 4.0:
			continue
		var s := Vector3(1.2, rng.randf_range(0.8, 1.6), 1.2)
		add_prop(p + Vector3(0, s.y * 0.5, 0), s, Color(0.55, 0.42, 0.26), true)


func _gen_radio_compound(lot: Rect2) -> void:
	# Zaun mit Tor an der Suedseite (Richtung Strasse z = -90)
	var fence_col := Color(0.4, 0.42, 0.44)
	var gate_x := CityLayout.poi("radio_gate").x
	var y := 1.1
	var x0 := lot.position.x
	var x1 := lot.end.x
	var z0 := lot.position.y
	var z1 := lot.end.y
	add_prop(Vector3((x0 + gate_x - 4.0) * 0.5, y, z1), Vector3(gate_x - 4.0 - x0, 2.2, 0.15), fence_col, true)
	add_prop(Vector3((gate_x + 4.0 + x1) * 0.5, y, z1), Vector3(x1 - gate_x - 4.0, 2.2, 0.15), fence_col, true)
	add_prop(Vector3((x0 + x1) * 0.5, y, z0), Vector3(x1 - x0, 2.2, 0.15), fence_col, true)
	add_prop(Vector3(x0, y, (z0 + z1) * 0.5), Vector3(0.15, 2.2, z1 - z0), fence_col, true)
	add_prop(Vector3(x1, y, (z0 + z1) * 0.5), Vector3(0.15, 2.2, z1 - z0), fence_col, true)
	# Funkturm
	var tower_pos := Vector3(CityLayout.poi("radio_tower").x, 0, lot.get_center().y - 5.0)
	add_prop(tower_pos + Vector3(0, 0.5, 0), Vector3(6, 1, 6), Color(0.5, 0.5, 0.5), true)
	var mast := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.35
	cm.bottom_radius = 2.2
	cm.height = 46.0
	cm.radial_segments = 6
	cm.rings = 1
	mast.mesh = cm
	mast.material_override = MeshFactory.material(Color(0.75, 0.32, 0.22), 0.6, 0.4)
	mast.position = tower_pos + Vector3(0, 24.0, 0)
	mast.name = "RadioMast"
	add_child(mast)
	for k in 3:
		MeshFactory.box(Vector3(3.5 - k * 0.8, 0.25, 3.5 - k * 0.8), MeshFactory.material(Color(0.8, 0.8, 0.8), 0.6, 0.5), tower_pos + Vector3(0, 14 + k * 11, 0), self)
	var beacon := MeshFactory.sphere(0.5, beacon_material, tower_pos + Vector3(0, 47.5, 0), self, 8)
	beacon.name = "RadioBeacon"
	# Schaltschrank fuer das Raetsel
	var ctrl := CityLayout.poi("radio_tower") + Vector3(0, 0, -3.5)
	add_prop(ctrl + Vector3(0, 0.8, 0), Vector3(1.4, 1.6, 0.6), Color(0.2, 0.35, 0.5), true)
	# Kleines Betriebsgebaeude
	add_building(Rect2(lot.position.x + 6, lot.end.y - 16, 12, 9), 4.2, INDUSTRIAL_COLORS[0])
	_label("FUNKTURM NORD", Vector3(gate_x, 3.2, z1 + 0.2), 0.0, 64)


func _gen_park(lot: Rect2) -> void:
	var grass := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = lot.size
	grass.mesh = pm
	grass.material_override = MeshFactory.material(Color(0.24, 0.36, 0.17), 1.0)
	grass.position = Vector3(lot.get_center().x, 0.03, lot.get_center().y)
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)
	var c := lot.get_center()
	var path_mat := _paving(Color(0.62, 0.57, 0.48), 0.9, 0.95)
	var p1 := MeshFactory.box(Vector3(4.0, 0.02, lot.size.y), path_mat, Vector3(c.x, 0.05, c.y), self)
	p1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var p2 := MeshFactory.box(Vector3(lot.size.x, 0.02, 4.0), path_mat, Vector3(c.x, 0.05, c.y), self)
	p2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Brunnen
	var stone := MeshFactory.material(Color(0.68, 0.66, 0.62), 0.7)
	MeshFactory.cylinder(4.0, 0.6, stone, Vector3(c.x, 0.3, c.y), self, 24)
	var water := ShaderMaterial.new()
	water.shader = WATER_SHADER
	MeshFactory.cylinder(3.7, 0.05, water, Vector3(c.x, 0.58, c.y), self, 24)
	MeshFactory.cylinder(0.5, 2.2, stone, Vector3(c.x, 1.1, c.y), self, 10)
	MeshFactory.sphere(0.8, stone, Vector3(c.x, 2.3, c.y), self, 10)
	_add_solid_cylinder(Vector3(c.x, 0, c.y), 4.1, 0.7)
	minimap_rects.append([lot, Color(0.22, 0.38, 0.2)])
	# Baeume (nicht auf Wegen, nicht am Brunnen, nicht an wichtigen Orten)
	var reserved := [CityLayout.poi("jonas"), CityLayout.COLLECTIBLES[1]]
	var placed := 0
	var tries := 0
	while placed < 34 and tries < 400:
		tries += 1
		var p := Vector3(rng.randf_range(lot.position.x + 2, lot.end.x - 2), 0, rng.randf_range(lot.position.y + 2, lot.end.y - 2))
		if absf(p.x - c.x) < 4.5 or absf(p.z - c.y) < 4.5:
			continue
		var ok := true
		for r in reserved:
			if p.distance_to(r) < 4.0:
				ok = false
		for t in _trees:
			if p.distance_to(t[0]) < 5.0:
				ok = false
		if ok:
			add_tree(p, rng.randf_range(0.9, 1.5))
			placed += 1
	# Baenke entlang der Wege
	for k in [-20.0, -10.0, 10.0, 20.0]:
		add_prop(Vector3(c.x + 3.0, 0.25, c.y + k), Vector3(0.5, 0.5, 1.8), Color(0.35, 0.25, 0.18), false)
		add_prop(Vector3(c.x + k, 0.25, c.y - 3.0), Vector3(1.8, 0.5, 0.5), Color(0.35, 0.25, 0.18), false)
	_label("LINDENPARK", Vector3(c.x, 2.6, lot.end.y + 0.5), 0.0, 72, Color(0.85, 1.0, 0.85))


func _gen_workshop(lot: Rect2) -> void:
	var asphalt := _paving(Color(0.16, 0.16, 0.17), 4.0, 0.8)
	var fc := MeshFactory.box(Vector3(lot.size.x, 0.02, lot.size.y), asphalt, Vector3(lot.get_center().x, 0.03, lot.get_center().y), self)
	fc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Werkstatthalle (Ostseite) mit Tor nach Westen
	var hall := Rect2(lot.position.x + 41.0, lot.position.y + 9.0, lot.size.x - 41.0, 50.0)
	add_building(hall, 7.5, Color(0.36, 0.40, 0.46))
	var door_x := hall.position.x - 0.05
	add_prop(Vector3(door_x, 2.4, CityLayout.poi("garage_tuning").z), Vector3(0.1, 4.6, 8.0), Color(0.08, 0.08, 0.09), false)
	add_prop(Vector3(door_x - 0.3, 5.4, CityLayout.poi("garage_tuning").z), Vector3(0.6, 0.6, 10.0), Color(0.9, 0.45, 0.1), false)
	_label("KENJIS WERKSTATT", Vector3(door_x - 0.4, 6.4, CityLayout.poi("garage_tuning").z), -PI / 2.0, 110, Color(1.0, 0.75, 0.35))
	# Nebengebaeude
	add_building(Rect2(lot.position.x, lot.position.y, 30.0, 10.0), 9.8, RESIDENTIAL_COLORS[4])
	add_building(Rect2(lot.position.x, lot.end.y - 10.0, 34.0, 10.0), 6.6, RESIDENTIAL_COLORS[2])
	# Reifenstapel und Werkzeugwagen
	for i in 5:
		add_prop(Vector3(hall.position.x - 1.2, 0.5, hall.position.y + 2.0 + i * 1.3), Vector3(0.9, 1.0, 0.9), Color(0.07, 0.07, 0.07), true)
	add_prop(Vector3(hall.position.x - 1.2, 0.55, hall.end.y - 3.0), Vector3(1.0, 1.1, 0.6), Color(0.75, 0.1, 0.1), true)
	minimap_rects.append([Rect2(lot.position.x, lot.position.y + 10.0, 41.0, lot.size.y - 20.0), Color(0.18, 0.18, 0.2)])


func _gen_plaza(lot: Rect2) -> void:
	var paving := _paving(Color(0.66, 0.6, 0.52), 1.4, 0.8)
	var pv := MeshFactory.box(Vector3(lot.size.x, 0.02, lot.size.y), paving, Vector3(lot.get_center().x, 0.03, lot.get_center().y), self)
	pv.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hall_rect := Rect2(lot.position.x + 9.0, lot.end.y - 24.0, 50.0, 24.0)
	var sand := Color(0.80, 0.72, 0.58)
	add_building(hall_rect, 16.6, sand)
	# Uhrturm
	var cx := hall_rect.get_center().x
	add_building(Rect2(cx - 3.0, hall_rect.get_center().y - 3.0, 6.0, 6.0), 26.0, sand.darkened(0.08), false)
	MeshFactory.cylinder(1.6, 0.2, MeshFactory.material(Color(0.95, 0.93, 0.85), 0.4, 0.0, Color(1, 0.95, 0.8), 0.6), Vector3(cx, 22.0, hall_rect.get_center().y - 3.1), self, 20).rotation.x = PI / 2.0
	# Saeulen vor dem Eingang
	var front_z := hall_rect.position.y - 1.6
	var x := hall_rect.position.x + 3.0
	while x < hall_rect.end.x - 2.0:
		if absf(x - cx) > 4.0:
			add_prop(Vector3(x, 4.0, front_z), Vector3(0.9, 8.0, 0.9), sand.lightened(0.1), true)
		x += 6.0
	add_prop(Vector3(cx, 8.3, front_z), Vector3(hall_rect.size.x - 2.0, 0.8, 2.4), sand.lightened(0.05), false)
	# Treppenstufen
	add_prop(Vector3(cx, 0.12, front_z + 0.4), Vector3(14.0, 0.24, 2.0), sand.darkened(0.1), false)
	_label("RATHAUS", Vector3(cx, 9.4, front_z - 1.25), PI, 120, Color(0.2, 0.15, 0.1))
	# Denkmal
	var stone := MeshFactory.material(Color(0.5, 0.5, 0.5), 0.6, 0.2)
	var mon := Vector3(cx, 0, lot.position.y + 14.0)
	MeshFactory.box(Vector3(2.2, 1.2, 2.2), stone, mon + Vector3(0, 0.6, 0), self)
	MeshFactory.capsule(0.35, 2.0, MeshFactory.material(Color(0.32, 0.42, 0.38), 0.4, 0.8), mon + Vector3(0, 2.2, 0), self)
	_add_solid_box(mon + Vector3(0, 1.0, 0), Vector3(2.4, 2.0, 2.4))
	# Baumreihen
	for k in 6:
		add_tree(Vector3(lot.position.x + 4.0, 0, lot.position.y + 6.0 + k * 9.0), 1.0)
		add_tree(Vector3(lot.end.x - 4.0, 0, lot.position.y + 6.0 + k * 9.0), 1.0)
	minimap_rects.append([Rect2(lot.position, Vector2(lot.size.x, lot.size.y - 24.0)), Color(0.42, 0.40, 0.36)])


func _gen_harbor(lot: Rect2) -> void:
	add_building(Rect2(lot.position.x, lot.position.y, 29.0, 24.0), 10.0, INDUSTRIAL_COLORS[1])
	add_building(Rect2(lot.end.x - 29.0, lot.position.y, 29.0, 24.0), 12.0, INDUSTRIAL_COLORS[2])
	# Containerstapel
	for row in 3:
		for col in 2:
			var stack := rng.randi_range(1, 3)
			for s in stack:
				var pos := Vector3(lot.position.x + 5.0 + col * 13.0, 1.3 + s * 2.6, lot.position.y + 40.0 + row * 8.0)
				add_prop(pos, Vector3(12.0, 2.6, 2.5), CONTAINER_COLORS[rng.randi() % CONTAINER_COLORS.size()], s == 0)
	# Kran (optisch)
	var crane_col := Color(0.9, 0.65, 0.1)
	var cbase := Vector3(lot.end.x - 14.0, 0, lot.end.y - 14.0)
	for dx in [-3.0, 3.0]:
		add_prop(cbase + Vector3(dx, 9.0, 0), Vector3(0.8, 18.0, 0.8), crane_col, true)
	add_prop(cbase + Vector3(0, 18.4, 6.0), Vector3(1.2, 1.2, 26.0), crane_col, false)
	_label("ALTER HAFEN", Vector3(lot.get_center().x, 8.5, lot.position.y - 0.2), PI, 96)


# ------------------------------------------------------------------ Strassenmoebel

func _build_street_furniture() -> void:
	for iz in CityLayout.block_count():
		for ix in CityLayout.block_count():
			var r := CityLayout.block_rect(ix, iz)
			var t := CityLayout.block_type(ix, iz)
			# Laternen an allen vier Seiten
			var inset := 0.8
			var step := 25.0
			var x := r.position.x + 6.0
			while x < r.end.x - 4.0:
				_add_lamp(Vector3(x, 0, r.position.y + inset), 0.0)
				_add_lamp(Vector3(x + 12.0, 0, r.end.y - inset), PI)
				x += step
			var z := r.position.y + 12.0
			while z < r.end.y - 4.0:
				_add_lamp(Vector3(r.position.x + inset, 0, z), PI / 2.0)
				_add_lamp(Vector3(r.end.x - inset, 0, z + 6.0), -PI / 2.0)
				z += step
			# Strassenbaeume in Wohngebieten
			if t == "residential" or t == "plaza":
				var tx := r.position.x + 18.0
				while tx < r.end.x - 10.0:
					add_tree(Vector3(tx, 0, r.position.y + 3.3), 0.8)
					add_tree(Vector3(tx - 6.0, 0, r.end.y - 3.3), 0.8)
					tx += 24.0


func _add_lamp(pos: Vector3, rot_y: float) -> void:
	for p in CityLayout.POIS.values():
		if Vector2(p.x, p.z).distance_to(Vector2(pos.x, pos.z)) < 2.5:
			return
	lamp_positions.append(pos + Vector3(0, 5.6, 0))
	_add_solid_cylinder(pos, 0.12, 5.8)


func _build_mission_props() -> void:
	# Stromverteilerkaesten fuer Mission 3 (stehen hinter dem Markierungspunkt)
	for key in ["fusebox_a", "fusebox_b"]:
		var p := CityLayout.poi(key)
		var dir := 1.0 if p.z > 0.0 else -1.0
		var box_pos := p + Vector3(0, 0.75, 1.7 * dir)
		add_prop(box_pos, Vector3(1.3, 1.5, 0.5), Color(0.55, 0.6, 0.55), true)
		add_prop(box_pos + Vector3(0, 0.3, -0.26 * dir), Vector3(0.5, 0.35, 0.03), Color(0.95, 0.8, 0.1), false)


# ------------------------------------------------------------------ Rand & Skyline

func _build_boundary() -> void:
	var h := CityLayout.HALF_SIZE
	for d in [Vector3(h + 0.5, 6, 0), Vector3(-h - 0.5, 6, 0)]:
		_add_solid_box(d, Vector3(1.0, 12.0, h * 2 + 2))
	for d in [Vector3(0, 6, h + 0.5), Vector3(0, 6, -h - 0.5)]:
		_add_solid_box(d, Vector3(h * 2 + 2, 12.0, 1.0))
	# Gelaender sichtbar am Rand
	var rail := Color(0.3, 0.32, 0.34)
	add_prop(Vector3(0, 0.55, h - 0.3), Vector3(h * 2, 0.08, 0.08), rail, false)
	add_prop(Vector3(0, 1.0, h - 0.3), Vector3(h * 2, 0.08, 0.08), rail, false)
	add_prop(Vector3(0, 1.0, -h + 0.3), Vector3(h * 2, 2.0, 0.1), Color(0.25, 0.27, 0.3), false)
	add_prop(Vector3(h - 0.3, 1.0, 0), Vector3(0.1, 2.0, h * 2), Color(0.25, 0.27, 0.3), false)
	add_prop(Vector3(-h + 0.3, 1.0, 0), Vector3(0.1, 2.0, h * 2), Color(0.25, 0.27, 0.3), false)
	# Kaimauer und Wasser im Sueden
	add_prop(Vector3(0, -0.7, h + 1.5), Vector3(h * 2 + 40, 1.6, 3.0), Color(0.4, 0.38, 0.35), false)
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1200, 400)
	water.mesh = pm
	var wm := ShaderMaterial.new()
	wm.shader = WATER_SHADER
	water.material_override = wm
	water.position = Vector3(0, -1.2, h + 203)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _build_skyline() -> void:
	# Nicht begehbare Kulisse rund um das Viertel (Norden, Osten, Westen)
	var h := CityLayout.HALF_SIZE
	var pos := -h - 60.0
	while pos < h + 60.0:
		var w := rng.randf_range(14.0, 26.0)
		for side in 3:
			var depth := rng.randf_range(14.0, 30.0)
			var height := rng.randf_range(18.0, 85.0)
			var off := rng.randf_range(12.0, 40.0)
			var r: Rect2
			match side:
				0:
					r = Rect2(pos, -h - off - depth, w, depth)
				1:
					r = Rect2(h + off, pos, depth, w)
				2:
					r = Rect2(-h - off - depth, pos, depth, w)
			var palette := DOWNTOWN_COLORS if rng.randf() < 0.5 else RESIDENTIAL_COLORS
			add_building(r, height, palette[rng.randi() % palette.size()], false)
		pos += w + rng.randf_range(2.0, 8.0)
	# Gegenueberliegendes Ufer
	var x := -500.0
	while x < 500.0:
		var w2 := rng.randf_range(20.0, 40.0)
		add_building(Rect2(x, h + 330.0, w2, 25.0), rng.randf_range(15.0, 70.0), DOWNTOWN_COLORS[rng.randi() % DOWNTOWN_COLORS.size()], false)
		x += w2 + rng.randf_range(4.0, 15.0)


# ------------------------------------------------------------------ MultiMeshes

func _commit_multimeshes() -> void:
	var unit_box := BoxMesh.new()
	# Gebaeude
	var bmm := _make_multimesh(unit_box, _buildings.size())
	for i in _buildings.size():
		bmm.set_instance_transform(i, _buildings[i][0])
		bmm.set_instance_color(i, _buildings[i][1])
	_add_mmi("Buildings", bmm, building_material)
	# Requisiten
	var pmm := _make_multimesh(unit_box, _props.size())
	for i in _props.size():
		pmm.set_instance_transform(i, _props[i][0])
		pmm.set_instance_color(i, _props[i][1])
	_add_mmi("Props", pmm, _vertex_color_material(0.75, 0.1))
	# Baeume: Stamm + zwei Kronen-Ebenen
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.26
	trunk_mesh.height = 3.0
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1
	var tmm := _make_multimesh(trunk_mesh, _trees.size())
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.0
	crown_mesh.height = 2.0
	crown_mesh.radial_segments = 8
	crown_mesh.rings = 5
	var cmm := _make_multimesh(crown_mesh, _trees.size() * 2)
	for i in _trees.size():
		var p: Vector3 = _trees[i][0]
		var s: float = _trees[i][1]
		var col: Color = _trees[i][2]
		tmm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s, s)), p + Vector3(0, 1.5 * s, 0)))
		tmm.set_instance_color(i, Color(0.28, 0.2, 0.14))
		var rot := Basis(Vector3.UP, rng.randf() * TAU)
		cmm.set_instance_transform(i * 2, Transform3D(rot * Basis.from_scale(Vector3(2.3, 1.9, 2.3) * s), p + Vector3(0, 4.0 * s, 0)))
		cmm.set_instance_color(i * 2, col)
		cmm.set_instance_transform(i * 2 + 1, Transform3D(rot * Basis.from_scale(Vector3(1.6, 1.4, 1.6) * s), p + Vector3(0.5 * s, 5.4 * s, 0.3 * s)))
		cmm.set_instance_color(i * 2 + 1, col.lightened(0.12))
	_add_mmi("TreeTrunks", tmm, _vertex_color_material(0.95))
	_add_mmi("TreeCrowns", cmm, _vertex_color_material(0.9))
	# Laternen
	var pole := CylinderMesh.new()
	pole.top_radius = 0.07
	pole.bottom_radius = 0.11
	pole.height = 5.8
	pole.radial_segments = 6
	pole.rings = 1
	var lmm := _make_multimesh(pole, lamp_positions.size())
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.55, 0.18, 0.55)
	var hmm := _make_multimesh(head_mesh, lamp_positions.size())
	for i in lamp_positions.size():
		var hp: Vector3 = lamp_positions[i]
		lmm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(hp.x, 2.9, hp.z)))
		lmm.set_instance_color(i, Color(0.22, 0.23, 0.25))
		hmm.set_instance_transform(i, Transform3D(Basis.IDENTITY, hp + Vector3(0, 0.1, 0)))
		hmm.set_instance_color(i, Color.WHITE)
	_add_mmi("LampPoles", lmm, _vertex_color_material(0.5, 0.6))
	var heads := _add_mmi("LampHeads", hmm, lamp_material)
	heads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _make_multimesh(mesh: Mesh, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	return mm


func _add_mmi(node_name: String, mm: MultiMesh, mat: Material) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	return mmi
