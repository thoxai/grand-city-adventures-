class_name NpcData
extends RefCounted
## NPC-Definitionen: Aussehen, Tagesablauf und Dialoge.
##
## Tagesablauf: Liste von Eintraegen, sortiert nach "from" (Stunde).
##   type "idle"  -> steht bei "at"
##   type "walk"  -> laeuft die Punkte in "path" im Kreis ab
##   type "home"  -> ist zu Hause (unsichtbar, nicht ansprechbar)
## Story-NPCs (story = true) gehen nie nach Hause, damit Missionen immer
## spielbar bleiben.
## Dialoge nach Tageszeit: morning (5-11), day (11-17), evening (17-21), night.

const NPCS := {
	"rosa": {
		"name": "Frau Lindner",
		"story": true,
		"look": {"skin": Color(0.9, 0.76, 0.66), "hair": Color(0.82, 0.82, 0.8), "hair_style": "bun",
			"top": Color(0.42, 0.33, 0.5), "top_style": "jacket", "pants": Color(0.3, 0.28, 0.3),
			"shoes": Color(0.25, 0.2, 0.18), "height": 1.62, "build": 1.05, "accent": Color(0.85, 0.8, 0.7)},
		"schedule": [
			{"from": 0.0, "type": "idle", "at": Vector3(-129, 0, 10.5)},
			{"from": 7.0, "type": "walk", "path": [Vector3(-129, 0, 9.5), Vector3(-150, 0, 9.5)]},
			{"from": 12.0, "type": "idle", "at": Vector3(-129, 0, 10.5)},
			{"from": 15.0, "type": "walk", "path": [Vector3(-129, 0, 9.5), Vector3(-112, 0, 9.5)]},
			{"from": 19.0, "type": "idle", "at": Vector3(-129, 0, 10.5)},
		],
		"lines": {
			"morning": ["Guten Morgen, {player}! Die Blumen gießt man am besten früh."],
			"day": ["Kenji in der Werkstatt am Lindenpark sucht immer helfende Hände."],
			"evening": ["Siehst du die Lichter? Unser Viertel ist abends am schönsten."],
			"night": ["So spät noch unterwegs? Pass auf dich auf, {player}."],
			"after": ["Seit das Störsignal weg ist, flackert hier kein Licht mehr. Danke dir!"],
		},
	},
	"kenji": {
		"name": "Kenji Sato",
		"story": true,
		"look": {"skin": Color(0.88, 0.74, 0.6), "hair": Color(0.05, 0.05, 0.06), "hair_style": "cap",
			"top": Color(0.2, 0.25, 0.32), "top_style": "shirt", "pants": Color(0.22, 0.26, 0.34),
			"shoes": Color(0.15, 0.12, 0.1), "height": 1.76, "build": 1.08, "accent": Color(0.9, 0.45, 0.1)},
		"schedule": [
			{"from": 0.0, "type": "idle", "at": Vector3(44, 0, -38)},
			{"from": 7.0, "type": "idle", "at": Vector3(30, 0, -48)},
			{"from": 12.0, "type": "walk", "path": [Vector3(30, 0, -48), Vector3(18, 0, -48), Vector3(18, 0, -40)]},
			{"from": 13.0, "type": "idle", "at": Vector3(30, 0, -48)},
		],
		"lines": {
			"morning": ["Morgen! Kaffee und Kolbenringe – so fängt ein guter Tag an."],
			"day": ["Fahr mit dem Wagen in die Halle (Taste T oder Tuning-Knopf), dann schauen wir uns den Motor an."],
			"evening": ["Gute Reifen sind wichtiger als PS. Glaub mir."],
			"night": ["Eigentlich ist schon zu... aber für dich mache ich das Tor auf."],
			"after": ["Die ganze Stadt redet von dir! Die Werkstatt ist immer offen für dich."],
		},
	},
	"brandt": {
		"name": "Herr Brandt",
		"story": true,
		"look": {"skin": Color(0.72, 0.52, 0.4), "hair": Color(0.25, 0.25, 0.25), "hair_style": "short",
			"top": Color(0.85, 0.55, 0.1), "top_style": "jacket", "pants": Color(0.2, 0.22, 0.25),
			"shoes": Color(0.1, 0.1, 0.1), "height": 1.8, "build": 1.12, "accent": Color(0.85, 0.85, 0.85)},
		"schedule": [
			{"from": 0.0, "type": "idle", "at": Vector3(-58, 0, 28)},
			{"from": 10.0, "type": "walk", "path": [Vector3(-58, 0, 28), Vector3(-58, 0, 40), Vector3(-66, 0, 40)]},
			{"from": 11.0, "type": "idle", "at": Vector3(-58, 0, 28)},
		],
		"lines": {
			"morning": ["Stromnetze sind wie Straßen: Wenn eine Kreuzung blockiert, staut sich alles."],
			"day": ["Ich bin Elektriker im Viertel. Wenn irgendwo der Strom spinnt, ruft man mich."],
			"evening": ["Die Laternen springen pünktlich an – so soll es sein."],
			"night": ["Nachtschicht. Irgendwer muss ja aufpassen, dass das Licht anbleibt."],
			"after": ["Seit der Sender abgeschaltet ist, laufen die Verteiler stabil. Super Arbeit!"],
		},
	},
	"jonas": {
		"name": "Jonas",
		"story": true,
		"look": {"skin": Color(0.55, 0.38, 0.28), "hair": Color(0.08, 0.06, 0.05), "hair_style": "short",
			"top": Color(0.18, 0.18, 0.2), "top_style": "hoodie", "pants": Color(0.35, 0.33, 0.3),
			"shoes": Color(0.85, 0.2, 0.15), "height": 1.7, "build": 0.95, "accent": Color(0.3, 0.8, 0.9)},
		"schedule": [
			{"from": 0.0, "type": "idle", "at": Vector3(-36, 0, -33)},
		],
		"lines": {
			"morning": ["Ich hab die halbe Nacht Funkdaten ausgewertet. Mehr Kaffee!"],
			"day": ["Wusstest du, dass hier überall Energiezellen versteckt sind? Zwölf Stück!"],
			"evening": ["Im Park hat man den besten Empfang. Glaub ich zumindest."],
			"night": ["Psst – nachts ist das Funkrauschen am leisesten."],
			"after": ["Unser Video über das Störsignal hat schon tausend Aufrufe!"],
		},
	},
	"okafor": {
		"name": "Bürgermeisterin Dr. Okafor",
		"story": true,
		"look": {"skin": Color(0.36, 0.24, 0.18), "hair": Color(0.06, 0.05, 0.05), "hair_style": "bun",
			"top": Color(0.15, 0.2, 0.35), "top_style": "jacket", "pants": Color(0.15, 0.18, 0.3),
			"shoes": Color(0.08, 0.08, 0.08), "height": 1.74, "build": 1.0, "accent": Color(0.9, 0.9, 0.92)},
		"schedule": [
			{"from": 0.0, "type": "idle", "at": Vector3(-45, 0, 49)},
		],
		"lines": {
			"morning": ["Guten Morgen! Der Stadtrat tagt heute wieder."],
			"day": ["Unser Viertel braucht junge Leute mit Ideen."],
			"evening": ["Ein langer Tag im Rathaus. Aber ein guter."],
			"night": ["Selbst nachts brennt im Rathaus noch Licht."],
			"after": ["Dank dir bleibt der Alte Hafen ein Viertel für alle. Die Stadt ist stolz auf dich!"],
		},
	},
	"partner": {
		"name": "{partner}",
		"story": true,
		"look": {},
		"schedule": [
			{"from": 0.0, "type": "idle", "at": Vector3(-141, 0, 10.5)},
			{"from": 9.0, "type": "walk", "path": [Vector3(-141, 0, 9.0), Vector3(-160, 0, 9.0)]},
			{"from": 11.0, "type": "idle", "at": Vector3(-141, 0, 10.5)},
		],
		"lines": {
			"morning": ["Na, schon wach? Ich hab gehört, Kenji braucht Hilfe."],
			"day": ["Tipp: Mit dem Nitro-Knopf kommst du bei Rennen viel schneller ans Ziel – wenn du ihn eingebaut hast."],
			"evening": ["Speichern nicht vergessen! Pause-Menü oben rechts."],
			"night": ["Ich geh gleich schlafen. Du solltest auch..."],
			"after": ["Wir zwei haben das Viertel gerettet. Wer hätte das gedacht?"],
		},
	},
	"lena": {
		"name": "Lena (Café)",
		"story": false,
		"look": {"skin": Color(0.92, 0.78, 0.68), "hair": Color(0.85, 0.65, 0.35), "hair_style": "ponytail",
			"top": Color(0.9, 0.88, 0.82), "top_style": "shirt", "pants": Color(0.1, 0.1, 0.12),
			"shoes": Color(0.1, 0.1, 0.1), "height": 1.68, "build": 0.95, "accent": Color(0.4, 0.25, 0.15)},
		"schedule": [
			{"from": 0.0, "type": "home"},
			{"from": 6.5, "type": "idle", "at": Vector3(102, 0, -100)},
			{"from": 12.0, "type": "walk", "path": [Vector3(100, 0, -100), Vector3(128, 0, -100)]},
			{"from": 13.0, "type": "idle", "at": Vector3(102, 0, -100)},
			{"from": 21.0, "type": "home"},
		],
		"lines": {
			"morning": ["Erster Espresso des Tages? Leider nur für Erwachsene – aber Kakao geht immer!"],
			"day": ["Mittagspause! Die Leute aus dem City-Ring stürmen gleich rein."],
			"evening": ["Gleich ist Feierabend. Morgen gibt's frische Zimtschnecken."],
			"night": [""],
		},
	},
	"tom": {
		"name": "Tom (Jogger)",
		"story": false,
		"look": {"skin": Color(0.8, 0.62, 0.5), "hair": Color(0.3, 0.2, 0.1), "hair_style": "short",
			"top": Color(0.1, 0.6, 0.45), "top_style": "shirt", "pants": Color(0.1, 0.1, 0.12),
			"shoes": Color(0.95, 0.4, 0.1), "height": 1.82, "build": 0.95, "accent": Color(1, 1, 1)},
		"speed": 3.2,
		"schedule": [
			{"from": 0.0, "type": "home"},
			{"from": 6.0, "type": "walk", "loop_block": Vector2i(1, 1)},
			{"from": 10.0, "type": "home"},
			{"from": 17.0, "type": "walk", "loop_block": Vector2i(1, 1)},
			{"from": 20.5, "type": "home"},
		],
		"lines": {
			"morning": ["*keuch* Noch drei Runden um den Park!"],
			"day": ["Laufen macht den Kopf frei."],
			"evening": ["Abendrunde! Die Luft ist jetzt am besten."],
			"night": [""],
		},
	},
	"sophie": {
		"name": "Sophie",
		"story": false,
		"look": {"skin": Color(0.95, 0.82, 0.72), "hair": Color(0.12, 0.08, 0.05), "hair_style": "ponytail",
			"top": Color(0.35, 0.45, 0.65), "top_style": "hoodie", "pants": Color(0.4, 0.45, 0.55),
			"shoes": Color(0.9, 0.9, 0.9), "height": 1.63, "build": 0.9, "accent": Color(0.95, 0.8, 0.3)},
		"schedule": [
			{"from": 0.0, "type": "home"},
			{"from": 7.5, "type": "walk", "loop_block": Vector2i(2, 2)},
			{"from": 16.0, "type": "idle", "at": Vector3(-82, 0, 100)},
			{"from": 19.5, "type": "walk", "loop_block": Vector2i(1, 3)},
			{"from": 21.0, "type": "home"},
		],
		"lines": {
			"morning": ["Mathe-Test heute. Wünsch mir Glück!"],
			"day": ["Hast du den Funkturm im Gewerbehof gesehen? Der blinkt so komisch."],
			"evening": ["Am Kiosk gibt's die besten Brezeln."],
			"night": [""],
		},
	},
	"mehmet": {
		"name": "Mehmet (Kiosk)",
		"story": false,
		"look": {"skin": Color(0.78, 0.6, 0.46), "hair": Color(0.2, 0.18, 0.16), "hair_style": "short",
			"top": Color(0.55, 0.15, 0.12), "top_style": "jacket", "pants": Color(0.25, 0.25, 0.28),
			"shoes": Color(0.2, 0.15, 0.1), "height": 1.75, "build": 1.15, "accent": Color(0.95, 0.95, 0.9)},
		"schedule": [
			{"from": 0.0, "type": "home"},
			{"from": 6.0, "type": "idle", "at": Vector3(-79, 0, 100)},
			{"from": 22.5, "type": "home"},
		],
		"lines": {
			"morning": ["Frische Zeitungen! Heute: „Wieder Stromausfall im Hafenviertel?“"],
			"day": ["Wenn die Lichter flackern, läuft meine Kühltruhe nicht. Ärgerlich!"],
			"evening": ["Feierabendbrezel? Geht aufs Haus."],
			"night": ["Gleich mache ich zu. Gute Nacht!"],
		},
	},
	"pia": {
		"name": "Pia (Kurierin)",
		"story": false,
		"look": {"skin": Color(0.6, 0.42, 0.32), "hair": Color(0.1, 0.07, 0.05), "hair_style": "cap",
			"top": Color(0.95, 0.75, 0.1), "top_style": "jacket", "pants": Color(0.15, 0.15, 0.18),
			"shoes": Color(0.2, 0.2, 0.2), "height": 1.7, "build": 0.95, "accent": Color(0.1, 0.1, 0.1)},
		"speed": 2.0,
		"schedule": [
			{"from": 0.0, "type": "home"},
			{"from": 7.0, "type": "walk", "loop_block": Vector2i(3, 2)},
			{"from": 19.0, "type": "home"},
		],
		"lines": {
			"morning": ["Achtzig Pakete heute. Mindestens."],
			"day": ["Kleiner Tipp: Mit der Handbremse kommst du schneller um enge Kurven."],
			"evening": ["Letzte Tour! Dann Füße hoch."],
			"night": [""],
		},
	},
	"herr_wu": {
		"name": "Herr Wu",
		"story": false,
		"look": {"skin": Color(0.9, 0.78, 0.64), "hair": Color(0.75, 0.75, 0.75), "hair_style": "short",
			"top": Color(0.45, 0.42, 0.35), "top_style": "jacket", "pants": Color(0.35, 0.3, 0.25),
			"shoes": Color(0.2, 0.15, 0.1), "height": 1.68, "build": 1.0, "accent": Color(0.7, 0.6, 0.4)},
		"speed": 0.9,
		"schedule": [
			{"from": 0.0, "type": "home"},
			{"from": 9.0, "type": "walk", "loop_block": Vector2i(0, 1)},
			{"from": 18.0, "type": "home"},
		],
		"lines": {
			"morning": ["Früher war hier ein Fischmarkt. Lange her..."],
			"day": ["Die jungen Leute fahren heute alle so schnell. Fahr vorsichtig!"],
			"evening": ["Zeit für meinen Tee."],
			"night": [""],
		},
	},
}


