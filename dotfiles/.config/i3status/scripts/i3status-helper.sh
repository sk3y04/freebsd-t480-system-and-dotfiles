#!/bin/sh

# i3status helper script for FreeBSD 14
# Continuously updates temp files that i3status reads

# Temp files directory
TEMP_DIR="/tmp"
KEYBOARD_FILE="$TEMP_DIR/i3status_keyboard"
MEDIA_FILE="$TEMP_DIR/i3status_media"
BACKLIGHT_FILE="$TEMP_DIR/i3status_backlight"
NETWORK_FILE="$TEMP_DIR/i3status_network"
BATTERY_FILE="$TEMP_DIR/i3status_battery"
AUDIO_FILE="$TEMP_DIR/i3status_audio"
PING_FILE="$TEMP_DIR/i3status_ping"
RAM_FILE="$TEMP_DIR/i3status_ram"
TEMPERATURE_FILE="$TEMP_DIR/i3status_temperature"

# Configuration - adjust for your preferences
PING_HOST="freebsd.org"
FAST_UPDATE_INTERVAL=1 # seconds for most updates
SLOW_UPDATE_INTERVAL=30 # seconds for ping update

# Update functions
update_keyboard() {
    layout=$(setxkbmap -query 2>/dev/null | awk '/layout/{print $2}' | cut -c1-2 | tr '[:lower:]' '[:upper:]')
    echo "${layout:-US}" > "$KEYBOARD_FILE"
}

update_media() {
    if command -v playerctl >/dev/null 2>&1; then
        player_status=$(playerctl status 2>/dev/null || echo "Stopped")
        media_artist=$(playerctl metadata artist 2>/dev/null || echo "Unknown")
        media_song=$(playerctl metadata title 2>/dev/null || echo "Unknown")
        case "$player_status" in
            Playing) echo "▶ $media_artist - $media_song" > "$MEDIA_FILE" ;;
            Paused)  echo "⏸ $media_artist - $media_song" > "$MEDIA_FILE" ;;
            *)       echo "⏹ No media" > "$MEDIA_FILE" ;;
        esac
    else
        echo "⏹ playerctl N/A" > "$MEDIA_FILE"
    fi
}

update_battery() {
    # Use acpiconf on FreeBSD
    if command -v acpiconf >/dev/null 2>&1; then
        percent=""
        state=""
        for bid in 0 1; do
            info=$(acpiconf -i "$bid" 2>/dev/null) || continue
            percent=$(echo "$info" | awk '/Remaining capacity/ {print $3}')
            state=$(echo "$info" | awk '/State:/ {print $2}')
            [ -n "$percent" ] && break
        done
        if [ -n "$percent" ]; then
            # percent already includes %; normalize possible missing sign
            case "$percent" in *%) ;; *) percent="${percent}%" ;; esac
            echo "$percent" > "$BATTERY_FILE"
        else
            echo "N/A" > "$BATTERY_FILE"
        fi
    else
        echo "N/A" > "$BATTERY_FILE"
    fi
}

update_audio() {
    if command -v pactl >/dev/null 2>&1; then
        # Get the default sink volume using pactl
        volume_info=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null)
        
        if [ -n "$volume_info" ]; then
            # Extract percentage from output like "Volume: front-left: 65536 /  100% / 0.00 dB,   front-right: 65536 /  100% / 0.00 dB"
            percentage=$(echo "$volume_info" | grep -oE '[0-9]+%' | head -1 | tr -d '%')
            
            if [ -n "$percentage" ] && [ "$percentage" -ge 0 ] 2>/dev/null; then
                echo "${percentage}%" > "$AUDIO_FILE"
            else
                echo "N/A" > "$AUDIO_FILE"
            fi
        else
            echo "N/A" > "$AUDIO_FILE"
        fi
    else
        echo "N/A" > "$AUDIO_FILE"
    fi
}

