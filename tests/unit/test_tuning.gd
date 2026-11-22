extends TestCase


func test_both_cars_defined() -> void:
	check(TuningData.CARS.has("car_compact"), "Kompaktwagen")
	check(TuningData.CARS.has("car_sport"), "Sportwagen")
	check(TuningData.base_spec("car_sport")["top_speed"] > TuningData.base_spec("car_compact")["top_speed"], "Sportwagen schneller")


func test_upgrades_improve_stats() -> void:
	for car in TuningData.CARS.keys():
		var base := TuningData.compute_stats(car, {})
		var full := TuningData.compute_stats(car, {"engine": 3, "tires": 3, "nitro": 2})
		check(full["top_speed"] > base["top_speed"], "%s Topspeed" % car)
		check(full["accel"] > base["accel"], "%s Beschleunigung" % car)
		check(full["grip"] > base["grip"], "%s Grip" % car)
		check_eq(base["nitro_capacity"], 0.0, "%s ohne Nitro" % car)
		check(full["nitro_capacity"] > 0.0, "%s mit Nitro" % car)


func test_levels_are_clamped() -> void:
	var a := TuningData.compute_stats("car_compact", {"engine": 99})
	var b := TuningData.compute_stats("car_compact", {"engine": 3})
	check_eq(a["top_speed"], b["top_speed"], "Stufe begrenzt")


func test_costs() -> void:
	check_eq(TuningData.upgrade_cost("engine", 0), 250, "Motor 1")
	check_eq(TuningData.upgrade_cost("engine", 2), 750, "Motor 3")
	check_eq(TuningData.upgrade_cost("engine", 3), -1, "Motor max")
	check_eq(TuningData.upgrade_cost("nitro", 2), -1, "Nitro max")
	check_eq(TuningData.upgrade_cost("flügel", 0), -1, "unbekannt")


func test_paint_wraps() -> void:
	var cols: Array = TuningData.base_spec("car_compact")["colors"]
	check_eq(TuningData.paint_color("car_compact", cols.size()), cols[0], "Farbe wiederholt sich")
	check_eq(TuningData.kmh(10.0), 36, "km/h")


func test_story_money_covers_some_tuning() -> void:
	var total := 100
	for m in MissionData.MISSIONS:
		total += int(m["reward"])
	total += CityLayout.COLLECTIBLES.size() * GameState.COLLECTIBLE_REWARD
	var all_tuning := 0
	for cat in TuningData.COSTS.keys():
		for c in TuningData.COSTS[cat]:
			all_tuning += c
	check(total > 1500, "genug Geld für sinnvolle Upgrades (%d)" % total)
	check(total < all_tuning * 2, "nicht alles sofort kaufbar (Langzeitmotivation)")
