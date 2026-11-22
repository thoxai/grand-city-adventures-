# Architektur

## Grundprinzipien

1. **Datengetrieben.** Missionen (`MissionData`), NPCs (`NpcData`), Fahrzeuge/Tuning (`TuningData`) und das
   Stadtlayout (`CityLayout`) sind reine Daten mit statischen Helfern. Neue Missionen oder NPCs entstehen
   durch Einträge, nicht durch neuen Code.
2. **Logik getrennt von Darstellung.** Rätsel (`PuzzleLogic`), Missionsablauf (`MissionManager`) und
   Spielzustand (`GameState`) kennen keine UI und sind einzeln testbar. Der `MissionManager` fragt die Welt
   nur über ein kleines Interface ab (`get_player_position`, `is_in_vehicle`, `current_car_id`, `get_npc`) –
   in den Unit-Tests ersetzt eine Attrappe die 3D-Szene.
3. **Ein Steuerungspfad.** Touch, Tastatur und Gamepad lösen dieselben Input-Aktionen aus (`InputSetup`
   registriert sie zur Laufzeit; `TouchControls` nutzt `Input.action_press`). Spieler- und Fahrzeugcode lesen
   nur Aktionen.
4. **Mobil zuerst.** Mobile-Renderer, Gebäude/Requisiten/Bäume/Laternen als MultiMesh, zusammengefasste
   Figuren- und Fahrzeug-Meshes, Sichtweiten-LOD, Licht-Pool statt hunderter Lampen-Lichter.

## Szenenbaum zur Laufzeit

```
Main (main.gd)
├── City (CityBuilder)        Boden-Shader, MultiMeshes, Labels, WorldCollision (ein StaticBody3D)
├── DayNight (DayNightCycle)  Sonne/Mond, WorldEnvironment, Pool aus 6 OmniLights
├── CameraRig                 SpringArm3D → Camera3D
├── MissionManager            + MissionMarkers (Lichtsäulen, Ringe)
├── Jobs (JobManager)         Taxi-/Lieferjobs, Fahrgast-Figur, Paket-Depot, eigene Markierung
├── HUD (CanvasLayer)         UIRoot → HUD-Ebene, Touch, Minikarte, Dialog, Menüs, Panels
├── Player                    CharacterBody3D + HumanoidModel
├── car_compact, car_sport    CharacterBody3D (Car) + CarModel + EngineAudio
├── TrafficLights             21 Ampelkreuzungen (MultiMeshes + Kollision der Masten)
├── Traffic (TrafficManager)  steuert Flitzer_0 … Flitzer_40 (Carsharing, Taxis, Busse – alle Car)
├── NPC_* (42)                CharacterBody3D (Npc) + HumanoidModel (12 Figuren + 30 Passanten)
└── Cell_* (12)               Energiezellen
```

## Module

| Modul | Aufgabe |
|---|---|
| `GameState` (Autoload) | Geld, Figur, erledigte Missionen, freigeschaltete Autos, Tuning, Sammelobjekte, Uhrzeit; `to_dict/from_dict` |
| `SaveSystem` (Autoload) | JSON-Speicherstand mit Version; Welt-Snapshot per registriertem Callable |
| `InputSetup` (Autoload) | Eingabeaktionen für Tastatur und Gamepad |
| `CityLayout` | Straßenraster, Blocktypen, benannte Orte (POIs), Checkpoints, Geometrie-Helfer |
| `CityBuilder` | Erzeugt Stadt deterministisch (Seed), sammelt Kollisionen und Minikarten-Daten |
| `MeshFactory` | Primitive, Material-Cache, `Batch` (fasst Meshes mit Vertex-Farben zu einer Oberfläche zusammen) |
| `DayNightCycle` | Lichtstimmung aus der Uhrzeit, Shader-Parameter für Fenster/Laternen |
| `Player`, `CameraRig`, `HumanoidModel` | Laufen/Sprinten/Springen relativ zur Kamera, Gelenk-Animation |
| `Car`, `CarModel`, `EngineAudio` | Arcade-Fahrphysik, Fahrzeugmodell, prozeduraler Motorsound |
| `TrafficManager` | Verkehrs-KI: Kreuzungsgraph, Spurpunkte, Bézier-Abbiegen, Abstandsregel, Neueinsetzen, Übernahme durch Spieler, Dichte je Qualitätsstufe |
| `JobManager` | Nebenjobs: Ziele am Straßenrand, Abhol-/Abgabe-Logik (Anhalten), Lohn/Trinkgeld, Pausieren während Story-Missionen |
| `TrafficLights` | Ampelphasen je Kreuzung (rein zeitbasiert, statisch testbar), Darstellung als MultiMeshes |
| `Horn` | Erzeugt den Hupton einmalig als AudioStreamWAV (läuft auch im Web) |
| `Npc` | Tagesablauf (idle/walk/home), Dialog-Zustand, Ausweichen vor Autos, Simulation nur in Kameranähe |
| `MissionManager` | Schrittautomat: talk, goto, drive, enter_car, race, delivery, puzzle; Timer und Wiederholung |
| `PuzzleLogic` | Sicherungs-Rätsel (garantiert lösbar, mit Tipp) und Frequenz-Rätsel |
| `Hud` & UI | HUD, Touch-Steuerung, Minikarte (einmal in Textur gerendert), Dialoge, Menüs, Tuning, Rätsel |