update_ram() {
    # Get memory statistics from sysctl on FreeBSD
    total_mem=$(sysctl -n hw.physmem)
    free_mem=$(sysctl -n vm.stats.vm.v_free_count)
    inactive_mem=$(sysctl -n vm.stats.vm.v_inactive_count 2>/dev/null || echo "0")
    cache_mem=$(sysctl -n vm.stats.vm.v_cache_count 2>/dev/null || echo "0")
    page_size=$(sysctl -n hw.pagesize)
    
    if [ -n "$total_mem" ] && [ -n "$free_mem" ] && [ -n "$page_size" ]; then
        # Calculate memory in bytes
        free_bytes=$((free_mem * page_size))
        inactive_bytes=$((inactive_mem * page_size))
        cache_bytes=$((cache_mem * page_size))
        
        # Calculate available memory (free + inactive + cache)
        # This gives a more realistic view similar to htop
        available_bytes=$((free_bytes + inactive_bytes + cache_bytes))
        
        # Calculate actually used memory
        used_bytes=$((total_mem - available_bytes))
        
        # Calculate percentage based on actually used memory
        used_percent=$((used_bytes * 100 / total_mem))
        
        # Convert to human readable format with decimal precision like htop
        # Convert to MB first for better precision
        used_mb=$((used_bytes / 1024 / 1024))
        total_mb=$((total_mem / 1024 / 1024))
        
        # Format with decimal precision
        if [ "$used_mb" -ge 1024 ]; then
            used_gb_decimal=$((used_mb * 100 / 1024))
            used_display="${used_gb_decimal%??}.${used_gb_decimal#*${used_gb_decimal%??}}G"
        else
            used_display="${used_mb}M"
        fi
        
        total_gb_decimal=$((total_mb * 100 / 1024))
        total_display="${total_gb_decimal%??}.${total_gb_decimal#*${total_gb_decimal%??}}G"
        
        echo "${used_display}/${total_display} (${used_percent}%)" > "$RAM_FILE"
    else
        echo "N/A" > "$RAM_FILE"
    fi
}

update_ping() {
    if command -v ping >/dev/null 2>&1; then
        # FreeBSD ping format contains time=XX.X ms
        ms=$(ping -c 1 "$PING_HOST" 2>/dev/null | awk -F'time=' '/time=/{print $2}' | cut -d' ' -f1 | cut -d'.' -f1)
        if [ -n "$ms" ]; then
            echo "${ms}ms" > "$PING_FILE"
        else
            echo "∞ms" > "$PING_FILE"
        fi
    else
        echo "N/A" > "$PING_FILE"
    fi
}

update_backlight() {
    if command -v backlight >/dev/null 2>&1; then
        # Extract brightness value
        level=$(backlight 2>/dev/null | cut -d' ' -f2)
        if [ -n "$level" ]; then
            echo "${level}%" > "$BACKLIGHT_FILE"
        else
            echo "N/A" > "$BACKLIGHT_FILE"
        fi
    else
        echo "N/A" > "$BACKLIGHT_FILE"
    fi
}

update_temperature() {
    # Get CPU temperature from first available core
    temp=$(sysctl -n dev.cpu.0.temperature 2>/dev/null | sed 's/C$//' | cut -d. -f1)
    
    if [ -n "$temp" ] && [ "$temp" -gt 0 ] 2>/dev/null; then
        echo "${temp}°C" > "$TEMPERATURE_FILE"
    else
        echo "N/A" > "$TEMPERATURE_FILE"
    fi
}

update_network() {
    if command -v ifconfig >/dev/null 2>&1; then
        # Find active interface
        interface=""
        for iface in em0 re0 wlan0; do
            if ifconfig "$iface" 2>/dev/null | grep -q "status: active\|status: associated"; then
                interface="$iface"
                break
            fi
        done
        
        if [ -n "$interface" ]; then
            if echo "$interface" | grep -q "wlan"; then
                ssid=$(ifconfig "$interface" 2>/dev/null | awk '/ssid /{print $2; exit}')
                echo "WiFi ${ssid:-Connected}" > "$NETWORK_FILE"
            else
                echo "ETH Connected" > "$NETWORK_FILE"
            fi
        else
            echo "NET Offline" > "$NETWORK_FILE"
        fi
    else
        echo "NET N/A" > "$NETWORK_FILE"
    fi
}

update_all() {
    update_keyboard
    update_media
    update_backlight
    update_temperature
    update_network
    update_battery
    update_audio
    update_ram
}

update_slow() {
    update_ping
}

# --- Main Loop ---

# Initial update to populate files immediately
update_all
update_slow

# Counter for slow updates
loop_count=0
slow_update_frequency=$((SLOW_UPDATE_INTERVAL / FAST_UPDATE_INTERVAL))

while true; do
    update_all
    
    if [ $((loop_count % slow_update_frequency)) -eq 0 ]; then
        update_slow
    fi
    
    sleep "$FAST_UPDATE_INTERVAL"
    loop_count=$((loop_count + 1))
done