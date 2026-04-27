#!/bin/bash

mtu=${1:-9000}
txqueuelen=${2:-524288}
INTERFACES=("${@:3}")   # all args from position 3 onward
ip_addr="192.168.10.100/24"

if [[ ${#INTERFACES[@]} -eq 0 ]]; then
    echo "Usage: $0 [mtu] [txqueuelen] iface1 [iface2 ...]"
    echo "  Defaults: mtu=9000, txqueuelen=524288"
    exit 1
fi

configure_interface() {
    local iface=$1
    local is_virtual=$2  # "true" for docker0, "false" for physical

    current_mtu=$(ip link show "$iface" 2>/dev/null | grep -oP 'mtu \K\d+' || echo "0")
    if [[ "$current_mtu" -eq "$mtu" ]]; then
        echo "$iface MTU already $mtu, skipping"
        return 1
    fi

    echo "Configuring $iface:"
    sudo ip link set "$iface" down                                           # fix: was "iface"
    sudo ip link set dev "$iface" mtu "$mtu"           && echo "  MTU set to $mtu"
    sudo ip link set dev "$iface" txqueuelen "$txqueuelen" && echo "  txqueuelen set to $txqueuelen"
    sudo ip link set dev "$iface" xdpoffload off       && echo "  xdpoffload disabled"

    if [[ "$is_virtual" != "true" ]]; then
        sudo nmcli connection modify "$iface" ipv4.method manual ipv4.addresses "$ip_addr" \
            && echo "  IP address set to $ip_addr"
    fi

    sudo ip link set "$iface" up                                             # fix: was "sit"
    return 0
}

for iface in "${INTERFACES[@]}"; do
    case "$iface" in
        docker0)
            configure_interface "$iface" "true"   # fix: was "iface"
            ;;
        *)
            configure_interface "$iface" "false"
            ;;
    esac
done

sleep 1
echo "DONE!"