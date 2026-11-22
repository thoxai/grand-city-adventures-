# Entwicklung in sechs Sprints

Jeder Sprint endet mit einem lauffähigen Stand; Tests wachsen mit.

| Sprint | Ziel | Ergebnis (Module) |
|---|---|---|
| **1 – Fundament** | Projekt, Stadt, Figur, Kamera, Touch | `project.godot` (Mobile-Renderer, Querformat), `InputSetup`, `CityLayout`, `CityBuilder`, Boden-/Fassaden-Shader, `MeshFactory`, `Player`, `HumanoidModel`, `CameraRig`, `TouchControls` |
| **2 – Fahrzeuge** | Zwei fahrbare Autos | `Car` (Arcade-Physik, Drift, Handbremse, Kollisionsdämpfung), `CarModel`, `EngineAudio`, Ein-/Aussteigen mit freier Ausstiegsposition, Fahrzeugkamera |
| **3 – Missionen & UI** | Fünf Missionen spielbar | `MissionData`, `MissionManager` (7 Schritttypen, Timer, Wiederholung), `PuzzleLogic`, `PuzzlePanel`, `Hud` (Ziele, Timer, Dialoge, Abschluss), `Minimap`, Missionsmarker |
| **4 – Leben in der Stadt** | NPCs mit Alltag und Story | `NpcData` (12 NPCs), `Npc` (Tagesablauf, Dialoge, Ausweichen), Partnerfigur (Alex/Mia), Story-Dialoge |
| **5 – Atmosphäre & Fortschritt** | Tag/Nacht, Tuning, Speichern | `DayNightCycle`, Laternen-Licht-Pool, `TuningData`, `TuningPanel`, `GameState`, `SaveSystem`, Energiezellen, Autosave |
| **6 – Qualität & Release-Vorbereitung** | Stabil, schnell, dokumentiert | Mesh-Batching (Draw-Calls −75 %), Minikarte als Textur, Qualitätsstufen, 74 Tests inkl. KI-Fahrer, CI-Workflow, Screenshots, Export-Vorlagen, Doku |

| **7 – Mehr Action: Verkehr & Carsharing** | Belebte Straßen, sofort Autofahren | `TrafficManager` (Spurführung, Bézier-Abbiegen, Abstandsregel, Patt-Auflösung, Neueinsetzen außer Sicht), drei Carsharing-Modelle (Mini, Limousine, Transporter), Übernahme jedes Verkehrsautos, geparkter CityFlitzer vor der Haustür, Kamera-Wackeln bei Aufprall, Fern-LOD für Autos, Web-Audio-Fix, 6 neue Tests |

| **8 – Stadtleben** | Mehr Fahrzeuge, Ampeln, Hupe, mehr NPCs | `TrafficLights` (21 Kreuzungen), KI hält an Rot, Rotlicht-Hinweis, `Horn` (prozeduraler Hupton) mit Reaktionen von Passanten und KI, Taxis und Stadtbusse, 30 generierte Passanten, Sprechblasen, Figuren-LOD in drei Stufen, 8 neue Tests |

| **9 – Nebenjobs & Zebrastreifen** | Wiederholbare Geldquelle, lebendigere Straßen | `JobManager` (Taxi-Job mit Fahrpreis/Trinkgeld, Lieferjob am Paket-Depot), Job-Ziele in HUD und Minikarte, Job-Statistik im Spielstand, Passanten-Routen über Zebrastreifen mit Ampelregel, Verkehr hält für Fußgänger, Haltelinie vor dem Zebrastreifen, Skriptfehler-Erkennung im Test-Runner, 9 neue Tests |

## Erkenntnisse aus Sprint 9

- Der Test-Runner hatte eine echte Lücke: Ein GDScript-Laufzeitfehler bricht die Testfunktion ab, sie gilt aber
  als bestanden. Jetzt zählt ein `Logger` (Godot 4.5) Skriptfehler pro Test; die Komplett-Suite enthielt zum
  Glück keine versteckten Fehler.