static func time_slot(hour: float) -> String:
	if hour >= 5.0 and hour < 11.0:
		return "morning"
	if hour >= 11.0 and hour < 17.0:
		return "day"
	if hour >= 17.0 and hour < 21.0:
		return "evening"
	return "night"


## Aktiver Tagesablauf-Eintrag fuer eine Stunde (mit Umlauf ueber Mitternacht).
static func activity_for_hour(schedule: Array, hour: float) -> Dictionary:
	if schedule.is_empty():
		return {"type": "idle", "at": Vector3.ZERO}
	var current: Dictionary = schedule[schedule.size() - 1]
	for entry in schedule:
		if float(entry["from"]) <= hour:
			current = entry
	return current


static func path_for(entry: Dictionary) -> Array:
	if entry.has("path"):
		return entry["path"]
	if entry.has("loop_block"):
		var b: Vector2i = entry["loop_block"]
		return CityLayout.sidewalk_loop(b.x, b.y)
	return [entry.get("at", Vector3.ZERO)]


static func line_for(npc_id: String, hour: float, story_done: bool) -> String:
	var d: Dictionary = NPCS.get(npc_id, {})
	var lines: Dictionary = d.get("lines", {})
	var slot := "after" if story_done and lines.has("after") else time_slot(hour)
	var arr: Array = lines.get(slot, [])
	if arr.is_empty() or str(arr[0]) == "":
		return ""
	return arr[randi() % arr.size()]
