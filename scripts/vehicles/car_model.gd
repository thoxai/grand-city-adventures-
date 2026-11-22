class_name CarModel
extends Node3D
## Prozedural modelliertes Fahrzeug (eigenes Asset): Karosserie mit schraegen
## Scheiben, Raeder mit Felgen, Scheinwerfer, Rueckleuchten, Spiegel.
## Front zeigt nach -Z.

var paint: StandardMaterial3D
var tail_mat: StandardMaterial3D
var head_mat: StandardMaterial3D
var wheels: Array[Node3D] = []  # drehende Rad-Meshes
var front_pivots: Array[Node3D] = []
var headlight: SpotLight3D
var wheel_radius := 0.33
var _spin := 0.0


func build(spec: Dictionary, color: Color, plate: String = "GC 0000") -> void:
	var size: Vector3 = spec.get("size", Vector3(1.8, 1.45, 4.0))
	var style: String = spec.get("style", "hatch")
	var w := size.x
	var h := size.y
	var l := size.z
	wheel_radius = 0.33 if style == "hatch" else 0.34

	paint = StandardMaterial3D.new()
	paint.albedo_color = color
	paint.metallic = 0.55
	paint.roughness = 0.28
	paint.clearcoat_enabled = true
	paint.clearcoat = 0.6
	head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.95, 0.95, 0.9)
	head_mat.emission_enabled = true
	head_mat.emission = Color(1.0, 0.95, 0.85)
	head_mat.emission_energy_multiplier = 0.3
	tail_mat = StandardMaterial3D.new()
	tail_mat.albedo_color = Color(0.5, 0.02, 0.02)
	tail_mat.emission_enabled = true
	tail_mat.emission = Color(1.0, 0.05, 0.03)
	tail_mat.emission_energy_multiplier = 0.4

	var clearance := 0.2
	var lower_h := h * 0.42
	var c_trim := Color(0.06, 0.06, 0.07)
	var c_chrome := Color(0.72, 0.73, 0.76)
	var c_rubber := Color(0.05, 0.05, 0.05)
	# Alle Teile werden zu wenigen Oberflächen zusammengefasst (Draw-Calls!)
	var paint_b := MeshFactory.Batch.new()
	var trim_b := MeshFactory.Batch.new()
	var glass_b := MeshFactory.Batch.new()
	var head_b := MeshFactory.Batch.new()
	var tail_b := MeshFactory.Batch.new()

	paint_b.add(MeshFactory.tapered_box(Vector2(w, l), Vector2(w * 0.97, l * 0.95), lower_h), _t(Vector3(0, clearance, 0)), Color.WHITE)
	trim_b.add(MeshFactory.box_mesh(Vector3(w * 0.96, 0.12, l * 0.9)), _t(Vector3(0, clearance + 0.02, 0)), c_trim)

	# Kabine
	var cab_len := l * (0.52 if style == "hatch" else 0.42)
	var cab_top := cab_len * (0.62 if style == "hatch" else 0.5)
	var cab_z := l * (0.1 if style == "hatch" else 0.06)
	var cab_h := h - lower_h - clearance - 0.03
	var top_off := cab_len * (0.12 if style == "hatch" else 0.15)
	glass_b.add(MeshFactory.tapered_box(Vector2(w * 0.9, cab_len), Vector2(w * 0.78, cab_top), cab_h, top_off), _t(Vector3(0, clearance + lower_h, cab_z)), Color.WHITE)
	paint_b.add(MeshFactory.tapered_box(Vector2(w * 0.79, cab_top * 1.02), Vector2(w * 0.76, cab_top * 0.95), 0.05), _t(Vector3(0, clearance + lower_h + cab_h - 0.01, cab_z + top_off)), Color.WHITE)
	for sx in [-1.0, 1.0]:
		paint_b.add(MeshFactory.box_mesh(Vector3(0.06, cab_h * 0.95, 0.12)), _t(Vector3(sx * w * 0.42, clearance + lower_h + cab_h * 0.48, cab_z + 0.1), Vector3(0, 0, -sx * 0.1)), Color.WHITE)
		paint_b.add(MeshFactory.box_mesh(Vector3(0.16, 0.08, 0.1)), _t(Vector3(sx * (w * 0.5 + 0.05), clearance + lower_h + 0.1, cab_z - cab_len * 0.38)), Color.WHITE)
		# Türfugen
		trim_b.add(MeshFactory.box_mesh(Vector3(0.01, lower_h * 0.8, 0.012)), _t(Vector3(sx * w * 0.492, clearance + lower_h * 0.5, cab_z - cab_len * 0.1)), c_trim)
		trim_b.add(MeshFactory.box_mesh(Vector3(0.012, 0.03, 0.14)), _t(Vector3(sx * w * 0.495, clearance + lower_h * 0.75, cab_z)), c_chrome)

	# Stoßfänger, Kühlergrill, Kennzeichen
	trim_b.add(MeshFactory.box_mesh(Vector3(w, 0.22, 0.16)), _t(Vector3(0, clearance + 0.12, -l * 0.5 + 0.02)), c_trim)
	trim_b.add(MeshFactory.box_mesh(Vector3(w, 0.22, 0.16)), _t(Vector3(0, clearance + 0.12, l * 0.5 - 0.02)), c_trim)
	trim_b.add(MeshFactory.box_mesh(Vector3(w * 0.45, 0.12, 0.04)), _t(Vector3(0, clearance + lower_h * 0.6, -l * 0.5 + 0.01)), Color(0.02, 0.02, 0.02))
	for zf in [-1.0, 1.0]:
		trim_b.add(MeshFactory.box_mesh(Vector3(0.52, 0.12, 0.02)), _t(Vector3(0, clearance + 0.13, zf * (l * 0.5 + 0.07))), Color(0.92, 0.92, 0.9))
		var lbl := Label3D.new()
		lbl.text = plate
		lbl.font_size = 32
		lbl.pixel_size = 0.0035
		lbl.modulate = Color(0.05, 0.05, 0.08)
		lbl.outline_size = 0
		lbl.position = Vector3(0, clearance + 0.13, zf * (l * 0.5 + 0.085))
		lbl.rotation.y = 0.0 if zf > 0 else PI
		lbl.visibility_range_end = 15.0
		add_child(lbl)

	# Leuchten
	for sx in [-1.0, 1.0]:
		head_b.add(MeshFactory.box_mesh(Vector3(w * 0.22, 0.09, 0.05)), _t(Vector3(sx * w * 0.34, clearance + lower_h * 0.78, -l * 0.5 + 0.03)), Color.WHITE)
		tail_b.add(MeshFactory.box_mesh(Vector3(w * 0.2, 0.08, 0.05)), _t(Vector3(sx * w * 0.36, clearance + lower_h * 0.8, l * 0.5 - 0.03)), Color.WHITE)
	if style == "coupe":
		trim_b.add(MeshFactory.box_mesh(Vector3(w * 0.9, 0.04, 0.3)), _t(Vector3(0, clearance + lower_h + 0.22, l * 0.47)), c_trim)
		for sx in [-0.35, 0.35]:
			trim_b.add(MeshFactory.box_mesh(Vector3(0.04, 0.2, 0.12)), _t(Vector3(sx * w, clearance + lower_h + 0.1, l * 0.47)), c_trim)
		for sx in [-1.0, 1.0]:
			trim_b.add(MeshFactory.box_mesh(Vector3(0.02, 0.1, 0.5)), _t(Vector3(sx * w * 0.49, clearance + lower_h * 0.55, l * 0.12)), c_trim)

	# Radhäuser
	var wheel_x := w * 0.5 - 0.12
	var axle_z := l * 0.5 - (0.72 if style == "hatch" else 0.8)
	for zf in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			trim_b.add(MeshFactory.box_mesh(Vector3(0.05, 0.12, wheel_radius * 2.3)), _t(Vector3(sx * w * 0.49, clearance + lower_h * 0.75, zf * axle_z)), c_trim)

	var am := ArrayMesh.new()
	paint_b.commit_to(am, paint)
	trim_b.commit_to(am, MeshFactory.vertex_color_material(0.55, 0.2))
	glass_b.commit_to(am, MeshFactory.glass_material())
	head_b.commit_to(am, head_mat)
	tail_b.commit_to(am, tail_mat)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = am
	add_child(body)

	# Räder (je Rad ein Mesh, damit sie sich drehen können)
	var wheel_mat := MeshFactory.vertex_color_material(0.45, 0.35)
	for zf in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(sx * wheel_x, wheel_radius, zf * axle_z)
			add_child(pivot)
			var wb := MeshFactory.Batch.new()
			var rot := Vector3(0, 0, PI / 2.0)
			wb.add(MeshFactory.cylinder_mesh(wheel_radius, 0.24, 16), _t(Vector3.ZERO, rot), c_rubber)
			wb.add(MeshFactory.cylinder_mesh(wheel_radius * 0.62, 0.25, 10), _t(Vector3.ZERO, rot), c_chrome)
			wb.add(MeshFactory.box_mesh(Vector3(0.255, wheel_radius * 1.1, 0.06)), _t(Vector3.ZERO), c_trim)
			wb.add(MeshFactory.box_mesh(Vector3(0.255, 0.06, wheel_radius * 1.1)), _t(Vector3.ZERO), c_trim)
			var wheel := wb.to_instance(wheel_mat, pivot)
			wheels.append(wheel)
			if zf < 0:
				front_pivots.append(pivot)

	headlight = SpotLight3D.new()
	headlight.position = Vector3(0, clearance + lower_h * 0.7, -l * 0.5 - 0.1)
	headlight.spot_range = 30.0
	headlight.spot_angle = 38.0
	headlight.light_energy = 3.0
	headlight.light_color = Color(1.0, 0.95, 0.85)
	headlight.shadow_enabled = false
	headlight.rotation.x = -0.08
	headlight.visible = false
	add_child(headlight)


func _t(pos: Vector3, rot: Vector3 = Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot), pos)


func set_paint(color: Color) -> void:
	if paint:
		paint.albedo_color = color


func set_lights(head_on: bool, braking: bool) -> void:
	if headlight:
		headlight.visible = head_on
	if head_mat:
		head_mat.emission_energy_multiplier = 4.0 if head_on else 0.3
	if tail_mat:
		tail_mat.emission_energy_multiplier = (4.0 if braking else (1.6 if head_on else 0.4))


func update_visuals(speed: float, steer: float, delta: float) -> void:
	_spin += speed / wheel_radius * delta
	for wheel in wheels:
		wheel.rotation.x = -_spin
	for p in front_pivots:
		p.rotation.y = -steer * 0.5
