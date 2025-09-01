#!/bin/bash

# Titel des Skripts
echo "====================================="
echo "   Touchscreen Mapping Utility v3.0"
echo "====================================="
echo ""

# Prüfe ob als root ausgeführt wird
if [ "$EUID" -eq 0 ]; then 
   # Wenn als root ausgeführt, hole den tatsächlichen Benutzer
   REAL_USER="${SUDO_USER:-$USER}"
   REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
   echo "Script wird als root ausgeführt. Benutzer: $REAL_USER"
else
   REAL_USER="$USER"
   REAL_HOME="$HOME"
fi

# Konfigurationsdatei-Pfade mit korrektem Benutzerverzeichnis
CONFIG_DIR="$REAL_HOME/.config/touchscreen-mapper"
CONFIG_FILE="$CONFIG_DIR/config"
AUTOSTART_DIR="$REAL_HOME/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/touchscreen-mapper.desktop"
LOG_FILE="/tmp/touchscreen-mapper.log"

# Logging-Funktion
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Funktion zum Anzeigen der Hilfe
show_help() {
    echo "Verwendung: $0 [OPTIONEN]"
    echo ""
    echo "Optionen:"
    echo "  -h, --help               Zeigt diese Hilfe an"
    echo "  -l, --load               Lädt die gespeicherte Konfiguration"
    echo "  -s, --save               Speichert die Konfiguration für den Autostart"
    echo "  -r, --remove             Entfernt die gespeicherte Konfiguration"
    echo "  -t, --test               Testet Touchscreen mit evtest"
    echo "  -d, --detect             Erkennt automatisch den funktionierenden Touchscreen"
    echo "  -a, --auto               Automatischer Modus für Autostart (mappt alle passenden IDs)"
    echo "  --show-log               Zeigt die Log-Datei an"
    echo ""
    exit 0
}

# Funktion zum Mappen aller IDs eines Touchscreens
map_all_matching_touchscreens() {
    local search_name="$1"
    local search_vendor="$2"
    local search_product="$3"
    local monitor="$4"
    local mapped_count=0
    
    log_message "Suche nach Touchscreens mit Namen: '$search_name', Vendor: '$search_vendor', Product: '$search_product'"
    
    # Methode 1: Suche nach Namen
    if [ -n "$search_name" ]; then
        while read -r line; do
            local name=$(echo "$line" | sed 's/.*↳ *//' | sed 's/[[:space:]]*id=.*//')
            local id=$(echo "$line" | grep -o 'id=[0-9]*' | cut -d= -f2)
            
            if [[ "$name" == *"$search_name"* ]]; then
                log_message "Gefunden: '$name' mit ID $id"
                
                if [ "$EUID" -eq 0 ]; then
                    su - "$REAL_USER" -c "DISPLAY=:0 xinput map-to-output $id $monitor" 2>/dev/null
                else
                    xinput map-to-output $id $monitor 2>/dev/null
                fi
                
                if [ $? -eq 0 ]; then
                    echo "✓ Touchscreen ID $id auf Monitor $monitor gemappt"
                    log_message "Erfolgreich gemappt: ID $id -> $monitor"
                    mapped_count=$((mapped_count + 1))
                else
                    echo "✗ Fehler beim Mapping von ID $id"
                    log_message "Fehler beim Mapping von ID $id"
                fi
            fi
        done < <(xinput list 2>/dev/null | grep -i "touchscreen\|touch")
    fi
    
    # Methode 2: Suche nach Vendor/Product ID (zusätzlich oder alternativ)
    if [ -n "$search_vendor" ] && [ -n "$search_product" ] && [ $mapped_count -eq 0 ]; then
        log_message "Keine Geräte über Namen gefunden, suche über Vendor/Product ID"
        
        while read -r line; do
            local id=$(echo "$line" | grep -o 'id=[0-9]*' | cut -d= -f2)
            
            local props=""
            if [ "$EUID" -eq 0 ]; then
                props=$(su - "$REAL_USER" -c "DISPLAY=:0 xinput list-props $id" 2>/dev/null)
            else
                props=$(xinput list-props "$id" 2>/dev/null)
            fi
            
            local device_vendor=$(echo "$props" | grep "Device Product ID" | grep -o '[0-9]*, [0-9]*' | cut -d, -f1 | tr -d ' ')
            local device_product=$(echo "$props" | grep "Device Product ID" | grep -o '[0-9]*, [0-9]*' | cut -d, -f2 | tr -d ' ')
            
            if [ "$device_vendor" = "$search_vendor" ] && [ "$device_product" = "$search_product" ]; then
                log_message "Gefunden über Vendor/Product: ID $id"
                
                if [ "$EUID" -eq 0 ]; then
                    su - "$REAL_USER" -c "DISPLAY=:0 xinput map-to-output $id $monitor" 2>/dev/null
                else
                    xinput map-to-output $id $monitor 2>/dev/null
                fi
                
                if [ $? -eq 0 ]; then
                    echo "✓ Touchscreen ID $id auf Monitor $monitor gemappt (via Vendor/Product)"
                    log_message "Erfolgreich gemappt: ID $id -> $monitor (via Vendor/Product)"
                    mapped_count=$((mapped_count + 1))
                fi
            fi
        done < <(xinput list 2>/dev/null | grep -i "touchscreen\|touch")
    fi
    
    # Methode 3: USB-Geräteerkennung für noch robustere Identifikation
    if [ -n "$search_vendor" ] && [ -n "$search_product" ] && command -v lsusb &> /dev/null; then
        local usb_device=$(lsusb | grep -i "${search_vendor}:${search_product}" 2>/dev/null)
        if [ -n "$usb_device" ]; then
            log_message "USB-Gerät gefunden: $usb_device"
        fi
    fi
    
    return $mapped_count
}

# Funktion für automatischen Modus (für Autostart)
auto_mode() {
    echo "===== Automatischer Mapping-Modus ====="
    log_message "Starte automatischen Mapping-Modus"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Fehler: Keine Konfigurationsdatei gefunden!"
        log_message "Fehler: Keine Konfigurationsdatei gefunden"
        exit 1
    fi
    
    # Lade Konfiguration
    source "$CONFIG_FILE"
    
    # Warte kurz, bis alle Geräte initialisiert sind (wichtig beim Boot)
    sleep 2
    
    echo "Lade Konfiguration für: $TOUCH_NAME"
    log_message "Lade Konfiguration für: $TOUCH_NAME"
    
    # Mappe ALLE passenden Touchscreen-IDs
    map_all_matching_touchscreens "$TOUCH_NAME" "$TOUCH_VENDOR" "$TOUCH_PRODUCT" "$MONITOR_NAME"
    mapped=$?
    
    if [ $mapped -gt 0 ]; then
        echo "✓ $mapped Touchscreen(s) erfolgreich gemappt"
        log_message "Erfolgreich: $mapped Touchscreen(s) gemappt"
        
        # Optional: Verifizierung nach dem Mapping
        sleep 1
        echo "Aktuelle Touchscreen-Konfiguration:"
        if [ "$EUID" -eq 0 ]; then
            su - "$REAL_USER" -c "DISPLAY=:0 xinput list" | grep -i "$TOUCH_NAME"
        else
            xinput list | grep -i "$TOUCH_NAME"
        fi
    else
        echo "✗ Keine Touchscreens konnten gemappt werden"
        log_message "Fehler: Keine Touchscreens konnten gemappt werden"
        
        # Fallback: Versuche es nach kurzer Wartezeit erneut
        echo "Warte 3 Sekunden und versuche erneut..."
        sleep 3
        map_all_matching_touchscreens "$TOUCH_NAME" "$TOUCH_VENDOR" "$TOUCH_PRODUCT" "$MONITOR_NAME"
        if [ $? -gt 0 ]; then
            echo "✓ Erfolgreich beim zweiten Versuch"
            log_message "Erfolgreich beim zweiten Versuch"
        else
            log_message "Fehler auch beim zweiten Versuch"
            exit 1
        fi
    fi
}

# Funktion zum Testen mit evtest
test_touchscreen() {
    if [ "$EUID" -ne 0 ]; then
        echo "evtest benötigt root-Rechte. Bitte mit sudo ausführen."
        return 1
    fi
    
    # Prüfe ob evtest installiert ist
    if ! command -v evtest &> /dev/null; then
        echo "evtest ist nicht installiert. Installiere es mit:"
        echo "  sudo apt-get install evtest  # Debian/Ubuntu"
        echo "  sudo dnf install evtest      # Fedora"
        echo "  sudo pacman -S evtest        # Arch"
        return 1
    fi
    
    echo "===== Touchscreen Test mit evtest ====="
    echo "Verfügbare Input-Geräte:"
    echo ""
    
    # Liste alle /dev/input/event* Geräte
    for device in /dev/input/event*; do
        if [ -e "$device" ]; then
            name=$(cat /sys/class/input/$(basename $device)/device/name 2>/dev/null || echo "Unbekannt")
            echo "$device: $name"
        fi
    done
    
    echo ""
    echo "Wählen Sie das zu testende Gerät (z.B. /dev/input/event5) oder 'q' zum Beenden:"
    read selected_device
    
    if [ "$selected_device" = "q" ]; then
        return 0
    fi
    
    if [ -e "$selected_device" ]; then
        echo "Teste $selected_device - Berühren Sie den Touchscreen (Strg+C zum Beenden)..."
        evtest "$selected_device"
    else
        echo "Gerät $selected_device nicht gefunden."
    fi
}

# Funktion zum Erkennen aller IDs eines Touchscreens
detect_touchscreen_ids() {
    local touch_name="$1"
    local ids=()
    
    echo "Suche alle IDs für '$touch_name'..."
    
    while read -r line; do
        if [[ "$line" == *"$touch_name"* ]]; then
            local id=$(echo "$line" | grep -o 'id=[0-9]*' | cut -d= -f2)
            local name=$(echo "$line" | sed 's/.*↳ *//' | sed 's/[[:space:]]*id=.*//')
            ids+=($id)
            echo "  Gefunden: $name (ID: $id)"
            
            # Teste ob diese ID Events liefert
            if [ "$EUID" -eq 0 ]; then
                echo -n "    Teste ID $id... "
                timeout 1 su - "$REAL_USER" -c "DISPLAY=:0 xinput test $id" 2>/dev/null | grep -q "button\|motion" && echo "✓ aktiv" || echo "✗ inaktiv"
            fi
        fi
    done < <(xinput list)
    
    echo "Gefundene IDs: ${ids[@]}"
    return ${#ids[@]}
}

# Verarbeite Befehlszeilenargumente
if [ $# -gt 0 ]; then
    case "$1" in
        -h|--help)
            show_help
            ;;
        -t|--test)
            test_touchscreen
            exit 0
            ;;
        -d|--detect)
            echo "Suche nach Touchscreens..."
            xinput list | grep -i "touchscreen\|touch"
            echo ""
            echo "Geben Sie den Namen des Touchscreens ein (z.B. 'WingCool Inc. TouchScreen'):"
            read touch_name
            detect_touchscreen_ids "$touch_name"
            exit 0
            ;;
        -a|--auto)
            auto_mode
            exit 0
            ;;
        --show-log)
            if [ -f "$LOG_FILE" ]; then
                echo "===== Touchscreen Mapper Log ====="
                tail -n 50 "$LOG_FILE"
            else
                echo "Keine Log-Datei gefunden."
            fi
            exit 0
            ;;
        -l|--load)
            if [ -f "$CONFIG_FILE" ]; then
                echo "Lade gespeicherte Konfiguration..."
                source "$CONFIG_FILE"
                
                # Im Load-Modus: Mappe ALLE passenden IDs
                if [ -n "$TOUCH_NAME" ] && [ -n "$MONITOR_NAME" ]; then
                    echo "Mappe alle IDs für '$TOUCH_NAME' auf Monitor $MONITOR_NAME..."
                    map_all_matching_touchscreens "$TOUCH_NAME" "$TOUCH_VENDOR" "$TOUCH_PRODUCT" "$MONITOR_NAME"
                    
                    if [ $? -gt 0 ]; then
                        echo "✓ Touchscreen(s) erfolgreich gemappt!"
                        exit 0
                    else
                        echo "✗ Fehler: Keine passenden Touchscreens gefunden."
                        echo "Verfügbare Touchscreens:"
                        xinput list | grep -i "touchscreen\|touch"
                        exit 1
                    fi
                else
                    echo "Fehler: Unvollständige Konfigurationsdatei."
                    exit 1
                fi
            else
                echo "Keine gespeicherte Konfiguration gefunden."
                echo "Führe interaktiven Modus aus..."
                echo ""
            fi
            ;;
        -r|--remove)
            if [ -f "$CONFIG_FILE" ]; then
                rm "$CONFIG_FILE"
                echo "Konfigurationsdatei entfernt."
            fi
            if [ -f "$AUTOSTART_FILE" ]; then
                rm "$AUTOSTART_FILE"
                echo "Autostart-Eintrag entfernt."
            fi
            exit 0
            ;;
        -s|--save)
            SAVE_CONFIG=true
            ;;
        *)
            echo "Unbekannte Option: $1"
            show_help
            ;;
    esac
