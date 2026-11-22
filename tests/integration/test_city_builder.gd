extends TestCase

var city: CityBuilder


func before_each() -> void:
	city = CityBuilder.new()
	runner.add_child(city)
	city.build()


func after_each() -> void:
	city.queue_free()


func test_city_has_content() -> void:
	check(city.building_count > 150, "genug Gebäude (%d)" % city.building_count)
	check(city.lamp_positions.size() > 80, "Straßenlaternen (%d)" % city.lamp_positions.size())
	check(city.minimap_rects.size() > 60, "Minikarten-Daten")
	check(city.solid_boxes.size() > 80, "Kollisionen")


func test_important_places_are_reachable() -> void:
	for k in CityLayout.POIS.keys():
		check(city.is_point_free(CityLayout.poi(k), 0.6), "Ort '%s' frei" % k)
	for i in CityLayout.COLLECTIBLES.size():
		check(city.is_point_free(CityLayout.COLLECTIBLES[i], 0.6), "Energiezelle %d frei" % i)
	for cp in CityLayout.RACE_CHECKPOINTS:
		check(city.is_point_free(cp, 2.0), "Checkpoint %s frei" % cp)


func test_npc_routes_are_free() -> void:
	var poles := []
	for n in range(5):
		for m in range(5):
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if TrafficLights.has_light(Vector2i(n, m)) and TrafficManager.valid_node(Vector2i(n, m) - d):
					poles.append(TrafficLights._pole_pos(Vector2i(n, m), d))
	var all := NpcData.all_npcs()
	for id in all.keys():
		for entry in all[id]["schedule"]:
			var path := NpcData.path_for(entry)
			if entry["type"] == "home":
				continue
			for i in path.size():
				var a: Vector3 = path[i]
				var b: Vector3 = path[(i + 1) % path.size()]
				var steps := int(a.distance_to(b)) + 1
				var blocked := false
				for k in steps + 1:
					var p := a.lerp(b, float(k) / float(steps))
					if not city.is_point_free(p, 0.3):
						blocked = true
					for pole in poles:
						if Vector2(p.x - pole.x, p.z - pole.z).length() < 0.42:
							blocked = true
				check(not blocked, "Weg von %s frei (%s -> %s)" % [id, a, b])


func test_deterministic_generation() -> void:
	var other := CityBuilder.new()
	runner.add_child(other)
	other.build()
	check_eq(other.building_count, city.building_count, "gleicher Seed => gleiche Stadt")
	check_eq(other.solid_boxes.size(), city.solid_boxes.size(), "gleiche Kollisionen")
	other.queue_free()


func test_day_night_cycle() -> void:
	var dn := DayNightCycle.new()
	runner.add_child(dn)
	dn.setup(city)
	dn.update_lighting(12.0)
	var day_energy := dn.sun.light_energy
	check(dn.night_factor < 0.05, "Mittag ist hell")
	dn.update_lighting(23.0)
	check(dn.night_factor > 0.95, "23 Uhr ist dunkel")
	check(dn.sun.light_energy < day_energy, "Mondlicht schwächer")
	check(city.lamp_material.emission_energy_multiplier > 3.0, "Laternen leuchten nachts")
	check_near(float(city.building_material.get_shader_parameter("night_factor")), dn.night_factor, 0.001, "Fenster leuchten")
	dn.update_lighting(18.0)
	check(dn.night_factor > 0.05 and dn.night_factor < 0.95, "Dämmerung um 18 Uhr")
	check(DayNightCycle.sun_direction(12.0).y > 0.9, "Sonne mittags hoch")
	dn.queue_free()
