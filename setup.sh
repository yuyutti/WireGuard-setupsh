#!/bin/bash

# WireGuardのインストール
sudo apt update
sudo apt install wireguard -y
sudo apt install curl -y

# IPフォワーディングを有効化
sudo sh -c 'echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf'
sudo sysctl -p

# ファイアウォール設定
sudo ufw allow 51820/udp
sudo ufw allow OpenSSH
echo "y" | sudo ufw enable

# サーバーのプライベートキーとパブリックキーを生成
sudo wg genkey | sudo tee /etc/wireguard/privatekey | wg pubkey | sudo tee /etc/wireguard/publickey

# クライアント設定を生成
sudo wg genkey | sudo tee /etc/wireguard/client_privatekey | wg pubkey | sudo tee /etc/wireguard/client_publickey

# 事前共有キーを生成
sudo wg genkey | sudo tee /etc/wireguard/client_preshared.key

# WireGuardサーバーインターフェースの設定
sudo sh -c 'echo "
[Interface]
Address = 172.16.0.254/24
ListenPort = 51820
PrivateKey = $(cat /etc/wireguard/privatekey)
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $(cat /etc/wireguard/client_publickey)
PresharedKey = $(cat /etc/wireguard/client_preshared.key)
AllowedIPs = 172.16.0.1/32
" > /etc/wireguard/wg0.conf'

# wireguardクライアントインターフェースの設定
sudo sh -c 'echo "
[Interface]
PrivateKey = $(cat /etc/wireguard/client_privatekey)
Address = 10.0.0.2/24
DNS = 1.1.1.1

[Peer]
PublicKey = $(cat /etc/wireguard/publickey)
PresharedKey = $(cat /etc/wireguard/client_preshared.key)
Endpoint = $(curl -4 icanhazip.com):51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
" > /opt/client.conf'

# WireGuardを起動
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0