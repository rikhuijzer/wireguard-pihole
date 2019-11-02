#!/usr/bin/env bash

# Exit on any error

set -euo pipefail

# Check if executed as root

if [[ $EUID -ne 0 ]]; then
  >&2 echo "This script has to be executed by root"
	exit 1
fi

# Update system and configure automatic upgrades

if [[ ${1-} != "nosetup" ]]; then
  apt update
  apt autoremove -y
  DEBIAN_FRONTEND=noninteractive UCF_FORCE_CONFFOLD=YES apt -y upgrade
  apt install -y unattended-upgrades update-notifier-common
  echo "APT::Periodic::Update-Package-Lists 1;
APT::Periodic::Download-Upgradeable-Packages 1;
APT::Periodic::AutocleanInterval 7;
APT::Periodic::Unattended-Upgrade 1;
" > /etc/apt/apt.conf.d/20auto-upgrades
  echo "Unattended-Upgrade::Automatic-Reboot \"true\";
" > /etc/apt/apt.conf.d/50unattended-upgrades
fi

# Detect default network interface and public IP address

INTERFACE=$(route | grep default | rev | cut -d " " -f 1 | rev)
IPV4_ADDRESS=$(ip addr list "$INTERFACE" | grep "inet " | xargs | cut -d " " -f 2)

# Disable IPV6

echo "net.ipv6.conf.${INTERFACE}.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p > /dev/null

# Install Wireguard

apt install -y linux-headers-$(uname -r)
add-apt-repository -y ppa:wireguard/wireguard
apt update
apt install -y wireguard python-pip
modprobe wireguard

# Configure Wireguard

mkdir -p /etc/wireguard

SERVER_PORT=$(shuf -i1024-65545 -n1)
SERVER_PRIVKEY=$(wg genkey)

echo "[Interface]
PrivateKey      = ${SERVER_PRIVKEY}
Address         = 10.10.0.1/24
ListenPort      = ${SERVER_PORT}

PostUp          = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ${INTERFACE} -j MASQUERADE
PostDown        = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ${INTERFACE} -j MASQUERADE
" > /etc/wireguard/wg0.conf

chmod 700 /etc/wireguard/
chmod 600 /etc/wireguard/*

echo "net.ipv4.ip_forward=1" | tee -a /etc/sysctl.conf
sysctl -p > /dev/null

# Start Wireguard

systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Configure and install Pi-hole

mkdir -p /etc/pihole/
echo "PIHOLE_INTERFACE=wg0
IPV4_ADDRESS=10.10.0.1
IPV6_ADDRESS=
PIHOLE_DNS_1=1.1.1.1
PIHOLE_DNS_2=1.0.0.1
QUERY_LOGGING=false
INSTALL_WEB_SERVER=true
INSTALL_WEB_INTERFACE=true
LIGHTTPD_ENABLED=true
BLOCKING_ENABLED=true
" > /etc/pihole/setupVars.conf
curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended
