# Touchscreen Mapper Utility

Ein robustes Bash-Script zur automatischen Konfiguration und dauerhaften Zuordnung von Touchscreens zu Monitoren unter Linux/X11.

## 🎯 Features

- **Automatische Erkennung** von Touchscreen-Geräten und Monitoren
- **Multi-ID Support** - Handhabt Touchscreens mit mehreren xinput IDs automatisch
- **Persistente Konfiguration** - Einmal einrichten, dauerhaft nutzen
- **Autostart-Integration** - Automatisches Mapping beim Login
- **Robuste Geräteerkennung** über Name, Vendor ID und Product ID
- **Logging-System** zur Fehleranalyse
- **evtest Integration** für erweiterte Diagnose
- **Benutzerfreundliche Verwaltung** von Berechtigungen (root/user)

## 📋 Voraussetzungen

### Benötigte Pakete
```bash
# Debian/Ubuntu
sudo apt-get install xinput x11-xserver-utils

# Fedora
sudo dnf install xinput xrandr

# Arch Linux
sudo pacman -S xorg-xinput xorg-xrandr
```

### Optionale Pakete (für erweiterte Funktionen)
```bash
# Für Touchscreen-Tests
sudo apt-get install evtest    # Debian/Ubuntu
sudo dnf install evtest         # Fedora
sudo pacman -S evtest           # Arch
```

## 🚀 Schnellstart


### 1. Erstmalige Einrichtung
```bash
sudo ./touchscreen_mapper.sh
```
Das Script führt dich interaktiv durch:
- Erkennung aller Touchscreens
- Auswahl des gewünschten Touchscreens
- Auswahl des Zielmonitors
- Speicherung der Konfiguration
- Einrichtung des Autostarts

### 2. Fertig!
Der Touchscreen wird nun automatisch bei jedem Login korrekt zugeordnet.

## 💡 Verwendung

### Grundlegende Befehle

| Befehl | Beschreibung |
|--------|-------------|
| `./touchscreen_mapper.sh` | Interaktiver Konfigurationsmodus |
| `./touchscreen_mapper.sh --auto` | Automatisches Mapping (für Autostart) |
| `./touchscreen_mapper.sh --load` | Lädt gespeicherte Konfiguration |
| `./touchscreen_mapper.sh --remove` | Entfernt Konfiguration und Autostart |
| `./touchscreen_mapper.sh --help` | Zeigt Hilfe an |

### Erweiterte Befehle

| Befehl | Beschreibung |
|--------|-------------|
| `sudo ./touchscreen_mapper.sh --detect` | Erkennt alle IDs eines Touchscreens |
| `sudo ./touchscreen_mapper.sh --test` | Testet Touchscreens mit evtest |
| `./touchscreen_mapper.sh --show-log` | Zeigt Log-Datei an |
| `./touchscreen_mapper.sh --save` | Speichert aktuelle Konfiguration |

## 🔧 Problemlösung

### Problem: Touchscreen hat mehrere IDs

**Symptom:** Ein Touchscreen erscheint mehrfach in `xinput list` (z.B. ID 14 und 15)

**Lösung:** Das Script handhabt dies automatisch:
- Erkennt alle IDs eines Geräts
- Mappt alle IDs auf den Monitor
- Nur die aktive ID wird funktionieren 

```bash
# Diagnose
sudo ./touchscreen_mapper.sh --detect

# Ausgabe zeigt alle IDs
# Geben Sie ein: WingCool Inc. TouchScreen
# Gefunden: WingCool Inc. TouchScreen (ID: 14)
# Gefunden: WingCool Inc. TouchScreen (ID: 15)
```

### Problem: Mapping funktioniert nach Neustart nicht

**Mögliche Ursachen:**
1. IDs haben sich geändert
2. Autostart wurde nicht korrekt eingerichtet
3. X11 ist noch nicht bereit

**Lösungen:**
```bash
# Logs prüfen
./touchscreen_mapper.sh --show-log

# Manuell testen
./touchscreen_mapper.sh --auto

# Konfiguration neu erstellen
sudo ./touchscreen_mapper.sh
```

### Problem: "Permission denied" Fehler

**Lösung:** Für manche Funktionen sind root-Rechte nötig:
```bash
# Für evtest und Geräteerkennung
sudo ./touchscreen_mapper.sh

# Für normales Mapping reicht Benutzer-Modus
./touchscreen_mapper.sh --load
```

## 📁 Dateispeicherorte

| Datei | Pfad | Beschreibung |
|-------|------|--------------|
| Konfiguration | `~/.config/touchscreen-mapper/config` | Gespeicherte Touchscreen-Einstellungen |
| Autostart | `~/.config/autostart/touchscreen-mapper.desktop` | Desktop-Datei für automatischen Start |
| Logs | `/tmp/touchscreen-mapper.log` | Debug- und Fehler-Logs |

## 🎮 Beispiel-Szenarien

### Szenario 1: Laptop mit externem Touchscreen-Monitor

```bash
# 1. Externen Monitor anschließen
# 2. Script ausführen
sudo ./touchscreen_mapper.sh

# 3. Wählen Sie:
#    [0] WingCool Inc. TouchScreen
#    [1] eDP-1 (interner Laptop-Bildschirm)
#    [2] HDMI-1 (externer Touchscreen)

# 4. Touchscreen 0 auf Monitor 2 mappen
# 5. Konfiguration speichern
```

### Szenario 2: Multi-Monitor Setup mit festem Touchscreen

```bash
# Einmalige Konfiguration
sudo ./touchscreen_mapper.sh

# Bei Monitor-Wechsel neu konfigurieren
sudo ./touchscreen_mapper.sh --remove
sudo ./touchscreen_mapper.sh
```

### Szenario 3: Debugging bei Problemen

```bash
# 1. Alle Touchscreens anzeigen
xinput list | grep -i touch

# 2. IDs analysieren
sudo ./touchscreen_mapper.sh --detect

# 3. Einzelne Geräte testen
sudo ./touchscreen_mapper.sh --test

# 4. Logs prüfen
./touchscreen_mapper.sh --show-log
```

## 🔍 Technische Details

### Wie funktioniert das Multi-ID Handling?

Manche Touchscreens registrieren mehrere xinput-Geräte:
- Eine ID für Touch-Events
- Eine ID für Pen/Stylus-Events
- Manchmal zusätzliche IDs für Gesten

Das Script:
1. Erkennt alle IDs mit gleichem Namen
2. Mappt alle IDs auf den Zielmonitor
3. Nur die aktive ID verarbeitet Events
4. Inaktive IDs stören nicht

### Autostart-Mechanismus

Die `.desktop` Datei nutzt:
- `X-GNOME-Autostart-Delay=3` - Wartet bis X11 bereit ist
- `--auto` Flag - Robustes Mapping aller passenden Geräte
- Fallback auf Vendor/Product ID wenn Namen sich ändern

### Unterstützte Desktop-Umgebungen

- ✅ GNOME
- ✅ KDE Plasma
- ✅ XFCE
- ✅ MATE
- ✅ Cinnamon
- ⚠️ Wayland (xinput funktioniert nur unter X11)

## 🤝 Beitragen

Verbesserungsvorschläge und Bug-Reports sind willkommen!

### Bekannte Limitierungen

- Funktioniert nur unter X11 (nicht Wayland)
- Benötigt xinput und xrandr
- Root-Rechte für evtest-Funktionen
- Touchscreen muss als xinput-Gerät erkannt werden

## 📜 Lizenz

Dieses Script ist Open Source und kann frei verwendet, modifiziert und weitergegeben werden.

## 🆘 Support

Bei Problemen:
1. Prüfen Sie die Logs: `./touchscreen_mapper.sh --show-log`
2. Führen Sie Diagnose aus: `sudo ./touchscreen_mapper.sh --detect`
3. Stellen Sie sicher, dass alle Voraussetzungen installiert sind
4. Öffnen Sie ein Issue mit der Ausgabe der Diagnose-Befehle

---

**Version:** 3.0  
**Autor:** [Dieter Aichberger]  
**Letzte Aktualisierung:** 2025