## Fahrphysik (Car.simulate)

1. Lenkwinkel nähert sich dem Eingabewert; Lenkbereich wird mit steigender Geschwindigkeit kleiner.
2. Gierrate = Lenkwinkel × Lenkrate × min(1, |v|/5) – im Stand dreht das Auto nicht.
3. Geschwindigkeit wird in Längs- (vf) und Queranteil (vl) zerlegt (nach der Drehung → Drift entsteht natürlich).
4. Motor wirkt auf vf mit abnehmender Kraft nahe der Höchstgeschwindigkeit; Bremsen, Rückwärtsgang, Rollwiderstand.
5. Reifengrip dämpft vl; Handbremse senkt den Grip auf 22 % → kontrolliertes Driften.
6. `move_and_slide()`; seitliche Kollisionen mit hoher Aufprallgeschwindigkeit dämpfen das Tempo (kein Schaden).

## Straßenverkehr

- Das Straßenraster ist ein 5 × 5-Kreuzungsgraph. Ein Auto kennt seine Startkreuzung, Richtung und die bereits
  gewählte nächste Richtung (so kann es vor dem Abbiegen bremsen).
- Auf dem Segment peilt es einen Punkt 9 m voraus auf der rechten Spur an; an der Haltelinie (10 m vor der
  Kreuzungsmitte) folgt es einer quadratischen Bézierkurve, deren Kontrollpunkt der Schnittpunkt von Ein- und
  Ausfahrspur ist.
- Gesteuert wird über dieselbe `Car.simulate()`-Physik wie beim Spieler (externe Eingaben). Deshalb kann der
  Spieler jedes Verkehrsauto nahtlos übernehmen.
- Ampeln: Vor der Haltelinie fragt das Auto `TrafficLights.state(kreuzung, achse)`; bei Rot (oder Gelb mit
  ausreichendem Bremsweg) hält es an der Haltelinie und wechselt erst bei Grün in die Abbiegekurve.
- Abstandsregel: Hindernisse in einem 2,4 m breiten Korridor vor dem Auto bremsen es; gemessen wird der Abstand
  zwischen den Fahrzeugenden (Erkennung 5 m + 1,4 s × Tempo, Halt bei < 2,5 m).
  KI-Autos kollidieren untereinander nicht physikalisch; nach 4 s gegenseitigem Blockieren ignorieren sie sich
  kurz – aber nur im Kreuzungsbereich, damit Ampel-Schlangen intakt bleiben. Blockiert der Spieler, hupt die KI.

## Passanten

`NpcData.generate_pedestrians()` erzeugt per Seed 30 Passanten: Aussehen aus Farbpaletten, Größe und Statur,
Gehtempo, Rundweg um einen zufälligen Block (Abstand 1,6–2,4 m vom Bordstein, Richtung und Startecke variieren)
und Tagesrhythmus. `NpcData.all_npcs()` liefert Story-Figuren und Passanten gemeinsam.

Jeder dritte Passant läuft stattdessen um zwei benachbarte Blocks (`NpcData.pair_route`) und quert dabei die
Straße dazwischen zweimal – genau auf den Zebrastreifen 9 m vor der Kreuzungsmitte. An den beiden Bordstein-
Punkten wartet er, bis die Autos dieser Straße Rot haben und die Querrichtung gerade Grün bekommen hat (dann
reicht die Zeit sicher). Auf der Fahrbahn zählt er für die Verkehrs-KI als Hindernis.

## Gewaltfreies Design

- Keine Waffen, kein Schaden, keine Polizeijagden.
- Verkehrsautos halten vor dem Spieler und anderen Hindernissen an.
- NPCs kollidieren nicht mit Autos: Sie springen rechtzeitig zur Seite; selbst wenn nicht, fährt das Auto
  durch sie hindurch, ohne Reaktion.
- Konflikte der Story werden durch Recherche, Technik und Beweise gelöst (Funkpeilung → Bürgermeisterin).

## Erweitern

- **Neue Mission**: Eintrag in `MissionData.MISSIONS` (Auftraggeber = NPC-ID) – Test `test_full_story_completable` prüft sie automatisch mit.
- **Neuer NPC**: Eintrag in `NpcData.NPCS` mit `look`, `schedule`, `lines`; Wege werden von `test_npc_routes_are_free` geprüft.
- **Neues Auto**: Eintrag in `TuningData.CARS` und Spawnpunkt in `CityLayout.POIS`.
- **Echte 3D-Modelle**: `HumanoidModel.build()` bzw. `CarModel.build()` durch das Instanziieren einer GLB-Szene ersetzen; die Animations-Schnittstelle (`animate`, `update_visuals`, `set_lights`) beibehalten.
