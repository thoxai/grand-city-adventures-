class_name HumanoidModel
extends Node3D
## Prozedural aufgebaute Figur mit realistischen Proportionen (ca. 1,70 m)
## und einfacher Lauf-/Idle-Animation ueber Gelenk-Pivots.
## Dient als eigenes Platzhalter-Asset, bis echte Modelle (GLB) vorliegen.
## Fernansicht: Ab 40 m wird nur noch eine einzelne Silhouette gezeichnet.

const DETAIL_RANGE := 35.0
const FAR_RANGE := 140.0

var params: Dictionary = {}
var _hip_l: Node3D
var _hip_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _shoulder_l: Node3D
var _shoulder_r: Node3D
var _elbow_l: Node3D
var _elbow_r: Node3D
var _torso: Node3D
var _head: Node3D
var _phase := 0.0
var _wave := 0.0
var waving := false


static func preset(id: String) -> Dictionary:
	match id:
		"alex":
			return {"skin": Color(0.87, 0.70, 0.58), "hair": Color(0.16, 0.11, 0.08), "hair_style": "short",
				"top": Color(0.16, 0.36, 0.42), "top_style": "hoodie", "pants": Color(0.18, 0.24, 0.36),
				"shoes": Color(0.92, 0.92, 0.9), "height": 1.72, "build": 1.0, "accent": Color(0.95, 0.55, 0.15)}
		"mia":
			return {"skin": Color(0.78, 0.58, 0.45), "hair": Color(0.35, 0.16, 0.09), "hair_style": "ponytail",
				"top": Color(0.52, 0.14, 0.2), "top_style": "jacket", "pants": Color(0.12, 0.12, 0.15),
				"shoes": Color(0.3, 0.3, 0.32), "height": 1.66, "build": 0.92, "accent": Color(0.9, 0.85, 0.75)}
	return {}


