extends Node
## Zentraler, serialisierbarer Spielzustand (Autoload "GameState").
##
## Enthaelt nur Daten, keine Szenenlogik. Alle Werte lassen sich ueber
## to_dict()/from_dict() verlustfrei als JSON speichern.

signal money_changed(amount: int)
signal notify(text: String)
signal state_changed

const CHARACTERS := {
	"alex": {
		"name": "Alex",
		"partner": "mia",
		"bio": "15, Technik-Tüftler. Repariert alles, was Kabel hat.",
	},
	"mia": {
		"name": "Mia",
		"partner": "alex",
		"bio": "16, Kartsport-Talent. Kennt jede Abkürzung im Viertel.",
	},
}

## Spielminuten pro Echtzeitsekunde (1.0 => ein Tag dauert 24 Minuten).
const DEFAULT_TIME_SCALE := 1.0
const START_HOUR := 8.0
const COLLECTIBLE_REWARD := 50

var character_id: String = "alex"
var money: int = 0
var completed_missions: Array = []
var unlocked_cars: Array = []
var tuning: Dictionary = {}
var collected: Array = []
var time_of_day: float = START_HOUR
var time_scale: float = DEFAULT_TIME_SCALE
var playtime: float = 0.0
var day: int = 1
var quality: String = "medium"
var show_fps: bool = false
var jobs_done: int = 0
var job_earnings: int = 0


func reset_new_game(char_id: String) -> void:
	character_id = char_id if CHARACTERS.has(char_id) else "alex"
	money = 100
	completed_missions = []
	unlocked_cars = []
	tuning = {}
	collected = []
	time_of_day = START_HOUR
	playtime = 0.0
	day = 1
	jobs_done = 0
	job_earnings = 0
	money_changed.emit(money)
	state_changed.emit()


func character_name(id: String = "") -> String:
	var key := character_id if id == "" else id
	return CHARACTERS.get(key, CHARACTERS["alex"])["name"]


func partner_id() -> String:
	return CHARACTERS[character_id]["partner"]


func add_money(amount: int) -> void:
	money = max(0, money + amount)
	money_changed.emit(money)


func can_afford(amount: int) -> bool:
	return amount >= 0 and money >= amount


## Zieht Geld ab, falls genug vorhanden ist. Gibt false zurueck, wenn nicht.
func spend(amount: int) -> bool:
	if not can_afford(amount):
		return false
	money -= amount
	money_changed.emit(money)
	return true


func unlock_car(car_id: String) -> void:
	if not unlocked_cars.has(car_id):
		unlocked_cars.append(car_id)
		state_changed.emit()


func is_car_unlocked(car_id: String) -> bool:
	return unlocked_cars.has(car_id)


func get_tuning(car_id: String) -> Dictionary:
	if not tuning.has(car_id):
		tuning[car_id] = {"engine": 0, "tires": 0, "nitro": 0, "color": 0}
	return tuning[car_id]


func set_tuning_value(car_id: String, key: String, value: int) -> void:
	var t := get_tuning(car_id)
	t[key] = value
	state_changed.emit()


func complete_mission(mission_id: String, reward: int) -> void:
	if completed_missions.has(mission_id):
		return
	completed_missions.append(mission_id)
	add_money(reward)
	state_changed.emit()


func is_mission_completed(mission_id: String) -> bool:
	return completed_missions.has(mission_id)


## Sammelobjekt einsammeln. Gibt true zurueck, wenn es neu war.
func collect(item_id: String) -> bool:
	if collected.has(item_id):
		return false
	collected.append(item_id)
	add_money(COLLECTIBLE_REWARD)
	return true


## Nebenjob-Statistik (Geld wird separat über add_money gutgeschrieben).
func record_job(earned: int) -> void:
	jobs_done += 1
	job_earnings += earned


func advance_time(delta: float) -> void:
	playtime += delta
	var t := time_of_day + delta * time_scale / 60.0
	if t >= 24.0:
		day += 1
	time_of_day = fposmod(t, 24.0)


func is_night() -> bool:
	return time_of_day >= 20.5 or time_of_day < 5.5


func clock_string() -> String:
	var h := int(time_of_day)
	var m := int((time_of_day - h) * 60.0)
	return "%02d:%02d" % [h, m]


func to_dict() -> Dictionary:
	return {
		"character_id": character_id,
		"money": money,
		"completed_missions": completed_missions.duplicate(),
		"unlocked_cars": unlocked_cars.duplicate(),
		"tuning": tuning.duplicate(true),
		"collected": collected.duplicate(),
		"time_of_day": time_of_day,
		"playtime": playtime,
		"day": day,
		"quality": quality,
		"jobs_done": jobs_done,
		"job_earnings": job_earnings,
	}


func from_dict(d: Dictionary) -> void:
	character_id = str(d.get("character_id", "alex"))
	if not CHARACTERS.has(character_id):
		character_id = "alex"
	money = int(d.get("money", 0))
	completed_missions = Array(d.get("completed_missions", []))
	unlocked_cars = Array(d.get("unlocked_cars", []))
	tuning = {}
	var t: Dictionary = d.get("tuning", {})
	for car_id in t.keys():
		var src: Dictionary = t[car_id]
		tuning[car_id] = {
			"engine": int(src.get("engine", 0)),
			"tires": int(src.get("tires", 0)),
			"nitro": int(src.get("nitro", 0)),
			"color": int(src.get("color", 0)),
		}
	collected = Array(d.get("collected", []))
	time_of_day = clampf(float(d.get("time_of_day", START_HOUR)), 0.0, 23.999)
	playtime = float(d.get("playtime", 0.0))
	day = int(d.get("day", 1))
	quality = str(d.get("quality", "medium"))
	jobs_done = int(d.get("jobs_done", 0))
	job_earnings = int(d.get("job_earnings", 0))
	money_changed.emit(money)
	state_changed.emit()
