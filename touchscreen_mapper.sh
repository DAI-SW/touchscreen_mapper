#!/bin/bash

# Titel des Skripts
echo "====================================="
echo "   Touchscreen Mapping Utility"
echo "====================================="
echo ""

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
while read -r line; do
    touch_id=$(echo $line | awk -F'id=' '{print $2}' | awk '{print $1}')
    touch_name=$(echo $line | awk -F'↳' '{print $2}' | awk -F'id=' '{print $1}')
    echo "[$touch_count] $touch_name (ID: $touch_id)"
    touch_ids[$touch_count]=$touch_id
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

echo ""
echo "====================================="
echo "   Mapping abgeschlossen"
echo "====================================="