func build(p: Dictionary) -> void:
	params = p
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var skin: Color = p.get("skin", Color(0.8, 0.65, 0.5))
	var hair: Color = p.get("hair", Color(0.15, 0.1, 0.08))
	var top: Color = p.get("top", Color(0.3, 0.3, 0.35))
	var pants: Color = p.get("pants", Color(0.2, 0.22, 0.3))
	var shoes: Color = p.get("shoes", Color(0.9, 0.9, 0.9))
	var accent: Color = p.get("accent", Color(0.9, 0.5, 0.1))
	var eye := Color(0.06, 0.05, 0.05)
	var style: String = p.get("top_style", "")
	var h: float = p.get("height", 1.72) / 1.72
	var w: float = p.get("build", 1.0)
	var mat := MeshFactory.vertex_color_material(0.8)

	var detail := Node3D.new()
	detail.name = "Detail"
	add_child(detail)
	var root := Node3D.new()
	root.scale = Vector3(h, h, h)
	detail.add_child(root)

	# Beine mit Knie-Gelenk (je Gelenk ein zusammengefasstes Mesh)
	_hip_l = _limb_pivot(root, Vector3(-0.095 * w, 0.92, 0))
	_hip_r = _limb_pivot(root, Vector3(0.095 * w, 0.92, 0))
	for hip in [_hip_l, _hip_r]:
		var thigh := MeshFactory.Batch.new()
		thigh.add(MeshFactory.capsule_mesh(0.075 * w, 0.48), _t(Vector3(0, -0.23, 0)), pants)
		_emit(thigh, hip, mat, true)
		var knee := _limb_pivot(hip, Vector3(0, -0.46, 0))
		var shin := MeshFactory.Batch.new()
		shin.add(MeshFactory.capsule_mesh(0.06 * w, 0.46), _t(Vector3(0, -0.21, 0)), pants)
		shin.add(MeshFactory.box_mesh(Vector3(0.1, 0.08, 0.27)), _t(Vector3(0, -0.42, -0.045)), shoes)
		shin.add(MeshFactory.box_mesh(Vector3(0.102, 0.025, 0.272)), _t(Vector3(0, -0.452, -0.045)), shoes.darkened(0.35))
		_emit(shin, knee, mat, true)
		if hip == _hip_l:
			_knee_l = knee
		else:
			_knee_r = knee

	# Rumpf
	_torso = Node3D.new()
	_torso.position = Vector3(0, 0.95, 0)
	root.add_child(_torso)
	var body := MeshFactory.Batch.new()
	body.add(MeshFactory.capsule_mesh(0.15, 0.3), _t(Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1.15 * w, 0.8, 0.75)), pants)
	body.add(MeshFactory.box_mesh(Vector3(0.3 * w, 0.04, 0.2)), _t(Vector3(0, 0.12, 0)), pants.darkened(0.4))
	body.add(MeshFactory.capsule_mesh(0.17, 0.58, 12), _t(Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1.12 * w, 1.0, 0.72)), top)
	if style == "hoodie":
		body.add(MeshFactory.sphere_mesh(0.11), _t(Vector3(0, 0.57, 0.085), Vector3(-0.3, 0, 0), Vector3(1.15, 0.45, 0.75)), top.darkened(0.08))
		body.add(MeshFactory.box_mesh(Vector3(0.02, 0.18, 0.01)), _t(Vector3(-0.04, 0.42, -0.125)), accent)
		body.add(MeshFactory.box_mesh(Vector3(0.02, 0.18, 0.01)), _t(Vector3(0.04, 0.42, -0.125)), accent)
		body.add(MeshFactory.box_mesh(Vector3(0.22 * w, 0.1, 0.02)), _t(Vector3(0, 0.15, -0.118)), top.darkened(0.12))
	elif style == "jacket":
		body.add(MeshFactory.box_mesh(Vector3(0.07, 0.42, 0.01)), _t(Vector3(0, 0.32, -0.123)), accent)
		body.add(MeshFactory.cylinder_mesh(0.08, 0.06, 10), _t(Vector3(0, 0.6, 0), Vector3.ZERO, Vector3(1.2, 1, 1)), top)
		body.add(MeshFactory.box_mesh(Vector3(0.012, 0.44, 0.012)), _t(Vector3(0.05, 0.32, -0.124)), top.darkened(0.3))
	else:
		body.add(MeshFactory.box_mesh(Vector3(0.1, 0.06, 0.012)), _t(Vector3(-0.06, 0.45, -0.123)), accent)
	body.add(MeshFactory.cylinder_mesh(0.045, 0.1, 8), _t(Vector3(0, 0.64, 0)), skin)
	_emit(body, _torso, mat, true)

	# Kopf
	_head = Node3D.new()
	_head.position = Vector3(0, 0.78, 0)
	_torso.add_child(_head)
	var head := MeshFactory.Batch.new()
	head.add(MeshFactory.sphere_mesh(0.112, 14), _t(Vector3.ZERO, Vector3.ZERO, Vector3(0.9, 1.08, 0.98)), skin)
	head.add(MeshFactory.sphere_mesh(0.07, 10), _t(Vector3(0, -0.06, -0.035), Vector3.ZERO, Vector3(1.05, 0.8, 1.0)), skin)
	head.add(MeshFactory.sphere_mesh(0.016, 6), _t(Vector3(-0.038, 0.015, -0.098)), eye)
	head.add(MeshFactory.sphere_mesh(0.016, 6), _t(Vector3(0.038, 0.015, -0.098)), eye)
	head.add(MeshFactory.box_mesh(Vector3(0.035, 0.008, 0.01)), _t(Vector3(-0.038, 0.042, -0.1)), hair.darkened(0.2))
	head.add(MeshFactory.box_mesh(Vector3(0.035, 0.008, 0.01)), _t(Vector3(0.038, 0.042, -0.1)), hair.darkened(0.2))
	head.add(MeshFactory.box_mesh(Vector3(0.022, 0.04, 0.03)), _t(Vector3(0, -0.015, -0.108), Vector3(0.25, 0, 0)), skin.darkened(0.05))
	head.add(MeshFactory.box_mesh(Vector3(0.04, 0.008, 0.01)), _t(Vector3(0, -0.058, -0.1)), skin.darkened(0.3))
	head.add(MeshFactory.sphere_mesh(0.022, 6), _t(Vector3(-0.1, 0.0, 0.0)), skin)
	head.add(MeshFactory.sphere_mesh(0.022, 6), _t(Vector3(0.1, 0.0, 0.0)), skin)
	head.add(MeshFactory.sphere_mesh(0.118, 14), _t(Vector3(0, 0.035, 0.012), Vector3.ZERO, Vector3(0.95, 0.9, 1.02)), hair)
	match p.get("hair_style", "short"):
		"ponytail":
			head.add(MeshFactory.sphere_mesh(0.05, 8), _t(Vector3(0, 0.06, 0.11), Vector3.ZERO, Vector3(1, 1, 0.8)), hair)
			head.add(MeshFactory.capsule_mesh(0.042, 0.26), _t(Vector3(0, -0.06, 0.15), Vector3(0.35, 0, 0)), hair)
		"bun":
			head.add(MeshFactory.sphere_mesh(0.06, 8), _t(Vector3(0, 0.12, 0.06)), hair)
		"cap":
			head.add(MeshFactory.sphere_mesh(0.122, 12), _t(Vector3(0, 0.05, 0.0), Vector3.ZERO, Vector3(0.98, 0.7, 1.0)), accent)
			head.add(MeshFactory.box_mesh(Vector3(0.16, 0.012, 0.1)), _t(Vector3(0, 0.035, -0.13)), accent)
		_:
			head.add(MeshFactory.box_mesh(Vector3(0.17, 0.05, 0.05)), _t(Vector3(0, 0.075, -0.085), Vector3(-0.3, 0, 0)), hair)
	_emit(head, _head, mat, false)

	# Arme
	_shoulder_l = _limb_pivot(_torso, Vector3(-0.21 * w, 0.52, 0))
	_shoulder_r = _limb_pivot(_torso, Vector3(0.21 * w, 0.52, 0))
	for sh in [_shoulder_l, _shoulder_r]:
		var upper := MeshFactory.Batch.new()
		upper.add(MeshFactory.capsule_mesh(0.052 * w, 0.32), _t(Vector3(0, -0.14, 0)), top)
		_emit(upper, sh, mat, false)
		var elbow := _limb_pivot(sh, Vector3(0, -0.29, 0))
		var fore := MeshFactory.Batch.new()
		fore.add(MeshFactory.capsule_mesh(0.044 * w, 0.28), _t(Vector3(0, -0.12, 0)), skin if style == "shirt" else top)
		fore.add(MeshFactory.sphere_mesh(0.045, 8), _t(Vector3(0, -0.28, 0), Vector3.ZERO, Vector3(0.8, 1.1, 1.0)), skin)
		_emit(fore, elbow, mat, false)
		if sh == _shoulder_l:
			_elbow_l = elbow
		else:
			_elbow_r = elbow

	for mi in detail.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visibility_range_end = DETAIL_RANGE
		(mi as MeshInstance3D).visibility_range_end_margin = 2.0

	# Fernansicht: eine einzige Silhouette
	var far_b := MeshFactory.Batch.new()
	far_b.add(MeshFactory.capsule_mesh(0.2 * w, 0.95, 8), _t(Vector3(0, 1.25, 0), Vector3.ZERO, Vector3(1, 1, 0.7)), top)
	far_b.add(MeshFactory.capsule_mesh(0.17 * w, 0.95, 8), _t(Vector3(0, 0.47, 0), Vector3.ZERO, Vector3(1, 1, 0.7)), pants)
	far_b.add(MeshFactory.sphere_mesh(0.12, 8), _t(Vector3(0, 1.62, 0)), hair)
	var far := far_b.to_instance(mat, self)
	far.name = "FarLOD"
	far.scale = Vector3(h, h, h)
	far.visibility_range_begin = DETAIL_RANGE
	far.visibility_range_end = FAR_RANGE
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _t(pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot) * Basis.from_scale(scl), pos)


