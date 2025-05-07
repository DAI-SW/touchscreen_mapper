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

### Interaktiver Modus

Führe das Skript ohne Parameter im Terminal aus:

```bash
./touchscreen_mapper.sh
```

Folge den Anweisungen auf dem Bildschirm:

1. Das Skript zeigt dir eine Liste aller verfügbaren Touchscreens an
2. Wähle den Touchscreen, den du mappen möchtest
3. Das Skript zeigt dir eine Liste aller verfügbaren Monitore an
4. Wähle den Monitor, auf den der Touchscreen gemappt werden soll
5. Das Skript führt das Mapping durch und bestätigt den erfolgreichen Abschluss
6. Du kannst wählen, ob du die Konfiguration dauerhaft speichern möchtest

### Kommandozeilenoptionen

Das Skript unterstützt folgende Optionen:

- `-h, --help`: Zeigt die Hilfe an
- `-l, --load`: Lädt und wendet die gespeicherte Konfiguration an
- `-s, --save`: Führt das Mapping durch und speichert die Konfiguration automatisch
- `-r, --remove`: Entfernt die gespeicherte Konfiguration und den Autostart-Eintrag

## Fehlerbehebung

Falls das Mapping nicht funktioniert:

- Stelle sicher, dass das Touchscreen-Gerät korrekt erkannt wird
- Überprüfe, ob der X-Server läuft und der Monitor korrekt erkannt wird
- Bei Multi-Monitor-Setups kann es hilfreich sein, die genaue Konfiguration mit `xrandr --verbose` zu prüfen

## Persistente Konfiguration

Das Skript speichert nun den Hardware-Namen des Touchscreens statt der dynamischen Geräte-ID. Das bietet mehrere Vorteile:

- Zuverlässigere Konfiguration über Neustarts hinweg
- Das Mapping funktioniert auch dann, wenn sich die Geräte-IDs ändern
- Bessere Kompatibilität mit verschiedenen X-Server-Konfigurationen

Das Skript bietet zwei Möglichkeiten, das Mapping dauerhaft zu speichern:

1. **Während der Ausführung**: Am Ende des interaktiven Modus kannst du wählen, ob du die Konfiguration speichern möchtest
2. **Mit der Option `--save`**: Das Mapping wird ausgeführt und automatisch gespeichert

Wenn du die Konfiguration speicherst:
- Es wird eine Konfigurationsdatei unter `~/.config/touchscreen-mapper/config` erstellt
- Ein Autostart-Eintrag wird unter `~/.config/autostart/touchscreen-mapper.desktop` erstellt
- Das Mapping wird automatisch bei jedem Login angewendet

### Konfiguration laden oder entfernen

- Um die gespeicherte Konfiguration manuell anzuwenden: `./touchscreen_mapper.sh --load`
- Um die gespeicherte Konfiguration zu entfernen: `./touchscreen_mapper.sh --remove`

## Hinweis

Wenn sich deine Monitor-Konfiguration ändert (z.B. anderer Monitor oder geänderte Auflösung), musst du möglicherweise die Konfiguration neu erstellen. Verwende dazu die Option `--remove` und führe das Skript dann neu aus.