fi

# === INTERAKTIVER MODUS ===

# Ausgabe aller USB-Geräte
echo "===== USB-Eingabegeräte ====="
lsusb
echo ""

# Ausgabe aller Monitore mit xrandr
echo "===== Verfügbare Monitore ====="
if [ "$EUID" -eq 0 ]; then
    su - "$REAL_USER" -c "DISPLAY=:0 xrandr --listmonitors"
else
    xrandr --listmonitors
fi
echo ""

# Ausgabe detaillierter Informationen über Eingabegeräte
echo "===== Detaillierte Eingabegeräte ====="
if [ "$EUID" -eq 0 ]; then
    su - "$REAL_USER" -c "DISPLAY=:0 xinput list"
else
    xinput list
fi
echo ""

# Touchscreen-Geräte identifizieren
echo "===== Touchscreen-Geräte ====="
if [ "$EUID" -eq 0 ]; then
    touch_list=$(su - "$REAL_USER" -c "DISPLAY=:0 xinput list" | grep -i "touchscreen\|touch")
else
    touch_list=$(xinput list | grep -i "touchscreen\|touch")
fi

if [ -z "$touch_list" ]; then
    echo "Keine Touchscreen-Geräte gefunden!"
    exit 1
else
    echo "$touch_list"
fi
echo ""

# Liste der Monitore erstellen
declare -a monitors
if [ "$EUID" -eq 0 ]; then
    readarray -t monitors < <(su - "$REAL_USER" -c "DISPLAY=:0 xrandr --listmonitors" | tail -n +2 | awk '{print $4}')
else
    readarray -t monitors < <(xrandr --listmonitors | tail -n +2 | awk '{print $4}')
fi

# Gruppiere Touchscreens nach Namen
declare -A touch_groups
declare -a unique_names
unique_count=0

while read -r line; do
    touch_name=$(echo "$line" | sed 's/.*↳ *//' | sed 's/[[:space:]]*id=.*//')
    touch_id=$(echo "$line" | grep -o 'id=[0-9]*' | cut -d= -f2)
    
    if [ -n "$touch_name" ] && [ -n "$touch_id" ]; then
        if [ -z "${touch_groups[$touch_name]}" ]; then
            touch_groups[$touch_name]="$touch_id"
            unique_names[$unique_count]="$touch_name"
            unique_count=$((unique_count + 1))
        else
            touch_groups[$touch_name]="${touch_groups[$touch_name]} $touch_id"
        fi
    fi
done <<< "$touch_list"

# Zeige eindeutige Touchscreen-Geräte
echo "===== Touchscreen Mapping ====="
echo ""
echo "Verfügbare Touchscreen-Geräte:"

