class_name TrafficLights
extends Node3D
## Ampeln an allen Kreuzungen mit mindestens drei Zufahrten (21 Stück).
##
## Jede Kreuzung schaltet abwechselnd die Nord-Süd- und die Ost-West-Achse grün:
## GREEN_TIME grün, YELLOW_TIME gelb, ALL_RED_TIME alle rot. Kreuzungen sind zeitlich
## versetzt (grüne Welle ist nicht garantiert – das wäre der nächste Schritt).
## Darstellung: Masten, Gehäuse und Leuchten als je eine MultiMesh (3 Draw-Calls);
## die Leuchtfarbe wird nur beim Phasenwechsel aktualisiert.

const GREEN_TIME := 9.0
const YELLOW_TIME := 2.0
const ALL_RED_TIME := 1.0
const CYCLE := (GREEN_TIME + YELLOW_TIME + ALL_RED_TIME) * 2.0
const LIGHT_SHADER := preload("res://shaders/vehicle_lights.gdshader")
const COLORS := {"green": Color(0.15, 1.0, 0.35), "yellow": Color(1.0, 0.75, 0.1), "red": Color(1.0, 0.1, 0.06)}

var time := 0.0
var nodes: Array = []          # Array[Vector2i] Kreuzungen mit Ampel
var heads: Array = []          # [node, approach_dir, axis]
var _lamp_mm: MultiMesh
var _last_states: Dictionary = {}
var _lamp_mat: ShaderMaterial


## Kreuzungen mit Ampel: alle außer den vier Ecken.
static func has_light(n: Vector2i) -> bool:
	var m := CityLayout.ROAD_CENTERS.size() - 1
	var corner := (n.x == 0 or n.x == m) and (n.y == 0 or n.y == m)
	return TrafficManager.valid_node(n) and not corner


## Achse einer Fahrtrichtung: 0 = Ost-West, 1 = Nord-Süd.
static func axis_of(d: Vector2i) -> int:
	return 0 if d.x != 0 else 1


static func offset_for(n: Vector2i) -> float:
	return fmod(float(n.x * 7 + n.y * 13) * 2.3, CYCLE)


## Zustand für eine Achse an einer Kreuzung zur Zeit t: "green", "yellow" oder "red".
static func state_at(n: Vector2i, axis: int, t: float) -> String:
	if not has_light(n):
		return "green"
	var c := fposmod(t + offset_for(n), CYCLE)
	var half := CYCLE * 0.5
	var own_start := 0.0 if axis == 0 else half
	var local := fposmod(c - own_start, CYCLE)
	if local < GREEN_TIME:
		return "green"
	if local < GREEN_TIME + YELLOW_TIME:
		return "yellow"
	return "red"


func state(n: Vector2i, axis: int) -> String:
	return state_at(n, axis, time)


func build() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var m := CityLayout.ROAD_CENTERS.size()
	for x in m:
		for z in m:
			var n := Vector2i(x, z)
			if not has_light(n):
				continue
			nodes.append(n)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if TrafficManager.valid_node(n - d):
					heads.append([n, d, axis_of(d)])
	var pole_mm := _mm(_cyl(0.09, 4.2), heads.size())
	var box_mm := _mm(MeshFactory.box_mesh(Vector3(0.38, 1.0, 0.3)), heads.size())
	var lamp_mesh := MeshFactory.sphere_mesh(0.13, 8)
	_lamp_mm = _mm(lamp_mesh, heads.size())
	for i in heads.size():
		var n: Vector2i = heads[i][0]
		var d: Vector2i = heads[i][1]
		var base := _pole_pos(n, d)
		pole_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, base + Vector3(0, 2.1, 0)))
		pole_mm.set_instance_color(i, Color(0.2, 0.21, 0.22))
		var yaw := TrafficManager.yaw_for(-d)
		var face := Transform3D(Basis(Vector3.UP, yaw), base + Vector3(0, 3.7, 0))
		box_mm.set_instance_transform(i, face)
		box_mm.set_instance_color(i, Color(0.08, 0.08, 0.09))
		# Leuchte vorne am Gehäuse, Richtung ankommender Verkehr
		_lamp_mm.set_instance_transform(i, face.translated_local(Vector3(0, 0, -0.17)))
		_lamp_mm.set_instance_color(i, COLORS["red"])
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.12
		cyl.height = 4.2
		cs.shape = cyl
		cs.position = base + Vector3(0, 2.1, 0)
		body.add_child(cs)
	_add_mmi(pole_mm, MeshFactory.vertex_color_material(0.5, 0.5))
	_add_mmi(box_mm, MeshFactory.vertex_color_material(0.7, 0.1))
	_lamp_mat = ShaderMaterial.new()
	_lamp_mat.shader = LIGHT_SHADER
	_lamp_mat.set_shader_parameter("energy", 3.0)
	var lamps := _add_mmi(_lamp_mm, _lamp_mat)
	lamps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_refresh(true)


## Mast steht an der Ecke rechts vor der Kreuzung (aus Sicht des ankommenden Verkehrs).
static func _pole_pos(n: Vector2i, d: Vector2i) -> Vector3:
	var c := TrafficManager.node_pos(n)
	var r := TrafficManager.dir3(TrafficManager.right_of(d))
	return c - TrafficManager.dir3(d) * 7.8 + r * 7.8


func pole_positions() -> Array:
	var out: Array = []
	for h in heads:
		out.append(_pole_pos(h[0], h[1]))
	return out


func _process(delta: float) -> void:
	time += delta
	_refresh(false)


func _refresh(force: bool) -> void:
	for i in heads.size():
		var st := state(heads[i][0], heads[i][2])
		if force or _last_states.get(i, "") != st:
			_last_states[i] = st
			_lamp_mm.set_instance_color(i, COLORS[st])


func _cyl(r: float, h: float) -> CylinderMesh:
	return MeshFactory.cylinder_mesh(r, h, 6)


func _mm(mesh: Mesh, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	return mm


func _add_mmi(mm: MultiMesh, mat: Material) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	return mmi
