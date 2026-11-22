class_name MissionData
extends RefCounted
## Story-Missionen (datengetrieben). Platzhalter: {player}, {partner}.
##
## Schritt-Typen:
##   talk      – mit NPC "npc" sprechen (Dialog "lines")
##   goto      – Ort "poi" erreichen (zu Fuß oder im Auto), optional time_limit
##   drive     – Ort "poi" im Fahrzeug erreichen, optional time_limit
##   enter_car – in ein (bestimmtes) Fahrzeug einsteigen
##   race      – Checkpoints "checkpoints" im Fahrzeug innerhalb time_limit
##   delivery  – Orte "targets" der Reihe nach im Fahrzeug anfahren, time_limit
##   puzzle    – am Ort "poi" ein Rätsel lösen ("lights" oder "frequency")
## Optionale Felder je Schritt: unlock_car, radius, retry_step (Schritt, an dem
## nach Zeitüberschreitung weitergespielt wird).

const MISSIONS := [
	{
		"id": "m1_neu_im_viertel",
		"title": "Neu im Viertel",
		"giver": "rosa",
		"reward": 150,
		"summary": "Lerne das Viertel kennen und hilf Kenji in der Werkstatt.",
		"steps": [
			{"type": "talk", "npc": "rosa", "objective": "Sprich mit Frau Lindner vor eurem Haus.",
				"lines": [
					["Frau Lindner", "Ah, {player}! Willkommen im Alten Hafen. Habt ihr euch schon eingelebt?"],
					["{player}", "Fast. Die Kisten sind ausgepackt, aber ich kenne hier noch niemanden."],
					["Frau Lindner", "Dann geh zu Kenji in die Werkstatt neben dem Lindenpark. Er sucht jemanden, der anpacken kann."],
				]},
			{"type": "goto", "poi": "garage", "radius": 7.0, "objective": "Geh zu Kenjis Werkstatt (Markierung auf der Minikarte)."},
			{"type": "talk", "npc": "kenji", "objective": "Sprich mit Kenji.", "unlock_car": "car_compact",
				"lines": [
					["Kenji", "Du musst {player} sein. Frau Lindner hat angerufen."],
					["Kenji", "Ich habe einen alten Lumen K2 wieder flottgemacht. Er braucht eine Probefahrt."],
					["Kenji", "Fahr ihn zu deinem Haus und zurück in die Stadt – wenn er durchhält, gehört er dir zum Ausleihen."],
				]},
			{"type": "enter_car", "car": "car_compact", "objective": "Steig in den Lumen K2 (Aktion-Knopf neben dem Auto)."},
			{"type": "drive", "poi": "home", "radius": 9.0, "objective": "Fahre zu eurem Haus im Wohnviertel West."},
		],
		"outro": "Der Lumen K2 schnurrt wie neu. Kenji schreibt: \"Komm vorbei, ich hätte da ein Rennen für dich!\"",
	},
	{
		"id": "m2_hafenrunde",
		"title": "Die Hafenrunde",
		"giver": "kenji",
		"reward": 300,
		"summary": "Ein offizielles Zeitrennen auf abgesperrter Strecke.",
		"steps": [
			{"type": "talk", "npc": "kenji", "objective": "Sprich mit Kenji.",
				"lines": [
					["Kenji", "Heute ist die Hafenrunde – ein Zeitrennen, die Strecke ist offiziell abgesperrt."],
					["Kenji", "Fahr zur Startlinie vor der Werkstatt. Neun Checkpoints, 80 Sekunden. Schaffst du das?"],
					["{player}", "Challenge accepted!"],
				]},
			{"type": "enter_car", "car": "", "objective": "Steig in ein Fahrzeug."},
			{"type": "drive", "poi": "race_start", "radius": 8.0, "objective": "Fahre zur Startlinie an der Hauptstraße."},
			{"type": "race", "checkpoints": "RACE", "time_limit": 80.0, "radius": 10.0, "retry_step": 2, "objective": "Rennen! Fahre durch alle Checkpoints."},
		],
		"outro": "Neue Bestzeit für den Alten Hafen! Doch kaum bist du im Ziel, flackern überall die Straßenlaternen...",
	},
	{
		"id": "m3_kurzschluss",
		"title": "Kurzschluss",
		"giver": "brandt",
		"reward": 400,
		"summary": "Hilf dem Elektriker, zwei Stromverteiler wieder ins Gleichgewicht zu bringen.",
		"steps": [
			{"type": "talk", "npc": "brandt", "objective": "Sprich mit Herrn Brandt auf dem Rathausplatz.",
				"lines": [
					["Herr Brandt", "Schon wieder ein Stromausfall! Zwei Verteilerkästen sind aus dem Takt geraten."],
					["Herr Brandt", "Jemand mit flinken Fingern müsste die Sicherungen neu schalten. Jede Sicherung beeinflusst ihre Nachbarn."],
					["{player}", "Klingt nach einem Rätsel. Ich übernehme das!"],
				]},
			{"type": "puzzle", "poi": "fusebox_a", "radius": 3.0, "puzzle": "lights", "size": 3, "seed": 31, "scramble": 4,
				"prompt": "Verteilerkasten Ost reparieren", "objective": "Repariere den Verteilerkasten im Wohnviertel Ost."},
			{"type": "puzzle", "poi": "fusebox_b", "radius": 3.0, "puzzle": "lights", "size": 4, "seed": 77, "scramble": 5,
				"prompt": "Verteilerkasten City reparieren", "objective": "Repariere den Verteilerkasten im City-Ring."},
			{"type": "talk", "npc": "brandt", "objective": "Berichte Herrn Brandt.",
				"lines": [
					["Herr Brandt", "Großartig, der Strom ist zurück! Aber schau dir diese Messwerte an..."],
					["Herr Brandt", "Die Kästen wurden von außen gestört – von einem Funksignal. Das ist kein Zufall."],
				]},
		],
		"outro": "Das Licht ist zurück. Aber wer sendet das seltsame Störsignal?",
	},
	{
		"id": "m4_ersatzteile",
		"title": "Ersatzteile im Eiltempo",
		"giver": "kenji",
		"reward": 500,
		"unlock_car": "car_sport",
		"summary": "Liefere drei dringende Ersatzteile aus, bevor die Zeit abläuft.",
		"steps": [
			{"type": "talk", "npc": "kenji", "objective": "Sprich mit Kenji.",
				"lines": [
					["Kenji", "Durch den Stromausfall stehen drei Kunden ohne Ersatzteile da. Kannst du ausliefern?"],
					["Kenji", "Wenn du es in der Zeit schaffst, leihe ich dir meinen Vireo RS. Abgemacht?"],
				]},
			{"type": "enter_car", "car": "", "objective": "Steig in ein Fahrzeug."},
			{"type": "delivery", "targets": ["delivery_1", "delivery_2", "delivery_3"], "time_limit": 150.0, "radius": 8.0, "retry_step": 1,
				"objective": "Liefere die Ersatzteile aus!"},
		],
		"outro": "Alle Kunden sind glücklich. Kenji wirft dir einen Schlüssel zu: Der Vireo RS steht jetzt für dich bereit!",
	},
	{
		"id": "m5_stoersignal",
		"title": "Das Störsignal",
		"giver": "jonas",
		"reward": 1000,
		"summary": "Finde die Quelle des Störsignals und bring die Beweise ins Rathaus.",
		"steps": [
			{"type": "talk", "npc": "jonas", "objective": "Triff Jonas im Lindenpark.",
				"lines": [
					["Jonas", "Hey {player}! Ich habe das Störsignal mit meinem Funkempfänger angepeilt."],
					["Jonas", "Es kommt vom alten Funkturm im Gewerbehof. Dort hat jemand einen Sender versteckt."],
					["Jonas", "Wenn du die Frequenz triffst, können wir ihn identifizieren und die Daten aufzeichnen."],
				]},
			{"type": "goto", "poi": "radio_gate", "radius": 6.0, "objective": "Fahre zum Funkturm im Gewerbehof."},
			{"type": "puzzle", "poi": "radio_tower", "radius": 3.5, "puzzle": "frequency", "seed": 5,
				"prompt": "Sender am Schaltschrank anpeilen", "objective": "Finde die Frequenz am Schaltschrank des Funkturms."},
			{"type": "talk", "npc": "partner", "objective": "Erzähle {partner} zu Hause, was du gefunden hast.",
				"lines": [
					["{partner}", "Zeig mal! Der Sender gehört ... Graufeld Logistik? Die wollen doch das Hafengelände kaufen!"],
					["{partner}", "Wenn das Viertel unzuverlässig wirkt, wird es billig. Wir müssen das sofort der Bürgermeisterin zeigen!"],
					["{partner}", "Die Ratssitzung beginnt gleich. Beeil dich – du hast 90 Sekunden!"],
				]},
			{"type": "goto", "poi": "city_hall", "radius": 7.0, "time_limit": 90.0, "retry_step": 3, "objective": "Bring die Beweise rechtzeitig zum Rathaus!"},
			{"type": "talk", "npc": "okafor", "objective": "Sprich mit Bürgermeisterin Dr. Okafor.",
				"lines": [
					["Dr. Okafor", "Diese Aufzeichnungen sind eindeutig. Ein nicht genehmigter Sender, der unser Stromnetz stört!"],
					["Dr. Okafor", "Der Verkauf des Hafengeländes ist damit vom Tisch. Die Behörden kümmern sich um Graufeld Logistik."],
					["Dr. Okafor", "{player}, du hast dem ganzen Viertel geholfen. Danke!"],
				]},
		],
		"outro": "Der Alte Hafen bleibt ein Viertel für alle. Die Story ist abgeschlossen – erkunde die Stadt, finde alle Energiezellen und tune deine Autos!",
	},
]


static func count() -> int:
	return MISSIONS.size()


static func by_index(i: int) -> Dictionary:
	return MISSIONS[i]


static func index_of(id: String) -> int:
	for i in MISSIONS.size():
		if MISSIONS[i]["id"] == id:
			return i
	return -1


static func checkpoints_for(step: Dictionary) -> Array:
	if step.get("checkpoints", "") is String and step.get("checkpoints", "") == "RACE":
		return CityLayout.RACE_CHECKPOINTS
	if step.has("targets"):
		var out: Array = []
		for t in step["targets"]:
			out.append(CityLayout.poi(t))
		return out
	return step.get("checkpoints", [])


static func fill(text: String) -> String:
	return text.replace("{player}", GameState.character_name()).replace("{partner}", GameState.character_name(GameState.partner_id()))
