#!/bin/bash

# ---- CONFIG ----
CONFIG=~/Documents/OpenVPN/proxy-gb.ovpn
VPN_ICON_ON="󰦝"
VPN_ICON_OFF="󱦚"
VPN_NAME="OpenVPN"
# ----------------

# Check if VPN session is active
is_vpn_active() {
    openvpn3 sessions-list | grep -q "Path:"
}

# Check if Wi-Fi is connected + internet access
has_internet() {
    # Check if NetworkManager is available
    if ! command -v nmcli &>/dev/null; then
        return 1  # NetworkManager not available
    fi
    
    # Check if any connection is active (broader than just wifi/ethernet)
    if ! nmcli -t -f STATE general status | grep -q "connected"; then
        return 1  # No active connections
    fi
    
    # Check connectivity with timeout
    local connectivity=$(timeout 5 nmcli networking connectivity check 2>/dev/null)
    if [[ "$connectivity" == "full" ]]; then
        return 0  # Full internet access
    fi
    
    return 1  # No or limited internet access
}


# Print status for Waybar
get_vpn_status() {
    if is_vpn_active; then
        echo "{\"text\":\"$VPN_ICON_ON\", \"class\":\"on\", \"tooltip\":\"VPN Connected\"}"
    else
        echo "{\"text\":\"$VPN_ICON_OFF\", \"class\":\"off\", \"tooltip\":\"VPN Disconnected\"}"
    fi
}

# Toggle VPN connection
toggle_vpn() {
    if is_vpn_active; then
        # Disconnect all running sessions
        sessions=$(openvpn3 sessions-list | awk '/Path:/ {print $2}')
        for session in $sessions; do
            openvpn3 session-manage --session-path "$session" --disconnect
        done
        notify-send -u normal "$VPN_NAME Disconnected" "VPN session stopped"
    else
        if ! has_internet; then
            notify-send -u critical "$VPN_NAME Error" "No Wi-Fi or no internet access"
            exit 1
        fi

        if [[ ! -f "$CONFIG" ]]; then
            notify-send -u critical "$VPN_NAME Error" "Config not found: $CONFIG"
            exit 1
        fi

        if openvpn3 session-start --config "$CONFIG" >/dev/null 2>&1; then
            notify-send -u normal "$VPN_NAME Connected" "VPN session started"
        else
            notify-send -u critical "$VPN_NAME Error" "Failed to start VPN session"
        fi
    fi
}

# -------- Main --------
case "$1" in
    --toggle)
        toggle_vpn
        ;;
    *)
        get_vpn_status
        ;;
esac

