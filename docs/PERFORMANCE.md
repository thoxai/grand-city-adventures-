# Performance-Ziel und Budget

## Referenzgerät

**Samsung Galaxy A54 5G** (Exynos 1380, Mali-G68 MP5, 6 GB RAM, 2340 × 1080, Android 13+, Vulkan 1.1) –
ein verbreitetes Mittelklasse-Smartphone. Ziel: **mindestens 30 FPS** in der Qualitätsstufe „Mittel“.

## Budget pro Frame

| Größe | Budget | Gemessen* |
|---|---|---|
| Draw-Calls (inkl. Schatten und UI) | ≤ 180 | 88 – 160 |
| Primitive (Dreiecke) | ≤ 200 000 | 136 000 – 166 000 |
| Schattenwerfende Lichter | 1 (Sonne, 2 Kaskaden, 80 m) | 1 |
| Dynamische Punktlichter | ≤ 8 | 6 (nur nachts) + 1 Scheinwerfer |
| 3D-Auflösung | 85 % (Mittel) | – |

\* Mit `tools/run_screenshots.sh` (Godot 4.5.1, Mobile-Renderer, 1280 × 720) in 17 Referenzszenen gemessen,
mit 28 Verkehrsautos, 2 Bussen, 21 Ampelkreuzungen und 42 NPCs (Qualität „Mittel“).
Die FPS-Werte dieser Messung sind **nicht aussagekräftig**, weil in der Entwicklungsumgebung nur ein
Software-Renderer (lavapipe, CPU) verfügbar war. Eine Messung auf dem Referenzgerät steht noch aus.

## Maßnahmen

- **Mobile-Renderer** (Vulkan Mobile), ETC2/ASTC-Texturkompression, keine Texturen (prozedurale Shader).
- **MultiMesh**: alle 181 Gebäude (davon ~85 begehbare im Viertel, Rest Skyline) in einem Draw-Call (Fassaden-Shader mit Fenstern), dazu je ein Draw-Call für
  Requisiten, Baumstämme, Baumkronen, Laternenmasten und Leuchtenköpfe.
- **Batching** von Figuren (11 Meshes je Figur, davon 5 ohne Schatten) und Autos (5 Oberflächen + 4 Räder).
- **Figuren in drei Stufen**: < 18 m animierte Einzelteile (11 Meshes), 18–60 m die ganze Figur als EIN Mesh
  in Ruhepose (ohne Schatten), 60–140 m eine einfache Silhouette. Damit bleiben 42 NPCs bezahlbar.
- **Ampeln**: 72 Ampelköpfe als drei MultiMeshes (Masten, Gehäuse, Leuchten); Farben werden nur beim
  Phasenwechsel aktualisiert.
- **Minikarte**: Fahrzeuge als Rechtecke statt Kreise – Rechtecke bündelt Godot zu einem Draw-Call
  (mit Kreisen kostete das UI 75 statt 42 Draw-Calls).
- **Verkehrsautos**: nah (< 20 m) 5 Oberflächen + 4 drehende Räder; fern nur 2 Oberflächen (Lack als
  Vertex-Farbe, alle Leuchten in einem Shader), ohne Schatten, ab 170 m unsichtbar. Keine echten
  Scheinwerfer-Lichter für den Verkehr (nur leuchtende Flächen); nur das eigene Auto hat ein SpotLight.
  Verkehrsdichte je Qualitätsstufe: 16 / 28 / 36 (+ 2 Busse).
- **LOD**: Figuren ab 35 m als einzelne Silhouette, ab 140 m unsichtbar; Kennzeichen ab 15 m ausgeblendet.
- **Simulation nur in der Nähe**: NPCs weiter als 110 m von der Kamera werden nicht simuliert – außer sie stehen
  gerade auf der Fahrbahn (sonst würde der Verkehr dort ewig warten).
- **Licht-Pool**: Statt 192 Laternenlichtern wandern 6 OmniLights alle 0,5 s zu den nächsten Laternen.
- **UI**: Minikarte einmal in eine Textur gerendert (1 statt ~200 Zeichenbefehle).
- **Qualitätsstufen** (Menü): Niedrig (70 % Auflösung, keine Schatten/Glow/Nebel), Mittel (85 %, Schatten 80 m),
  Hoch (100 %, MSAA 2×, Schatten 130 m). FPS-/Draw-Call-Anzeige im Pause-Menü zuschaltbar.

## Selbst messen

```bash
GODOT=/pfad/zu/godot tools/run_screenshots.sh     # Screenshots + Draw-Calls je Szene
```

`tools/perf_probe.tscn` schlüsselt Draw-Calls nach Gruppen auf (UI, Schatten, NPCs, Autos, Stadt).
Auf dem Gerät: Pause-Menü → „FPS-Anzeige an/aus“.
