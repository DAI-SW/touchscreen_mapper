# Touchscreen Monitor Mapping Tool

Dieses Bash-Skript ermöglicht es dir, Touchscreen-Eingabegeräte auf bestimmte Monitore in einer Linux-Umgebung zu mappen.

## Funktionen

- Listet alle USB-Eingabegeräte im System auf
- Zeigt verfügbare Monitore und deren Einstellungen an
- Identifiziert automatisch Touchscreen-Geräte
- Ermöglicht interaktives Mapping eines Touchscreens auf einen ausgewählten Monitor
- Führt das Mapping mit `xinput map-to-output` durch

## Voraussetzungen

- Linux-Betriebssystem
- X-Server (X11) 
- Folgende Befehle müssen installiert sein:
  - `lsusb`
  - `xrandr`
  - `xinput`

## Installation

1. Speichere das Skript in einer Datei (z.B. `touchscreen_mapper.sh`)
2. Mache das Skript ausführbar:
   ```bash
   chmod +x touchscreen_mapper.sh
   ```

## Verwendung

Führe das Skript im Terminal aus:

```bash
./touchscreen_mapper.sh
```

Folge den Anweisungen auf dem Bildschirm:

1. Das Skript zeigt dir eine Liste aller verfügbaren Touchscreens an
2. Wähle den Touchscreen, den du mappen möchtest
3. Das Skript zeigt dir eine Liste aller verfügbaren Monitore an
4. Wähle den Monitor, auf den der Touchscreen gemappt werden soll
5. Das Skript führt das Mapping durch und bestätigt den erfolgreichen Abschluss

## Fehlerbehebung

Falls das Mapping nicht funktioniert:

- Stelle sicher, dass das Touchscreen-Gerät korrekt erkannt wird
- Überprüfe, ob der X-Server läuft und der Monitor korrekt erkannt wird
- Bei Multi-Monitor-Setups kann es hilfreich sein, die genaue Konfiguration mit `xrandr --verbose` zu prüfen

## Hinweis

Dieses Skript musst du nach jedem Neustart oder nach Änderungen an der Monitor-Konfiguration erneut ausführen, da die Mapping-Einstellungen nicht persistent sind.
