#!/bin/bash
# Update and install WireGuard
sudo apt update && sudo apt install -y wireguard

# Generate server keys
SERVER_PRIVATE_KEY=$(wg genkey)
SERVER_PUBLIC_KEY=$(echo $SERVER_PRIVATE_KEY | wg pubkey)

# Generate client keys
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY | wg pubkey)

echo "Server Private Key: $SERVER_PRIVATE_KEY"
echo "Server Public Key: $SERVER_PUBLIC_KEY"
echo "Client Private Key: $CLIENT_PRIVATE_KEY"
echo "Client Public Key: $CLIENT_PUBLIC_KEY"

# Configure server
SERVER_PORT=51820
SERVER_ADDRESS="10.0.0.1/24"
CLIENT_ADDRESS="10.0.0.2/32"
DNS_SERVER="1.1.1.1"

WG_CONFIG="/etc/wireguard/wg0.conf"
sudo mkdir -p /etc/wireguard

# Write WireGuard configuration (server-side)
cat <<EOL | sudo tee $WG_CONFIG
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = $SERVER_ADDRESS
ListenPort = $SERVER_PORT
MTU = 1420
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = $CLIENT_ADDRESS
EOL

# Enable and start WireGuard
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

wg-quick down wg0
wg-quick up wg0

# Enable IP forwarding (temporary and persistent)
echo "Enabling IP forwarding..."
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
sudo sed -i '/^#*net.ipv4.ip_forward/c\net.ipv4.ip_forward=1' /etc/sysctl.conf
sudo sysctl -p

# Configure UFW
echo "Configuring UFW rules..."
sudo ufw allow 51820/udp
sudo ufw allow 22/tcp
sudo ufw --force enable

# Generate client configuration
CLIENT_CONFIG="\
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_ADDRESS
DNS = $DNS_SERVER
MTU = 1420

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $(curl -s ifconfig.me):$SERVER_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
"

echo "$CLIENT_CONFIG" > client.conf

# Final message
echo "WireGuard setup is complete!"
echo "Server configuration saved to '$WG_CONFIG'."
echo "Client configuration saved to 'client.conf'."

cat client.conf