for i in "${!unique_names[@]}"; do
    name="${unique_names[$i]}"
    ids=(${touch_groups[$name]})
    
    echo "[$i] $name"
    if [ ${#ids[@]} -gt 1 ]; then
        echo "    ⚠ Mehrere IDs gefunden: ${ids[@]}"
        echo "    ℹ Alle IDs werden gemappt (nur die aktive wird funktionieren)"
    else
        echo "    ID: ${ids[0]}"
    fi
    
    # Sammle Geräteinformationen von der ersten ID
    touch_id=${ids[0]}
    if [ "$EUID" -eq 0 ]; then
        device_info=$(su - "$REAL_USER" -c "DISPLAY=:0 xinput list-props $touch_id" 2>/dev/null)
    else
        device_info=$(xinput list-props $touch_id 2>/dev/null)
    fi
    
    device_node=$(echo "$device_info" | grep "Device Node" | grep -o '"/dev/[^"]*"' | tr -d '"')
    product_info=$(echo "$device_info" | grep "Device Product ID" | grep -o '[0-9]*, [0-9]*')
    vendor=$(echo "$product_info" | cut -d, -f1 | tr -d ' ')
    product=$(echo "$product_info" | cut -d, -f2 | tr -d ' ')
    
    if [ -n "$device_node" ]; then
        echo "    Device Node: $device_node"
    fi
    if [ -n "$vendor" ] && [ -n "$product" ]; then
        echo "    Vendor/Product: $vendor/$product"
    fi
done

# Touchscreen-Auswahl
selected_touch=0
if [ $unique_count -gt 1 ]; then
    echo ""
    echo "Bitte wählen Sie den zu mappenden Touchscreen (0-$((unique_count-1))):"
    read selected_touch
    
    while ! [[ "$selected_touch" =~ ^[0-9]+$ ]] || [ "$selected_touch" -ge "$unique_count" ]; do
        echo "Ungültige Auswahl. Bitte wählen Sie einen Wert zwischen 0 und $((unique_count-1)):"
        read selected_touch
    done
fi

TOUCH_NAME="${unique_names[$selected_touch]}"
TOUCH_IDS=(${touch_groups[$TOUCH_NAME]})

# Sammle Vendor/Product Info
if [ "$EUID" -eq 0 ]; then
    device_info=$(su - "$REAL_USER" -c "DISPLAY=:0 xinput list-props ${TOUCH_IDS[0]}" 2>/dev/null)
else
    device_info=$(xinput list-props ${TOUCH_IDS[0]} 2>/dev/null)
fi

product_info=$(echo "$device_info" | grep "Device Product ID" | grep -o '[0-9]*, [0-9]*')
TOUCH_VENDOR=$(echo "$product_info" | cut -d, -f1 | tr -d ' ')
TOUCH_PRODUCT=$(echo "$product_info" | cut -d, -f2 | tr -d ' ')

# Monitor-Auswahl
echo ""
echo "Verfügbare Monitore:"
for i in "${!monitors[@]}"; do
    echo "[$i] ${monitors[$i]}"
done

echo ""
echo "Bitte wählen Sie den Monitor, auf den der Touchscreen gemappt werden soll (0-$((${#monitors[@]}-1))):"
read selected_monitor

while ! [[ "$selected_monitor" =~ ^[0-9]+$ ]] || [ "$selected_monitor" -ge "${#monitors[@]}" ]; do
    echo "Ungültige Auswahl. Bitte wählen Sie einen Wert zwischen 0 und $((${#monitors[@]}-1)):"
    read selected_monitor
done

MONITOR_NAME="${monitors[$selected_monitor]}"

# Mapping durchführen - mappe ALLE IDs
echo ""
echo "Mappe Touchscreen '$TOUCH_NAME' auf Monitor $MONITOR_NAME..."

success_count=0
for id in "${TOUCH_IDS[@]}"; do
    echo -n "  Mappe ID $id... "
    if [ "$EUID" -eq 0 ]; then
        su - "$REAL_USER" -c "DISPLAY=:0 xinput map-to-output $id $MONITOR_NAME" 2>/dev/null
    else
        xinput map-to-output $id $MONITOR_NAME 2>/dev/null
    fi
    
    if [ $? -eq 0 ]; then
        echo "✓"
        success_count=$((success_count + 1))
    else
        echo "✗"
    fi
done

if [ $success_count -gt 0 ]; then
    echo ""
    echo "✓ $success_count von ${#TOUCH_IDS[@]} IDs erfolgreich gemappt!"
    if [ ${#TOUCH_IDS[@]} -gt 1 ]; then
        echo "ℹ Bei mehreren IDs ist nur die aktive funktionsfähig - das ist normal."
    fi
else
    echo "✗ Fehler: Keine IDs konnten gemappt werden!"
fi

# Test nach dem Mapping
echo ""
echo "Bitte testen Sie den Touchscreen auf dem ausgewählten Monitor."
echo "Funktioniert das Mapping korrekt? (j/n)"
read mapping_works

if [[ ! "$mapping_works" =~ ^[Jj] ]]; then
    echo "Bitte überprüfen Sie die Konfiguration oder nutzen Sie --detect zur Fehlersuche."
fi

# Speichern der Konfiguration
if [ "$SAVE_CONFIG" != "true" ]; then
    echo ""
    echo "Möchten Sie diese Konfiguration dauerhaft speichern? (j/n)"
    read save_answer
    if [[ "$save_answer" =~ ^[Jj] ]]; then
        SAVE_CONFIG=true
    fi
fi

if [ "$SAVE_CONFIG" = "true" ]; then
    # Erstelle Konfigurationsverzeichnis
    if [ "$EUID" -eq 0 ]; then
        su - "$REAL_USER" -c "mkdir -p '$CONFIG_DIR'"
    else
        mkdir -p "$CONFIG_DIR"
    fi
    
    # Schreibe Konfigurationsdatei
    config_content="# Touchscreen Mapper Konfiguration
# Automatisch erstellt am $(date)
# Gerät: $TOUCH_NAME
# Monitor: $MONITOR_NAME
# Gefundene IDs: ${TOUCH_IDS[@]}

TOUCH_NAME=\"$TOUCH_NAME\"
TOUCH_VENDOR=\"$TOUCH_VENDOR\"
TOUCH_PRODUCT=\"$TOUCH_PRODUCT\"
MONITOR_NAME=\"$MONITOR_NAME\"
# Alle IDs werden beim Autostart gemappt
TOUCH_ALL_IDS=\"${TOUCH_IDS[@]}\""
    
    if [ "$EUID" -eq 0 ]; then
        echo "$config_content" | su - "$REAL_USER" -c "cat > '$CONFIG_FILE'"
    else
        echo "$config_content" > "$CONFIG_FILE"
    fi
    
    echo "Konfiguration gespeichert in $CONFIG_FILE"
    
    # Erstelle Autostart-Eintrag
    if [ "$EUID" -eq 0 ]; then
        su - "$REAL_USER" -c "mkdir -p '$AUTOSTART_DIR'"
    else
        mkdir -p "$AUTOSTART_DIR"
    fi
    
    # Ermittle den absoluten Pfad des Skripts
    SCRIPT_PATH=$(readlink -f "$0")
    
    # Desktop-Datei mit --auto Flag für robustes Mapping
    desktop_content="[Desktop Entry]
Type=Application
Name=Touchscreen Mapper
Comment=Mappt den Touchscreen auf den richtigen Monitor
Exec=$SCRIPT_PATH --auto
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
StartupNotify=false
X-GNOME-Autostart-Delay=3"
    
    if [ "$EUID" -eq 0 ]; then
        echo "$desktop_content" | su - "$REAL_USER" -c "cat > '$AUTOSTART_FILE'"
        su - "$REAL_USER" -c "chmod 644 '$AUTOSTART_FILE'"
    else
        echo "$desktop_content" > "$AUTOSTART_FILE"
        chmod 644 "$AUTOSTART_FILE"
    fi
    
    echo "Autostart-Eintrag erstellt in $AUTOSTART_FILE"
    echo ""
    echo "ℹ Der Autostart verwendet den --auto Modus:"
    echo "  - Mappt automatisch ALLE passenden Touchscreen-IDs"
    echo "  - Funktioniert auch wenn sich IDs ändern"
    echo "  - Nutzt Produkterkennung für robuste Identifikation"
    echo "  - Log-Datei: $LOG_FILE"
    echo ""
    echo "Das Mapping wird automatisch beim nächsten Login angewendet."
fi

echo ""
echo "====================================="
echo "   Mapping abgeschlossen"
echo "====================================="
echo ""
echo "Tipps:"
echo "- Logs anzeigen: $0 --show-log"
echo "- Manueller Test: $0 --auto"
echo "- Fehlersuche: sudo $0 --detect"
