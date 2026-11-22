extends TestCase


func test_district_is_400m() -> void:
	check_eq(CityLayout.HALF_SIZE * 2.0, 400.0, "400 x 400 m")
	check_eq(CityLayout.block_count(), 4, "4x4 Blöcke")


func test_blocks_do_not_overlap_roads() -> void:
	for iz in 4:
		for ix in 4:
			var r := CityLayout.block_rect(ix, iz)
			check(r.size.x > 60.0 and r.size.y > 60.0, "Blockgröße")
			var c := r.get_center()
			check(not CityLayout.is_on_road(Vector3(c.x, 0, c.y)), "Blockmitte nicht auf Straße")
			check(not CityLayout.is_on_road(Vector3(r.position.x + 0.5, 0, r.position.y + 0.5)), "Blockecke nicht auf Straße")


func test_surface_classification() -> void:
	check_eq(CityLayout.surface_at(Vector3(0, 0, 45)), "road", "Straße")
	check_eq(CityLayout.surface_at(Vector3(9, 0, 45)), "sidewalk", "Gehweg")
	check_eq(CityLayout.surface_at(Vector3(45, 0, 45)), "lot", "Grundstück")
	check_eq(CityLayout.surface_at(Vector3(250, 0, 0)), "outside", "außerhalb")


func test_checkpoints_and_deliveries_on_roads() -> void:
	for cp in CityLayout.RACE_CHECKPOINTS:
		check(CityLayout.is_on_road(cp), "Checkpoint %s auf Straße" % cp)
	for k in ["delivery_1", "delivery_2", "delivery_3", "race_start"]:
		check(CityLayout.is_on_road(CityLayout.poi(k)), "%s auf Straße" % k)


func test_pois_inside_district() -> void:
	for k in CityLayout.POIS.keys():
		check(CityLayout.is_inside_bounds(CityLayout.poi(k)), "%s im Viertel" % k)
	for p in CityLayout.COLLECTIBLES:
		check(CityLayout.is_inside_bounds(p), "Sammelobjekt im Viertel")


func test_nearest_road_point() -> void:
	for p in [Vector3(45, 0, 45), Vector3(-130, 0, 160), Vector3(199, 0, -199)]:
		check(CityLayout.is_on_road(CityLayout.nearest_road_point(p)), "Rettungspunkt auf Straße für %s" % p)


func test_sidewalk_loop_on_sidewalk() -> void:
	for p in CityLayout.sidewalk_loop(1, 1):
		check_eq(CityLayout.surface_at(p), "sidewalk", "Rundweg-Punkt %s" % p)
