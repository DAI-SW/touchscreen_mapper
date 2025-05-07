#!/bin/bash

# Titel des Skripts
echo "====================================="
echo "   Touchscreen Mapping Utility"
echo "====================================="
echo ""

# Konfigurationsdatei-Pfad
CONFIG_DIR="$HOME/.config/touchscreen-mapper"
CONFIG_FILE="$CONFIG_DIR/config"
AUTOSTART_DIR="$HOME/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/touchscreen-mapper.desktop"

# Funktion zum Anzeigen der Hilfe
show_help() {
    echo "Verwendung: $0 [OPTIONEN]"
    echo ""
    echo "Optionen:"
    echo "  -h, --help               Zeigt diese Hilfe an"
    echo "  -l, --load               Lädt die gespeicherte Konfiguration"
    echo "  -s, --save               Speichert die Konfiguration für den Autostart"
    echo "  -r, --remove             Entfernt die gespeicherte Konfiguration"
    echo ""
    exit 0
}

# Funktion zum Finden eines Touchscreen-Geräts anhand seines Namens
find_touchscreen_by_name() {
    local search_name="$1"
    local device_id=""
    
    # Durchsuche alle xinput-Geräte nach dem Namen
    while read -r line; do
        local name=$(echo "$line" | awk -F'↳' '{print $2}' | awk -F'id=' '{print $1}' | xargs)
        local id=$(echo "$line" | awk -F'id=' '{print $2}' | awk '{print $1}')
        
        # Überprüfe, ob der Name übereinstimmt (teilweise Übereinstimmung ist ausreichend)
        if [[ "$name" == *"$search_name"* ]]; then
            device_id="$id"
            break
        fi
    done < <(xinput list | grep -i "touchscreen")
    
    echo "$device_id"
}

# Verarbeite Befehlszeilenargumente
if [ $# -gt 0 ]; then
    case "$1" in
        -h|--help)
            show_help
            ;;
        -l|--load)
            if [ -f "$CONFIG_FILE" ]; then
                echo "Lade gespeicherte Konfiguration..."
                source "$CONFIG_FILE"
                
                # Führe das Mapping mit den gespeicherten Werten durch
                if [ -n "$TOUCH_NAME" ] && [ -n "$MONITOR_NAME" ]; then
                    # Finde die aktuelle Geräte-ID anhand des gespeicherten Namens
                    TOUCH_ID=$(find_touchscreen_by_name "$TOUCH_NAME")
                    
                    if [ -n "$TOUCH_ID" ]; then
                        xinput map-to-output $TOUCH_ID $MONITOR_NAME
                        echo "Touchscreen '$TOUCH_NAME' (ID: $TOUCH_ID) erfolgreich auf Monitor $MONITOR_NAME gemappt!"
                        exit 0
                    else
                        echo "Fehler: Touchscreen '$TOUCH_NAME' nicht gefunden."
                        echo "Verfügbare Touchscreens:"
                        xinput list | grep -i "touchscreen"
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
            # Diese Option wird später im Skript behandelt
            SAVE_CONFIG=true
            ;;
        *)
            echo "Unbekannte Option: $1"
            show_help
            ;;
    esac
fi

# Ausgabe aller USB-Geräte
echo "===== USB-Eingabegeräte ====="
lsusb
echo ""

# Ausgabe aller Monitore mit xrandr
echo "===== Verfügbare Monitore ====="
xrandr --listmonitors
echo ""

# Ausgabe detaillierter Informationen über Eingabegeräte
echo "===== Detaillierte Eingabegeräte ====="
xinput list
echo ""

# Touchscreen-Geräte identifizieren
echo "===== Touchscreen-Geräte ====="
touchscreens=$(xinput list | grep -i "touchscreen" | awk -F'id=' '{print $2}' | awk '{print $1}')
if [ -z "$touchscreens" ]; then
    echo "Keine Touchscreen-Geräte gefunden!"
else
    xinput list | grep -i "touchscreen"
fi
echo ""

# Interaktive Mapping-Funktion
map_touch_to_monitor() {
    local touch_id=$1
    local monitor=$2
    
    echo "Mappe Touchscreen ID $touch_id auf Monitor $monitor..."
    
    # Hole die Koordinaten des ausgewählten Monitors
    coords=$(xrandr | grep "$monitor" | grep -o "[0-9]*x[0-9]*+[0-9]*+[0-9]*")
    
    if [ -z "$coords" ]; then
        echo "Fehler: Konnte die Koordinaten des Monitors nicht ermitteln."
        return 1
    fi
    
    # Extrahiere die Werte
    width=$(echo $coords | cut -d'x' -f1)
    rest=$(echo $coords | cut -d'x' -f2)
    height=$(echo $rest | cut -d'+' -f1)
    x_offset=$(echo $rest | cut -d'+' -f2)
    y_offset=$(echo $rest | cut -d'+' -f3)
    
    # Setze die Transformation für den Touchscreen
    xinput map-to-output $touch_id $monitor
    
    echo "Touchscreen erfolgreich gemapped!"
    echo "Koordinaten: ${width}x${height}+${x_offset}+${y_offset}"
}

