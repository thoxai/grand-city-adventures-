class_name MeshFactory
extends RefCounted
## Hilfsfunktionen zum Erzeugen eigener, einfacher 3D-Assets aus Primitiven.
## Materialien werden zwischengespeichert, damit gleiche Farben dieselbe
## Materialinstanz teilen (weniger State-Wechsel auf Mobilgeraeten).

static var _material_cache: Dictionary = {}


static func material(color: Color, roughness: float = 0.8, metallic: float = 0.0, emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s|%.2f" % [color.to_html(), roughness, metallic, emission.to_html(), emission_energy]
	if _material_cache.has(key):
		return _material_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	_material_cache[key] = m
	return m


static func glass_material() -> StandardMaterial3D:
	if _material_cache.has("glass"):
		return _material_cache["glass"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.08, 0.11, 0.82)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.6
	m.metallic_specular = 0.9
	_material_cache["glass"] = m
	return m


static func box(size: Vector3, mat: Material, pos: Vector3 = Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	if parent:
		parent.add_child(mi)
	return mi


static func cylinder(radius: float, height: float, mat: Material, pos: Vector3 = Vector3.ZERO, parent: Node = null, segments: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = segments
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	if parent:
		parent.add_child(mi)
	return mi


static func sphere(radius: float, mat: Material, pos: Vector3 = Vector3.ZERO, parent: Node = null, segments: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = segments
	sm.rings = max(4, segments / 2)
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	if parent:
		parent.add_child(mi)
	return mi


static func capsule(radius: float, height: float, mat: Material, pos: Vector3 = Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = max(height, radius * 2.0)
	cm.radial_segments = 10
	cm.rings = 3
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	if parent:
		parent.add_child(mi)
	return mi


## Quader mit verjuengter Oberseite (z. B. Fahrzeugkabine mit schraegen Scheiben).
## bottom/top: Groesse in X/Z, height: Hoehe, top_offset_z verschiebt die Oberseite.
static func tapered_box(bottom: Vector2, top: Vector2, height: float, top_offset_z: float = 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bx := bottom.x * 0.5
	var bz := bottom.y * 0.5
	var tx := top.x * 0.5
	var tz := top.y * 0.5
	var b := [Vector3(-bx, 0, -bz), Vector3(bx, 0, -bz), Vector3(bx, 0, bz), Vector3(-bx, 0, bz)]
	var t := [
		Vector3(-tx, height, -tz + top_offset_z), Vector3(tx, height, -tz + top_offset_z),
		Vector3(tx, height, tz + top_offset_z), Vector3(-tx, height, tz + top_offset_z),
	]
	# Seiten (gegen den Uhrzeigersinn von aussen gesehen)
	for i in 4:
		var j := (i + 1) % 4
		_quad(st, b[i], b[j], t[j], t[i])
	_quad(st, t[0], t[1], t[2], t[3])
	_quad(st, b[3], b[2], b[1], b[0])
	st.generate_normals()
	return st.commit()


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	# Godot: Vorderseiten im Uhrzeigersinn
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


## Gemeinsames Material für Vertex-gefärbte, zusammengefasste Meshes.
static func vertex_color_material(roughness: float = 0.75, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "vc|%.2f|%.2f" % [roughness, metallic]
	if _material_cache.has(key):
		return _material_cache[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = roughness
	m.metallic = metallic
	_material_cache[key] = m
	return m


static func box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func sphere_mesh(radius: float, segments: int = 10) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = max(4, segments / 2)
	return m


static func capsule_mesh(radius: float, height: float, segments: int = 10) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	m.radial_segments = segments
	m.rings = 3
	return m


static func cylinder_mesh(radius: float, height: float, segments: int = 12) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m


## Fasst viele einfache Meshes (mit Transformation und Farbe) zu EINER
## Oberfläche mit Vertex-Farben zusammen => ein Draw-Call statt vieler.
class Batch:
	extends RefCounted
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	func add(mesh: Mesh, xform: Transform3D, color: Color) -> void:
		var arr: Array
		if mesh is PrimitiveMesh:
			arr = (mesh as PrimitiveMesh).get_mesh_arrays()
		else:
			arr = mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx = arr[Mesh.ARRAY_INDEX]
		var base := verts.size()
		var nb := xform.basis.inverse().transposed()
		for i in v.size():
			verts.append(xform * v[i])
			normals.append((nb * n[i]).normalized() if i < n.size() else Vector3.UP)
			colors.append(color)
		if idx == null or (idx as PackedInt32Array).is_empty():
			for i in v.size():
				indices.append(base + i)
		else:
			for i in idx:
				indices.append(base + i)

	## Hängt eine andere Batch mit Transformation an (z. B. zum Zusammenfassen ganzer Figuren).
	func add_batch(other: Batch, xform: Transform3D) -> void:
		var base := verts.size()
		var nb := xform.basis.inverse().transposed()
		for i in other.verts.size():
			verts.append(xform * other.verts[i])
			normals.append((nb * other.normals[i]).normalized())
			colors.append(other.colors[i])
		for i in other.indices:
			indices.append(base + i)

	func is_empty() -> bool:
		return verts.is_empty()

	## Hängt die gesammelte Geometrie als neue Oberfläche an "target" an.
	func commit_to(target: ArrayMesh, material: Material) -> void:
		if verts.is_empty():
			return
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		target.surface_set_material(target.get_surface_count() - 1, material)

	func to_instance(material: Material, parent: Node3D = null) -> MeshInstance3D:
		var am := ArrayMesh.new()
		commit_to(am, material)
		var mi := MeshInstance3D.new()
		mi.mesh = am
		if parent:
			parent.add_child(mi)
		return mi
