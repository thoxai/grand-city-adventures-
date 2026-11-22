extends TestCase


func test_lights_out_generated_unsolved_and_solvable() -> void:
	for size in [3, 4]:
		for seed_value in range(1, 40):
			var p := PuzzleLogic.LightsOut.new(size, seed_value, 4)
			check(not p.is_solved(), "Größe %d Seed %d nicht schon gelöst" % [size, seed_value])
			for i in p.solution():
				p.press(int(i))
			check(p.is_solved(), "Größe %d Seed %d lösbar" % [size, seed_value])


func test_lights_out_press_twice_is_identity() -> void:
	var p := PuzzleLogic.LightsOut.new(3, 7, 3)
	var before := p.cells.duplicate()
	p.press(4)
	p.press(4)
	check_eq(p.cells, before, "zweimal drücken hebt sich auf")
	check_eq(p.moves, 2, "Züge gezählt")


func test_lights_out_toggles_neighbors_only() -> void:
	var p := PuzzleLogic.LightsOut.new(3, 1, 1)
	for i in p.solution():
		p.press(int(i))
	p.moves = 0
	p.press(0)  # Ecke: sich selbst + 2 Nachbarn
	check_eq(p.lit_count(), 6, "Ecke schaltet 3 Felder")
	p.press(0)
	p.press(4)  # Mitte: 5 Felder
	check_eq(p.lit_count(), 4, "Mitte schaltet 5 Felder")


func test_lights_out_hint_progresses() -> void:
	var p := PuzzleLogic.LightsOut.new(4, 77, 5)
	var guard := 0
	while not p.is_solved() and guard < 30:
		p.press(p.hint())
		guard += 1
	check(p.is_solved(), "Tipps führen zur Lösung")
	check_eq(p.hint(), -1, "kein Tipp mehr nötig")


func test_frequency_puzzle() -> void:
	var f := PuzzleLogic.Frequency.new(5)
	check(not f.is_solved(), "Startwerte lösen nicht")
	check(f.target_freq >= 88.0 and f.target_freq <= 108.0, "Zielfrequenz im Band")
	f.set_values(f.target_freq, f.target_phase)
	check(f.is_solved(), "exakte Werte lösen")
	check_near(f.strength(), 1.0, 0.001, "volle Stärke")
	f.set_values(f.target_freq + 1.5, f.target_phase)
	check(not f.is_solved(), "falsche Frequenz")
	f.set_values(f.target_freq, f.target_phase + 120.0)
	check(not f.is_solved(), "falsche Phase")
	f.set_values(500.0, -30.0)
	check(f.freq <= 108.0 and f.phase >= 0.0 and f.phase < 360.0, "Werte begrenzt")