# Liste der Monitore erstellen für die Auswahl
declare -a monitors
readarray -t monitors < <(xrandr --listmonitors | tail -n +2 | awk '{print $4}')

# Interaktiver Dialog
echo "===== Touchscreen Mapping ====="
echo ""

# Touchscreen-Auswahl
if [ -z "$touchscreens" ]; then
    echo "Keine Touchscreens gefunden. Beende Programm."
    exit 1
fi

echo "Verfügbare Touchscreens:"
touch_count=0
declare -a touch_ids
declare -a touch_names
while read -r line; do
    touch_id=$(echo $line | awk -F'id=' '{print $2}' | awk '{print $1}')
    touch_name=$(echo $line | awk -F'↳' '{print $2}' | awk -F'id=' '{print $1}' | xargs)
    # Hardware-Name mit xinput list-props erhalten
    device_info=$(xinput list-props $touch_id | grep "Device Node" || echo "")
    device_node=$(echo "$device_info" | grep -o '"/dev/[^"]*"' | tr -d '"' || echo "")
    
    # Sicherere Gerätename-Ermittlung
    hw_name=$(echo "$touch_name" | awk '{$1=$1};1')
    
    echo "[$touch_count] $touch_name (ID: $touch_id)"
    if [ -n "$device_node" ]; then
        echo "    Device Node: $device_node"
    fi
    
    touch_ids[$touch_count]=$touch_id
    touch_names[$touch_count]=$hw_name
    touch_count=$((touch_count + 1))
done < <(xinput list | grep -i "touchscreen")

# Wenn mehr als ein Touchscreen verfügbar ist, lasse den Benutzer wählen
selected_touch=0
if [ $touch_count -gt 1 ]; then
    echo ""
    echo "Bitte wählen Sie den zu mappenden Touchscreen (0-$((touch_count-1))):"
    read selected_touch
    
    # Validierung der Eingabe
    while ! [[ "$selected_touch" =~ ^[0-9]+$ ]] || [ "$selected_touch" -ge "$touch_count" ]; do
        echo "Ungültige Auswahl. Bitte wählen Sie einen Wert zwischen 0 und $((touch_count-1)):"
        read selected_touch
    done
fi

# Monitor-Auswahl
echo ""
echo "Verfügbare Monitore:"
for i in "${!monitors[@]}"; do
    echo "[$i] ${monitors[$i]}"
done

echo ""
echo "Bitte wählen Sie den Monitor, auf den der Touchscreen gemappt werden soll (0-$((${#monitors[@]}-1))):"
read selected_monitor

# Validierung der Eingabe
while ! [[ "$selected_monitor" =~ ^[0-9]+$ ]] || [ "$selected_monitor" -ge "${#monitors[@]}" ]; do
    echo "Ungültige Auswahl. Bitte wählen Sie einen Wert zwischen 0 und $((${#monitors[@]}-1)):"
    read selected_monitor
done

# Mapping durchführen
map_touch_to_monitor "${touch_ids[$selected_touch]}" "${monitors[$selected_monitor]}"

# Speichern der Konfiguration wenn gewünscht
TOUCH_ID="${touch_ids[$selected_touch]}"
TOUCH_NAME="${touch_names[$selected_touch]}"
MONITOR_NAME="${monitors[$selected_monitor]}"

# Frage nach dem Speichern der Konfiguration, wenn nicht mit --save aufgerufen
if [ "$SAVE_CONFIG" != "true" ]; then
    echo ""
    echo "Möchtest du diese Konfiguration dauerhaft speichern? (j/n)"
    read save_answer
    if [[ "$save_answer" =~ ^[Jj] ]]; then
        SAVE_CONFIG=true
    fi
fi

# Konfiguration speichern, wenn gewünscht
if [ "$SAVE_CONFIG" = "true" ]; then
    # Erstelle Konfigurationsverzeichnis, falls es nicht existiert
    mkdir -p "$CONFIG_DIR"
    
    # Schreibe Konfigurationsdatei
    cat > "$CONFIG_FILE" << EOF
# Touchscreen Mapper Konfiguration
# Automatisch erstellt am $(date)
TOUCH_NAME="$TOUCH_NAME"
MONITOR_NAME="$MONITOR_NAME"
EOF

    echo "Konfiguration gespeichert in $CONFIG_FILE"
    
    # Erstelle Autostart-Eintrag
    mkdir -p "$AUTOSTART_DIR"
    
    # Ermittle den absoluten Pfad des Skripts
    SCRIPT_PATH=$(readlink -f "$0")
    
    cat > "$AUTOSTART_FILE" << EOF
[Desktop Entry]
Type=Application
Name=Touchscreen Mapper
Comment=Mappt den Touchscreen auf den richtigen Monitor
Exec=$SCRIPT_PATH --load
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
EOF

    echo "Autostart-Eintrag erstellt in $AUTOSTART_FILE"
    echo "Das Mapping wird automatisch beim nächsten Login angewendet."
fi

echo ""
echo "====================================="
echo "   Mapping abgeschlossen"
echo "====================================="
