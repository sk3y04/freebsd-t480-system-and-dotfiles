#!/bin/sh

# WiFi Reconnect Script for FreeBSD
# Usage: doas ./wifi-reconnect.sh [interface] [config_file]
# Note: This script must be run with root privileges

# Default values
DEFAULT_INTERFACE="wlan0"
DEFAULT_CONFIG="/etc/wpa_supplicant.conf"

# Use provided arguments or defaults
INTERFACE=${1:-$DEFAULT_INTERFACE}
CONFIG_FILE=${2:-$DEFAULT_CONFIG}

# Function to print output
print_status() {
    printf "[INFO] %s\n" "$1"
}

print_warning() {
    printf "[WARN] %s\n" "$1"
}

print_error() {
    printf "[ERROR] %s\n" "$1"
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    print_error "This script must be run with doas/sudo privileges"
    print_error "Usage: doas ./wifi-reconnect.sh [interface] [config_file]"
    exit 1
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    print_error "Configuration file $CONFIG_FILE not found!"
    exit 1
fi

# Check if interface exists
if ! ifconfig "$INTERFACE" > /dev/null 2>&1; then
    print_error "Interface $INTERFACE not found!"
    print_warning "Available interfaces:"
    ifconfig | grep -E '^[a-z]' | cut -d: -f1
    exit 1
fi

print_status "Reconnecting WiFi on interface $INTERFACE using config $CONFIG_FILE"

# Step 1: Kill existing wpa_supplicant process
print_status "Stopping existing wpa_supplicant processes..."
pkill wpa_supplicant
sleep 2

# Step 2: Start wpa_supplicant with new configuration
print_status "Starting wpa_supplicant..."
if wpa_supplicant -B -i "$INTERFACE" -c "$CONFIG_FILE"; then
    print_status "wpa_supplicant started successfully"
else
    print_error "Failed to start wpa_supplicant"
    exit 1
fi

# Wait a moment for connection to establish
print_status "Waiting for connection to establish..."
sleep 3

# Step 3: Handle existing dhclient process
print_status "Managing DHCP client..."

# Check if dhclient is already running for this interface
DHCP_PID=$(pgrep -f "dhclient.*$INTERFACE")
if [ -n "$DHCP_PID" ]; then
    print_status "Stopping existing dhclient process (PID: $DHCP_PID)..."
    pkill -f "dhclient.*$INTERFACE"
    sleep 2
fi

# Start dhclient
print_status "Starting DHCP client..."
if dhclient "$INTERFACE"; then
    print_status "DHCP client started successfully"
else
    print_warning "DHCP client may have failed - you might need to configure IP manually"
fi

# Step 4: Check connection status
print_status "Checking connection status..."
sleep 3

# Show current IP address
IP_ADDR=$(ifconfig "$INTERFACE" | grep 'inet ' | awk '{print $2}')
if [ -n "$IP_ADDR" ]; then
    print_status "Connected! IP address: $IP_ADDR"
else
    print_warning "No IP address assigned yet"
fi

# Show current SSID if available (parse properly)
SSID_LINE=$(ifconfig "$INTERFACE" | grep 'ssid')
if [ -n "$SSID_LINE" ]; then
    # Extract SSID name (not BSSID)
    SSID=$(echo "$SSID_LINE" | sed -n 's/.*ssid \([^ ]*\).*/\1/p')
    if [ -n "$SSID" ] && [ "$SSID" != "98:42:65:e1:9a:44" ]; then
        print_status "Connected to SSID: $SSID"
    else
        # Try alternative parsing for SSID
        SSID_ALT=$(echo "$SSID_LINE" | awk '{for(i=1;i<=NF;i++) if($i=="ssid") print $(i+1)}')
        if [ -n "$SSID_ALT" ]; then
            print_status "Connected to network: $SSID_ALT"
        fi
    fi
fi

# Show signal strength if available
SIGNAL=$(ifconfig "$INTERFACE" | grep -o 'signal [0-9]*' | awk '{print $2}')
if [ -n "$SIGNAL" ]; then
    print_status "Signal strength: $SIGNAL dBm"
fi

print_status "WiFi reconnection completed!"