- Die gelegentlichen „Hänger“ ließen sich nur reproduzieren, wenn Godot unter `timeout … | grep` lief – nie bei
  direktem Aufruf (z. B. `tools/run_tests.sh`, 10+ Läufe). Sie liegen damit sehr wahrscheinlich an der
  Prozess-/Pipe-Konstellation der Entwicklungsumgebung, nicht am Spiel. Zur Sicherheit gibt es einen Watchdog.
- KI-Autos standen mit der Front auf dem Zebrastreifen; Haltepunkt von 10 auf 13 m verlegt.
- Mehrere Test-Fehlschläge lagen an Testannahmen (Kamera folgt weich, NPC-Simulationsradius) – im Spiel war
  das Verhalten korrekt.

## Erkenntnisse aus Sprint 8

- Abstandsregel überarbeitet: Erkennungsbereich war bei Schritttempo kürzer als der Halteabstand – Autos krochen
  ruckelnd an Hindernisse heran. Jetzt wird zwischen den Fahrzeugenden gemessen (wichtig für 10,5 m lange Busse).
- Ein übernommener CityFlitzer wurde von der KI weiter als KI-Auto behandelt (keine Hupe, Patt-Regel) – behoben.
- Patt-Auflösung nur noch im Kreuzungsbereich, sonst wären Autos in Ampel-Schlangen durch den Vordermann gefahren.
- Der Test-Runner blieb bei einer Test-Datei mit Syntaxfehler stehen (erklärt einen früheren Hänger) – meldet sie jetzt als Fehler.
- Draw-Calls trotz mehr Inhalt gesunken (max. 155): Figuren-LOD und batchbare Minikarten-Symbole.

## Erkenntnisse aus Sprint 7

- Spieler-Feedback: „Man kann nur mit der Person durch die leere Stadt laufen.“ Ursache: Autofahren war erst nach
  dem ersten Story-Gespräch möglich und schwer zu entdecken.
- 14 Autos wirkten auf 3,6 km Fahrspur zu leer; mit 20 Autos und Fern-LOD bleibt das Draw-Call-Budget im Rahmen.
- Browser-Test zeigte zwei echte Probleme: Gespräche hatten immer Vorrang vor dem Einsteigen (jetzt gewinnt das
  nähere Ziel), und der prozedurale Motorsound brauchte im Web Stream- statt Sample-Wiedergabe.

## Erkenntnisse aus Sprint 6

- Erste Messung: 400–960 Draw-Calls pro Frame. Ursache waren nicht Gebäude (die waren schon als MultiMesh
  gebündelt), sondern ~27 Einzel-Meshes pro Figur, ~40 pro Auto und das UI.
- Maßnahmen: `MeshFactory.Batch` (Vertex-Farben, eine Oberfläche pro Gelenk/Material), Minikarte als
  vorgerenderte Textur, Text-Konturen nur wo nötig, Godot 4.5 (2D-Batching).
- Ergebnis: 73–137 Draw-Calls in allen Referenzszenen.
- Ein Fehler im eigenen Test-Runner (asynchrones `before_each` wurde nicht abgewartet) wurde durch einen
  scheinbar zufälligen Missionsabbruch sichtbar und behoben.

## Nächste Schritte (nach dem MVP)

1. Echte Figuren-/Fahrzeugmodelle (GLB, Skinning, Animationen) im bestehenden Interface.
2. Messung auf dem Referenzgerät, ggf. Feintuning der Qualitätsstufen.
3. Musik/Soundeffekte, haptisches Feedback.
4. Vorfahrt beim Linksabbiegen, grüne Welle, Bushaltestellen mit Fahrgästen, Verkehrsgeräusche, weitere Job-Arten.
5. Speichern von Missions-Zwischenständen.
6. Web- und iOS-Build.
