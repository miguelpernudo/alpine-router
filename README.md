# PATHFINDER
This script turns my Asus mini PC into a basic, secure gateway.

This PC is an Asus Eee PC X101CH, with intel Atom N2600and 980MB RAM.
I decided to give it a second life as a small networking lab so I could start defining and experimenting with the approach I’d like a real router to take. Since the hardware isn’t in perfect condition, it only functions as an access point and not as a router.

```mermaid
graph LR
    A[Internet] --> B[Router\n192.168.0.1]
    B --> C[eth0\n192.168.0.30]
    C --> D[Pathfinder]
    D --> E[wlan0\n192.168.2.1]
    E --> F[dnscrypt-proxy\nnftables NAT]
    F --> G[Wi-Fi Clients\n192.168.2.x]
```

## Structure
```
.
├── etc
│   ├── dnscrypt-proxy.toml
│   ├── dnsmasq.conf
│   ├── hostapd.conf
│   ├── logrotate.d
│   │   └── dnscrypt-proxy
│   └── nftables.nft
├── install.sh
├── LICENSE
├── README.md
└── secrets.env.example  ->  for the wpa passphrase
```

## hostapd
The primarily responsible for turning the network card into a network in its own that can be accessed. Set the ESSID, password (that's why we need the secrets.env), channel, etc.

## dnsmasq
It's the DHCP server that assigns IP addresses to the devices connected in the network and resolves DNS using dsnCrypt in this case.

## dnsCrypt 
Encrypts the plaintext in DNS queries. Provides an extra layer of security and privacy.

## nftables
A robust firewall with strict policies that allows only necessary traffic. SSH access is permitted only if the user is on the same LAN.
