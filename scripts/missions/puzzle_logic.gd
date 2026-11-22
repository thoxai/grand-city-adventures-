class_name PuzzleLogic
extends RefCounted
## Reine Rätsel-Logik (ohne UI) – vollständig unit-testbar.


## "Sicherungs-Rätsel" (Lights-Out-Prinzip): Jede Sicherung schaltet sich
## selbst und ihre direkten Nachbarn um. Ziel: alle Sicherungen grün.
## Erzeugt wird das Rätsel durch zufälliges Drücken auf ein gelöstes Feld –
## dadurch ist es garantiert lösbar.
class LightsOut:
	extends RefCounted
	var size := 3
	var cells: Array[bool] = []
	var moves := 0
	var _solution: Dictionary = {}   # Index -> true: noch zu drückende Felder

	func _init(p_size: int = 3, p_seed: int = 0, scramble: int = 4) -> void:
		size = clampi(p_size, 2, 6)
		cells.resize(size * size)
		cells.fill(true)
		var rng := RandomNumberGenerator.new()
		rng.seed = p_seed
		var picked: Array[int] = []
		var n := clampi(scramble, 1, size * size)
		while picked.size() < n:
			var i := rng.randi_range(0, size * size - 1)
			if not picked.has(i):
				picked.append(i)
		for i in picked:
			_toggle_area(i)
			_solution[i] = true
		moves = 0

	func press(i: int) -> void:
		if i < 0 or i >= cells.size():
			return
		_toggle_area(i)
		if _solution.has(i):
			_solution.erase(i)
		else:
			_solution[i] = true
		moves += 1

	func _toggle_area(i: int) -> void:
		var x := i % size
		var y := i / size
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx >= 0 and nx < size and ny >= 0 and ny < size:
				var j := ny * size + nx
				cells[j] = not cells[j]

	func is_solved() -> bool:
		for c in cells:
			if not c:
				return false
		return true

	func lit_count() -> int:
		var n := 0
		for c in cells:
			if c:
				n += 1
		return n

	## Felder, deren Drücken das Rätsel löst (Reihenfolge egal).
	func solution() -> Array:
		return _solution.keys()

	func hint() -> int:
		var s := solution()
		return -1 if s.is_empty() else int(s[0])


## "Frequenz-Rätsel": Frequenz (MHz) und Phase (Grad) so einstellen, dass
## das Empfangssignal mit dem Störsignal übereinstimmt.
class Frequency:
	extends RefCounted
	const MIN_FREQ := 88.0
	const MAX_FREQ := 108.0
	const SOLVE_THRESHOLD := 0.93
	var target_freq := 98.0
	var target_phase := 90.0
	var freq := 88.0
	var phase := 0.0

	func _init(p_seed: int = 0) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = p_seed
		target_freq = snappedf(rng.randf_range(91.0, 106.0), 0.1)
		target_phase = snappedf(rng.randf_range(30.0, 330.0), 5.0)
		freq = MIN_FREQ
		phase = 0.0

	func set_values(f: float, p: float) -> void:
		freq = clampf(f, MIN_FREQ, MAX_FREQ)
		phase = fposmod(p, 360.0)

	func strength() -> float:
		var sf := clampf(1.0 - absf(freq - target_freq) / 3.0, 0.0, 1.0)
		var sp := 0.5 + 0.5 * cos(deg_to_rad(phase - target_phase))
		return sf * (0.3 + 0.7 * sp)

	func is_solved() -> bool:
		return strength() >= SOLVE_THRESHOLD
