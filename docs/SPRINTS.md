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
4. Ampeln und Vorfahrtsregeln für den Verkehr, Hupe, Verkehrsgeräusche.
5. Speichern von Missions-Zwischenständen.
6. Web- und iOS-Build.