func _emit(batch: MeshFactory.Batch, parent: Node3D, mat: Material, shadows: bool) -> void:
	var mi := batch.to_instance(mat, parent)
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _limb_pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


## speed: horizontale Geschwindigkeit in m/s, airborne: in der Luft.
func animate(speed: float, delta: float, airborne: bool = false) -> void:
	if _hip_l == null:
		return
	var moving := clampf(speed / 3.0, 0.0, 1.6)
	_phase += delta * (2.0 + speed * 2.2)
	var s := sin(_phase)
	var amp := 0.55 * minf(moving, 1.2)
	if airborne:
		_hip_l.rotation.x = -0.5
		_hip_r.rotation.x = 0.2
		_knee_l.rotation.x = -0.9
		_knee_r.rotation.x = -0.4
		_shoulder_l.rotation.x = 0.7
		_shoulder_r.rotation.x = 0.7
		return
	_hip_l.rotation.x = s * amp
	_hip_r.rotation.x = -s * amp
	_knee_l.rotation.x = -(maxf(0.0, -s) * amp * 1.4 + 0.05)
	_knee_r.rotation.x = -(maxf(0.0, s) * amp * 1.4 + 0.05)
	_shoulder_l.rotation.x = -s * amp * 0.8
	_shoulder_r.rotation.x = s * amp * 0.8
	_shoulder_l.rotation.z = -0.08
	_shoulder_r.rotation.z = 0.08
	_elbow_l.rotation.x = 0.25 + amp * 0.4
	_elbow_r.rotation.x = 0.25 + amp * 0.4
	# Atmen / Wippen
	var bob := absf(cos(_phase)) * 0.025 * minf(moving, 1.0)
	var breathe := sin(_phase * 0.5) * 0.004 * (1.0 - minf(moving, 1.0))
	_torso.position.y = 0.95 + bob + breathe
	_torso.rotation.x = 0.06 * minf(moving, 1.5)
	if waving:
		_wave += delta * 8.0
		_shoulder_r.rotation.x = 2.6
		_shoulder_r.rotation.z = 0.3 + sin(_wave) * 0.25
		_elbow_r.rotation.x = 0.4
