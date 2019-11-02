#!/usr/bin/env bash

# Exit on any error

set -euo pipefail

# Check if executed as root

if [[ $EUID -ne 0 ]]; then
  >&2 echo "This script has to be executed by root"
        exit 1
fi

# Detect default network interface and public IP address

INTERFACE=$(route | grep default | rev | cut -d " " -f 1 | rev)
IPV4_ADDRESS=$(ip addr list "$INTERFACE" | grep "inet " | xargs | cut -d " " -f 2)

# Get next available client IP

nextip(){
  local IP=$1
  local IP_HEX=$(printf '%.2X%.2X%.2X%.2X\n' `echo $IP | sed -e 's/\./ /g'`)
  local NEXT_IP_HEX=$(printf %.8X `echo $(( 0x$IP_HEX + 1 ))`)
  local NEXT_IP=$(printf '%d.%d.%d.%d\n' `echo $NEXT_IP_HEX | sed -r 's/(..)/0x\1 /g'`)
  echo "$NEXT_IP"
}

LAST_IP=$(cat /etc/wireguard/wg0.conf  | grep -E "Address|AllowedIPs" | grep "10.10." | rev | cut -d " " -f 1 | rev | sed 's#/[0-9]*##g' | sort | tail -n 1)
NEXT_IP=$(nextip "$LAST_IP")

# Get client name from params

CLIENT_NAME=""
if [[ ! -z ${1-} ]]; then
  CLIENT_NAME=$1
fi

# Generate client keys

CLIENT_PRIVKEY=$(wg genkey)
CLIENT_PUBKEY=$(echo ${CLIENT_PRIVKEY} | wg pubkey)

# Retrieve server public key and listening port

SERVER_PUBKEY=$(cat /etc/wireguard/wg0.conf | grep PrivateKey | rev | cut -d " " -f 1 | rev | wg pubkey)
SERVER_PORT=$(cat /etc/wireguard/wg0.conf | grep ListenPort | rev | cut -d " " -f 1 | rev)
SERVER_ADDRESS=$(echo "$IPV4_ADDRESS" | sed 's#/[0-9]*##g')
# Add clientto wg0.conf

echo "
# ${CLIENT_NAME}
[Peer]
PublicKey       = ${CLIENT_PUBKEY}
AllowedIPs      = ${NEXT_IP}/32
" >> /etc/wireguard/wg0.conf

# Restart Wireguard

systemctl restart wg-quick@wg0

# Display client config

echo "
[Interface]
PrivateKey = ${CLIENT_PRIVKEY}
Address = ${NEXT_IP}/32
DNS = 10.10.0.1

[Peer]
PublicKey = ${SERVER_PUBKEY}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${SERVER_ADDRESS}:${SERVER_PORT}
"

