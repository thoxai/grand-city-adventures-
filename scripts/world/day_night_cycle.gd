class_name DayNightCycle
extends Node3D
## Tag-Nacht-Wechsel: Sonnen-/Mondlicht, prozeduraler Himmel, Nebel,
## leuchtende Fenster und Strassenlaternen.
##
## Laternen: Alle Leuchtenkoepfe leuchten emissiv (MultiMesh). Echte
## OmniLights gibt es nur als kleinen Pool, der jeweils an die naechsten
## Laternen um die Kamera wandert – so bleibt die Lichtanzahl mobilfreundlich.

const LIGHT_POOL_SIZE := 6
const POOL_UPDATE_INTERVAL := 0.5

var city: CityBuilder
var camera_provider: Callable
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var night_factor := 0.0
var shadows_enabled := true
var _pool: Array[OmniLight3D] = []
var _pool_timer := 0.0
var _beacon: Node3D
var _beacon_t := 0.0


func setup(p_city: CityBuilder) -> void:
	city = p_city
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	add_child(sun)

	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_color = Color(0.62, 0.6, 0.58)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	for i in LIGHT_POOL_SIZE:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.8, 0.55)
		l.light_energy = 0.0
		l.omni_range = 13.0
		l.omni_attenuation = 1.4
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_pool.append(l)
	_beacon = city.get_node_or_null("RadioBeacon")
	update_lighting(GameState.time_of_day)


func _process(delta: float) -> void:
	update_lighting(GameState.time_of_day)
	_pool_timer -= delta
	if _pool_timer <= 0.0:
		_pool_timer = POOL_UPDATE_INTERVAL
		_update_light_pool()
	if _beacon:
		_beacon_t += delta
		_beacon.visible = fmod(_beacon_t, 1.6) < 0.8


## Sonnenposition als Einheitsvektor (zeigt zur Sonne). Mittags am hoechsten.
static func sun_direction(hour: float) -> Vector3:
	var az := (hour - 6.0) / 12.0 * PI
	return Vector3(cos(az) * 0.8, sin(az), 0.45).normalized()


## 0 = Tag, 1 = tiefe Nacht. Weiche Uebergaenge in Daemmerung.
static func compute_night_factor(hour: float) -> float:
	var y := sun_direction(hour).y
	return 1.0 - smoothstep(-0.12, 0.18, y)


func update_lighting(hour: float) -> void:
	var dir := sun_direction(hour)
	night_factor = compute_night_factor(hour)
	var day := 1.0 - night_factor
	var dusk := clampf(1.0 - absf(dir.y) / 0.3, 0.0, 1.0) * smoothstep(-0.2, 0.05, dir.y)

	# Tagsueber Sonne, nachts schwaches Mondlicht aus der Gegenrichtung
	var light_dir := dir if dir.y > -0.05 else Vector3(-dir.x, absf(dir.y) * 0.8 + 0.3, -dir.z).normalized()
	if sun:
		sun.transform = Transform3D(Basis.looking_at(-light_dir, Vector3.UP if absf(light_dir.y) < 0.99 else Vector3.FORWARD), Vector3.ZERO)
		var sun_col := Color(1.0, 0.96, 0.9).lerp(Color(1.0, 0.62, 0.35), dusk)
		sun.light_color = sun_col.lerp(Color(0.55, 0.65, 0.95), night_factor)
		sun.light_energy = lerpf(0.12, 1.25, day) * (1.0 - 0.35 * dusk)
		sun.shadow_enabled = shadows_enabled and (day > 0.2 or night_factor > 0.95)

	if sky_mat:
		var top_day := Color(0.22, 0.42, 0.78)
		var hor_day := Color(0.68, 0.76, 0.86)
		var top_night := Color(0.01, 0.015, 0.04)
		var hor_night := Color(0.05, 0.07, 0.12)
		var hor_dusk := Color(0.98, 0.52, 0.28)
		sky_mat.sky_top_color = top_day.lerp(top_night, night_factor)
		sky_mat.sky_horizon_color = hor_day.lerp(hor_night, night_factor).lerp(hor_dusk, dusk * 0.85)
		sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
		sky_mat.ground_bottom_color = Color(0.1, 0.1, 0.1).lerp(Color(0.01, 0.01, 0.02), night_factor)
		sky_mat.sky_energy_multiplier = lerpf(0.35, 1.0, day)
		sky_mat.sun_angle_max = 25.0 if night_factor < 0.9 else 2.0
	if env:
		env.ambient_light_energy = lerpf(0.45, 1.0, day)
		env.ambient_light_color = Color(0.62, 0.6, 0.58).lerp(Color(0.2, 0.24, 0.36), night_factor)
		env.fog_light_color = sky_mat.sky_horizon_color if sky_mat else Color.GRAY
		env.glow_intensity = lerpf(0.4, 0.9, night_factor)
	if city:
		city.building_material.set_shader_parameter("night_factor", night_factor)
		city.ground_material.set_shader_parameter("night_factor", night_factor)
		city.lamp_material.emission_energy_multiplier = lerpf(0.1, 5.0, night_factor)


func _update_light_pool() -> void:
	var active := night_factor > 0.35 and city != null
	if not active or not camera_provider.is_valid():
		for l in _pool:
			l.visible = false
		return
	var cam_pos: Vector3 = camera_provider.call()
	var sorted: Array = city.lamp_positions.duplicate()
	sorted.sort_custom(func(a, b): return a.distance_squared_to(cam_pos) < b.distance_squared_to(cam_pos))
	for i in _pool.size():
		var l := _pool[i]
		if i < sorted.size():
			l.visible = true
			l.global_position = sorted[i] - Vector3(0, 0.4, 0)
			l.light_energy = 2.2 * night_factor
		else:
			l.visible = false
